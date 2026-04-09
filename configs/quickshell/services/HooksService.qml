import Quickshell
import Quickshell.Io
import QtQuick
import "../core" as Core

// HooksService — wire shell events to user-defined shell commands.
//
// Loads ~/.config/quickshell/hooks.json on startup. Format:
//
//   {
//     "audio.deviceSwitched": "notify-send 'Audio' 'Now using ${arg2}'",
//     "wifi.connectFinished": ["sh", "-c", "echo $1 >> ~/.wifi.log", "--", "${arg1}"],
//     "brightness.update":    "echo ${arg2} > /tmp/bri",
//     "caffeine.toggle":      "notify-send 'Caffeine' ${arg1}"
//   }
//
// Each event maps to either:
//   - a string (run via `sh -c`)
//   - an array (executed directly as argv)
//
// ${arg1}..${argN} are substituted from signal arguments at fire time.
// Unmatched ${argN} placeholders become empty strings.
//
// Hooks are stateless — the service spawns one Process per fire, no queueing.
// If two events fire simultaneously, both run in parallel.
//
// Hot reload: HooksService uses Quickshell's reactive `FileView` to watch
// hooks.json. Edits are picked up instantly via kernel filesystem events —
// no 3-second polling timer, no `stat` subprocess, no mtime diffing.
Scope {
    id: root

    // Set by shell.qml after construction. Map of service-key → instance.
    property var services: ({})

    // Loaded hook table: { eventName: command }
    property var _table: ({})
    property bool _loaded: false

    // Recent fires for in-shell debugging (settings page reads this).
    // Bounded ring buffer of size 50, newest last.
    property var recentFires: []
    readonly property int _recentLimit: 50

    // Path to the JSON config
    readonly property string _path: Quickshell.env("HOME") + "/.config/quickshell/hooks.json"

    // ── Known events catalog ──
    // Drives the settings page's discovery UI and the `hooksList` IPC.
    // Adding a new wired Connections block below should also add an entry
    // here so users can find it without grepping QML.
    readonly property var knownEvents: [
        { name: "audio.volumeUpdated",       args: "oldValue, newValue",       desc: "Audio output volume changed" },
        { name: "audio.muteToggled",         args: "oldMuted, newMuted",       desc: "Audio mute state changed" },
        { name: "audio.deviceSwitched",      args: "oldDevice, newDevice",     desc: "Default audio sink changed" },
        { name: "brightness.update",         args: "oldValue, newValue",       desc: "Screen brightness changed" },
        { name: "wifi.connectFinished",      args: "ssid, ok|error, message",  desc: "Wifi connect attempt completed" },
        { name: "wifi.connected",            args: "ssid",                     desc: "Joined a wifi network or ethernet" },
        { name: "wifi.disconnected",         args: "ssid",                     desc: "Left the previous wifi network" },
        { name: "bluetooth.deviceConnected", args: "name, type",               desc: "Bluetooth device connected" },
        { name: "bluetooth.deviceDisconnected", args: "name",                  desc: "Bluetooth device disconnected" },
        { name: "power.batteryCharged",      args: "(none)",                   desc: "Battery hit 100% while plugged in" },
        { name: "power.batteryLow",          args: "level",                    desc: "Battery dropped to 15% on the discharge curve" },
        { name: "power.acPlugged",           args: "plugged (true|false)",     desc: "AC adapter plugged or unplugged" },
        { name: "power.chargingChanged",     args: "charging (true|false)",    desc: "Charging state flipped" },
        { name: "caffeine.toggle",           args: "on|off",                   desc: "Idle inhibit toggled" },
        { name: "notification.received",    args: "appName, summary, body",    desc: "Notification received (when NotifService supports it)" }
    ]

    // ── Reactive file loader ──
    // FileView watches the file via the kernel (inotify on Linux) and emits
    // `fileChanged` on any edit, `loaded` once on initial read, and
    // `loadFailed` if the file doesn't exist. All three funnel into
    // `_parseTable()`, which swallows errors and falls back to `{}` so a
    // malformed or missing file never breaks the shell.
    FileView {
        id: _hooksFile
        path: root._path
        watchChanges: true
        onLoaded: root._parseTable()
        onFileChanged: {
            Core.Logger.i("HooksService", "hooks.json changed, reloading");
            reload();
            root._parseTable();
        }
        onLoadFailed: err => {
            // Missing file is fine — service just stays inert until one
            // exists. Other errors we log so the user knows.
            if (err !== FileViewError.FileNotFound) {
                Core.Logger.w("HooksService", "load failed:", FileViewError.toString(err));
            }
            root._table = {};
            root._loaded = true;
        }
    }

    function _parseTable() {
        var raw = "";
        try { raw = _hooksFile.text(); } catch (e) { raw = ""; }
        if (!raw || raw.trim().length === 0) {
            root._table = {};
            root._loaded = true;
            return;
        }
        try {
            root._table = JSON.parse(raw);
            root._loaded = true;
            Core.Logger.i("HooksService", "loaded", Object.keys(root._table).length, "hooks");
        } catch (e) {
            Core.Logger.w("HooksService", "failed to parse hooks.json:", e);
            root._table = {};
            root._loaded = true;
        }
    }

    // Manual reload entry point — still exposed over IPC so you can
    // force a re-read without touching the file.
    function reload() {
        _hooksFile.reload();
        _parseTable();
    }

    // ── Public API: fire an event by name ──
    // Extra arguments are passed through to ${arg1..argN} substitution.
    function fire(eventName) {
        // Collect args (after eventName)
        let args = [];
        for (let i = 1; i < arguments.length; i++) args.push(String(arguments[i]));

        // Record into ring buffer regardless of whether a hook is bound,
        // so users can debug "why isn't my hook firing" by seeing the
        // event was actually emitted.
        _recordFire(eventName, args);

        let cmd = _table[eventName];
        if (cmd === undefined) return;

        let resolved;
        if (typeof cmd === "string") {
            // sh -c form
            resolved = ["sh", "-c", _substitute(cmd, args)];
        } else if (cmd instanceof Array) {
            resolved = [];
            for (let i = 0; i < cmd.length; i++) {
                resolved.push(_substitute(String(cmd[i]), args));
            }
        } else {
            console.log("HooksService: hook for", eventName, "must be string or array");
            return;
        }

        // Spawn a fresh per-fire Process so concurrent hooks don't clobber
        // each other. Quickshell's Process can't safely re-`run` while busy,
        // so we instantiate one dynamically and let it self-destroy on exit.
        _spawn(resolved);
    }

    function _recordFire(eventName, args) {
        let entry = {
            event: eventName,
            args: args,
            ts: Date.now(),
            bound: _table[eventName] !== undefined
        };
        // Replace the property wholesale so QML's binding system notices
        // the change (mutating the array in place would not).
        let next = recentFires.slice();
        next.push(entry);
        if (next.length > _recentLimit) next = next.slice(next.length - _recentLimit);
        recentFires = next;
    }

    // Component used to spawn one-shot Processes
    property Component _runnerComponent: Component {
        Process {
            property var argv: []
            command: argv
            running: true
            onExited: Qt.callLater(() => destroy())
        }
    }

    function _spawn(argv) {
        let p = _runnerComponent.createObject(root, { argv: argv });
        if (!p) console.log("HooksService: failed to spawn process for", JSON.stringify(argv));
    }

    function _substitute(str, args) {
        // Replace ${arg1}..${argN} with the corresponding arg, or "" if absent.
        return str.replace(/\$\{arg(\d+)\}/g, function(m, n) {
            let i = parseInt(n) - 1;
            return (i >= 0 && i < args.length) ? args[i] : "";
        });
    }

    // ── IPC helpers ──
    // Returns a JSON-serializable structure describing every known event,
    // whether it has a binding, and what the binding looks like.
    function listEvents() {
        let out = [];
        for (let i = 0; i < knownEvents.length; i++) {
            let e = knownEvents[i];
            out.push({
                name: e.name,
                args: e.args,
                desc: e.desc,
                bound: _table[e.name] !== undefined,
                command: _table[e.name] || null
            });
        }
        return out;
    }

    // ── Wire known service signals to fire() ──
    // Connections blocks below bind reactively to `root.services.<key>`,
    // which shell.qml populates after construction. When the service map
    // lands, QML rebinds the targets automatically — no manual wiring.

    // Audio
    Connections {
        target: root.services.audio || null
        function onVolumeUpdated(oldValue, newValue) { root.fire("audio.volumeUpdated", oldValue, newValue); }
        function onMuteToggled(oldMuted, newMuted) { root.fire("audio.muteToggled", oldMuted, newMuted); }
        function onDeviceSwitched(oldDevice, newDevice) { root.fire("audio.deviceSwitched", oldDevice, newDevice); }
    }

    // Brightness
    Connections {
        target: root.services.brightness || null
        function onBrightnessUpdated(oldValue, newValue) { root.fire("brightness.update", oldValue, newValue); }
    }

    // Wifi
    Connections {
        target: root.services.wifi || null
        function onConnectFinished(ssid, ok, message) {
            root.fire("wifi.connectFinished", ssid, ok ? "ok" : "error", message);
        }
        function onWifiConnected(ssid) { root.fire("wifi.connected", ssid); }
        function onWifiDisconnected(ssid) { root.fire("wifi.disconnected", ssid); }
    }

    // Bluetooth
    Connections {
        target: root.services.bluetooth || null
        function onBluetoothDeviceConnected(name, type) {
            root.fire("bluetooth.deviceConnected", name, type);
        }
        function onBluetoothDeviceDisconnected(name) {
            root.fire("bluetooth.deviceDisconnected", name);
        }
    }

    // Power / battery
    Connections {
        target: root.services.power || null
        function onBatteryCharged() { root.fire("power.batteryCharged"); }
        function onBatteryLow(level) { root.fire("power.batteryLow", level); }
        function onAcPlugged(plugged) { root.fire("power.acPlugged", plugged ? "true" : "false"); }
        function onChargingStateChanged(charging) { root.fire("power.chargingChanged", charging ? "true" : "false"); }
    }

    // Idle inhibit (caffeine)
    Connections {
        target: root.services.idleInhibit || null
        function onInhibitedChanged() {
            let svc = root.services.idleInhibit;
            if (svc) root.fire("caffeine.toggle", svc.inhibited ? "on" : "off");
        }
    }

    // Notifications
    Connections {
        target: root.services.notif || null
        ignoreUnknownSignals: true
        function onNotificationReceived(appName, summary, body) {
            root.fire("notification.received", appName, summary, body);
        }
    }
}
