import Quickshell
import Quickshell.Io
import QtQuick

// Centralized brightness monitoring and control service
Scope {
    id: root

    property int brightness: -1
    property int maxBrightness: 100
    property bool available: false

    // Signal emitted when brightness changes (for OSD integration)
    signal brightnessUpdated(int oldValue, int newValue)

    Component.onCompleted: pollProc.running = true

    // Guard: ignore poll results briefly after a manual set to prevent jitter
    property bool suppressPoll: false
    Timer { id: suppressTimer; interval: 300; onTriggered: root.suppressPoll = false }

    function setBrightness(percent) {
        percent = Math.max(0, Math.min(100, percent));
        let old = root.brightness;
        root.brightness = percent;
        if (old !== percent && old >= 0) root.brightnessUpdated(old, percent);
        root.suppressPoll = true;
        suppressTimer.restart();
        setProc.percent = percent;
        setProc.running = true;
    }

    function increase(step) {
        if (step === undefined) step = 5;
        setBrightness(brightness + step);
    }

    function decrease(step) {
        if (step === undefined) step = 5;
        setBrightness(brightness - step);
    }

    // Poll current brightness
    Process {
        id: pollProc
        command: [
            "bash", "-c",
            "cur=$(brightnessctl get 2>/dev/null) && max=$(brightnessctl max 2>/dev/null) && " +
            "echo \"$cur $max\" || echo '-1 -1'"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                if (root.suppressPoll) return;

                let parts = data.trim().split(" ");
                if (parts.length >= 2) {
                    let cur = parseInt(parts[0]);
                    let max = parseInt(parts[1]);

                    if (!isNaN(max) && max > 0) {
                        root.maxBrightness = max;
                        root.available = true;

                        if (!isNaN(cur)) {
                            let oldBri = root.brightness;
                            let newBri = Math.round(cur * 100 / max);

                            if (newBri !== oldBri) {
                                root.brightness = newBri;
                                if (oldBri >= 0) {
                                    root.brightnessUpdated(oldBri, newBri);
                                }
                            }
                        }
                    } else {
                        root.available = false;
                    }
                }
            }
        }

        onExited: pollTimer.start()
    }

    // Adaptive polling: faster when recently active
    property bool recentlyActive: false

    Timer {
        id: activityCooldown
        interval: 2000
        onTriggered: root.recentlyActive = false
    }

    function markActive() {
        recentlyActive = true;
        activityCooldown.restart();
    }

    Timer {
        id: pollTimer
        interval: root.recentlyActive ? 100 : 500
        onTriggered: pollProc.running = true
    }

    // Set brightness
    Process {
        id: setProc
        property int percent: 0
        command: ["brightnessctl", "set", percent + "%"]

        onStarted: root.markActive()
    }
}
