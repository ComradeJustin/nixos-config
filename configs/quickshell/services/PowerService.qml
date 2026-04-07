import Quickshell
import Quickshell.Io
import QtQuick

// PowerService — power actions + battery state + change-event signals.
//
// Battery polling lives here (rather than in BatteryModule) so the data has
// exactly one source of truth and can drive both the bar widget and the
// hooks system from a single set of signals. BatteryModule binds to these
// properties; HooksService listens for the signals.
Scope {
    id: root

    // ── Power actions ──
    function lock() { lockProc.running = true; }
    function suspend() { suspendProc.running = true; }
    function reboot() { rebootProc.running = true; }
    function shutdown() { shutdownProc.running = true; }
    function logout() { logoutProc.running = true; }

    Process { id: lockProc; command: ["loginctl", "lock-session"] }
    Process { id: suspendProc; command: ["systemctl", "suspend"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
    Process { id: logoutProc; command: ["niri", "msg", "action", "quit"] }

    // ── Battery state (read by BatteryModule) ──
    property string device: "BAT0"
    property int capacity: -1
    property bool charging: false
    property bool pluggedIn: false
    property bool hasBattery: false

    // Latch so we only fire batteryCharged once per charge cycle
    property bool _hasNotifiedFull: false
    // Previous capacity for threshold-crossing detection
    property int _prevCapacity: -1
    // First-poll guard — suppress signals/notifications until baseline is set
    property bool _powerInitialized: false

    // ── Signals (HooksService binds to these) ──
    signal batteryCharged()                      // hit 100% while plugged in
    signal batteryLow(int level)                 // crossed 15% on the way down
    signal acPlugged(bool plugged)               // AC plug state changed
    // NOTE: named *chargingStateChanged* (not chargingChanged) to avoid
    // colliding with the auto-generated `chargingChanged` signal that QML
    // emits for the `charging` property.
    signal chargingStateChanged(bool charging)

    Component.onCompleted: detectProc.running = true

    Process {
        id: detectProc
        command: ["test", "-d", "/sys/class/power_supply/" + root.device]
        onExited: code => {
            root.hasBattery = (code === 0);
            if (root.hasBattery) {
                capProc.running = true;
                statusProc.running = true;
            }
        }
    }

    Process {
        id: capProc
        command: ["cat", "/sys/class/power_supply/" + root.device + "/capacity"]
        stdout: SplitParser {
            onRead: data => {
                let val = parseInt(data);
                if (isNaN(val)) return;
                root._prevCapacity = root.capacity;
                root.capacity = val;
                root._checkBatteryEvents();
            }
        }
        onExited: pollTimer.start()
    }

    Process {
        id: statusProc
        command: ["cat", "/sys/class/power_supply/" + root.device + "/status"]
        stdout: SplitParser {
            onRead: data => {
                let wasCharging = root.charging;
                let wasPlugged = root.pluggedIn;
                root.charging = (data === "Charging");
                root.pluggedIn = (data === "Charging" || data === "Not charging" || data === "Full");

                // Suppress signals + notifications on the very first poll
                // so the shell doesn't shout "AC plugged in!" every restart.
                if (root._powerInitialized) {
                    if (wasCharging !== root.charging) {
                        root.chargingStateChanged(root.charging);
                    }
                    if (wasPlugged !== root.pluggedIn) {
                        root.acPlugged(root.pluggedIn);
                        // Notify only on plug-in (not on unplug — that's
                        // typically obvious from the user's own action).
                        if (root.pluggedIn) root._firePlugged();
                    }
                }
                root._powerInitialized = true;
                root._checkBatteryEvents();
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 5000
        onTriggered: {
            if (root.hasBattery) {
                capProc.running = true;
                statusProc.running = true;
            }
        }
    }

    // Combined edge-detection: called from both capProc and statusProc.
    // Both inputs are needed because "fully charged" requires capacity == 100
    // AND pluggedIn == true, which arrive from different processes.
    function _checkBatteryEvents() {
        // ── Fully charged ──
        // Latch prevents repeat fires while sitting at 100%. Reset on
        // unplug or once capacity drops below 95%.
        if (root.pluggedIn && root.capacity >= 100 && !root._hasNotifiedFull) {
            root._hasNotifiedFull = true;
            root.batteryCharged();
            root._fireCharged();
        }
        if (!root.pluggedIn || root.capacity < 95) {
            root._hasNotifiedFull = false;
        }

        // ── Low battery: 15% threshold crossing while on battery ──
        if (!root.pluggedIn
            && root._prevCapacity > 15
            && root.capacity <= 15
            && root.capacity >= 0) {
            root.batteryLow(root.capacity);
            root._fireLow(root.capacity);
        }
    }

    // Built-in notifications so the events work without any hooks.json.
    // Hooks can layer additional behavior on top via `power.batteryCharged`.
    //
    // All three power notifications share the same synchronous hint tag
    // (`sysinfo-power`) so battery+ac toasts mutually replace each other —
    // the user always sees the *latest* power state, never a stack.
    //
    // IMPORTANT: we go through a single centralized spawn function rather
    // than declaring three static Process objects. Declarative Process
    // command arrays are captured at component instantiation time — if
    // you hot-reload the service, old Process instances keep their old
    // argv cached, which makes "restart to see changes" bugs very easy.
    // A Component.createObject() per fire sidesteps that entirely.

    readonly property string _notifyApp: "System Information"
    readonly property string _notifyTag: "string:x-canonical-private-synchronous:sysinfo-power"

    property Component _notifyRunner: Component {
        Process {
            property var argv: []
            command: argv
            running: true
            onExited: Qt.callLater(() => destroy())
        }
    }

    function _spawnNotify(argv) {
        let p = _notifyRunner.createObject(root, { argv: argv });
        if (!p) console.log("PowerService: failed to spawn notify", JSON.stringify(argv));
    }

    function _fireCharged() {
        _spawnNotify([
            "notify-send",
            "-a", _notifyApp,
            "-i", "battery-full-charged",
            "-h", _notifyTag,
            "-t", "4000",
            "Battery", "Fully charged"
        ]);
    }

    function _firePlugged() {
        _spawnNotify([
            "notify-send",
            "-a", _notifyApp,
            "-i", "battery-charging",
            "-h", _notifyTag,
            "-t", "4000",
            "Power", "AC adapter connected"
        ]);
    }

    function _fireLow(level) {
        _spawnNotify([
            "notify-send",
            "-a", _notifyApp,
            "-u", "critical",
            "-i", "battery-caution",
            "-h", _notifyTag,
            "Battery low", "Battery at " + level + "%"
        ]);
    }

    // ── Test entry points (wired to IPC) ──
    // Use these to verify notification formatting without waiting for a
    // real AC plug or battery charge transition:
    //   qs ipc call quickshell-bar testNotifyCharged
    //   qs ipc call quickshell-bar testNotifyPlugged
    //   qs ipc call quickshell-bar testNotifyLow
    function testFireCharged() { _fireCharged(); }
    function testFirePlugged() { _firePlugged(); }
    function testFireLow() { _fireLow(15); }
}
