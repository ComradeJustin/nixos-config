import Quickshell
import Quickshell.Io
import QtQuick

// Brightness monitoring and control.
// Event-driven: backlight changes fire udev events, so one persistent
// `udevadm monitor` stream replaces the old 500ms brightnessctl polling.
// Reads only happen on startup, on udev events, and after our own writes.
Scope {
    id: root

    property int brightness: -1
    property int maxBrightness: 100
    property bool available: false

    // Signal emitted when brightness changes (for OSD integration)
    signal brightnessUpdated(int oldValue, int newValue)

    Component.onCompleted: readProc.running = true

    // Guard: ignore reads briefly after a manual set to prevent jitter
    property bool suppressRead: false
    Timer { id: suppressTimer; interval: 300; onTriggered: root.suppressRead = false }

    property int _pendingBri: -1

    function setBrightness(percent) {
        percent = Math.max(0, Math.min(100, percent));
        let old = root.brightness;
        root.brightness = percent;
        if (old !== percent && old >= 0) root.brightnessUpdated(old, percent);
        root.suppressRead = true;
        suppressTimer.restart();
        setProc.percent = percent;
        if (!setProc.running) {
            setProc.running = true;
        } else {
            _pendingBri = percent;
        }
    }

    function increase(step) {
        if (step === undefined) step = 5;
        setBrightness(brightness + step);
    }

    function decrease(step) {
        if (step === undefined) step = 5;
        setBrightness(brightness - step);
    }

    // Backlight change events (brightness keys, swayidle dim, other tools)
    Process {
        id: udevMonitor
        command: ["stdbuf", "-oL", "udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.indexOf("change") !== -1 && !readProc.running)
                    readProc.running = true;
            }
        }
    }

    // Read current + max brightness (startup and on udev events)
    Process {
        id: readProc
        command: [
            "bash", "-c",
            "cur=$(brightnessctl get 2>/dev/null) && max=$(brightnessctl max 2>/dev/null) && " +
            "echo \"$cur $max\" || echo '-1 -1'"
        ]

        stdout: SplitParser {
            onRead: data => {
                if (root.suppressRead) return;

                let parts = data.trim().split(" ");
                if (parts.length < 2) return;
                let cur = parseInt(parts[0]);
                let max = parseInt(parts[1]);

                if (isNaN(max) || max <= 0) {
                    root.available = false;
                    return;
                }
                root.maxBrightness = max;
                root.available = true;

                if (!isNaN(cur)) {
                    let oldBri = root.brightness;
                    let newBri = Math.round(cur * 100 / max);
                    if (newBri !== oldBri) {
                        root.brightness = newBri;
                        if (oldBri >= 0) root.brightnessUpdated(oldBri, newBri);
                    }
                }
            }
        }
    }

    // Set brightness; coalesces rapid slider updates via _pendingBri
    Process {
        id: setProc
        property int percent: 0
        command: ["brightnessctl", "set", percent + "%"]

        onExited: {
            if (root._pendingBri >= 0) {
                percent = root._pendingBri;
                root._pendingBri = -1;
                root.suppressRead = true;
                suppressTimer.restart();
                running = true;
            }
        }
    }
}
