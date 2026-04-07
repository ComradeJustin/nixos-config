import Quickshell
import Quickshell.Io
import QtQuick

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
// Hot reload: HooksService polls the mtime of hooks.json every 3s and reloads
// when it changes — no need to call `qs ipc call quickshell-bar hooksReload`
// after editing the file.
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

    // Last known hooks.json mtime, used for hot reload diffing.
    property string _lastMtime: ""

    // Path to the JSON config
    readonly property string _path: Quickshell.env("HOME") + "/.config/quickshell/hooks.json"

    Component.onCompleted: { _loadProc.running = true; }

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

    // ── Loader ──
    property var _loadProc: Process {
        property string _buf: ""
        command: ["cat", root._path]
        stdout: SplitParser {
            onRead: line => { _loadProc._buf += line + "\n"; }
        }
        onExited: code => {
            if (code === 0 && _loadProc._buf.trim().length > 0) {
                try {
                    root._table = JSON.parse(_loadProc._buf);
                    root._loaded = true;
                    console.log("HooksService: loaded", Object.keys(root._table).length, "hooks");
                } catch (e) {
                    console.log("HooksService: failed to parse hooks.json:", e);
                    root._table = {};
                }
            } else {
                // No hooks file is fine — service stays inert.
                root._table = {};
                root._loaded = true;
            }
            _loadProc._buf = "";
            root._wire();
        }
    }

    // Manual reload (e.g. after editing hooks.json)
    function reload() { _loadProc.running = true; }

    // ── Hot reload via mtime polling ──
    // Cheap and dependency-free: a `stat` every 3 seconds is invisible
    // even on a battery-powered laptop, and avoids needing inotifywait.
    Timer {
        id: mtimeWatcher
        interval: 3000
        running: true
        repeat: true
        onTriggered: mtimeProc.running = true
    }

    Process {
        id: mtimeProc
        property string _buf: ""
        command: ["stat", "-c", "%Y", root._path]
        stdout: SplitParser {
            onRead: line => { mtimeProc._buf += line; }
        }
        onExited: code => {
            if (code === 0) {
                let m = mtimeProc._buf.trim();
                if (m.length > 0 && m !== root._lastMtime) {
                    if (root._lastMtime.length > 0) {
                        console.log("HooksService: hooks.json changed, reloading");
                        root.reload();
                    }
                    root._lastMtime = m;
                }
            }
            mtimeProc._buf = "";
        }
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
    // Called once after the table loads. We attach Connections components
    // declaratively below; this function only logs.
    function _wire() {
        // The Connections blocks below pick up `services` reactively.
    }

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
