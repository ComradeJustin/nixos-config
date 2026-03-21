import Quickshell
import Quickshell.Io
import QtQuick

// Tracks window state and overview mode for widget occlusion
Scope {
    id: root

    // True when widgets should be visible (no windows on active workspace AND not in overview)
    property bool widgetsVisible: windowCount === 0 && !overviewOpen
    property int windowCount: 0
    property bool overviewOpen: false

    Component.onCompleted: {
        checkProc.running = true;
        overviewProc.running = true;
    }

    // Use JSON output for reliable parsing - workspace IDs can be non-contiguous
    Process {
        id: checkProc
        command: ["bash", "-c",
            "ws=$(niri msg -j workspaces 2>/dev/null | jq '.[] | select(.is_active) | .id'); " +
            "niri msg -j windows 2>/dev/null | jq --arg ws \"$ws\" '[.[] | select(.workspace_id == ($ws | tonumber))] | length'"
        ]

        stdout: SplitParser {
            onRead: data => {
                let count = parseInt(data.trim());
                if (!isNaN(count)) {
                    root.windowCount = count;
                }
            }
        }

        onExited: pollTimer.start()
    }

    // Check overview state
    Process {
        id: overviewProc
        command: ["bash", "-c", "niri msg -j overview-state 2>/dev/null | jq -r '.is_open'"]

        stdout: SplitParser {
            onRead: data => {
                root.overviewOpen = data.trim() === "true";
            }
        }
    }

    // Poll regularly
    Timer {
        id: pollTimer
        interval: 500
        onTriggered: checkProc.running = true
    }

    // Listen to niri events for faster response
    Process {
        id: eventProc
        command: ["niri", "msg", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                // Check for overview toggle events
                if (data.indexOf("Overview toggled") !== -1) {
                    // Parse "Overview toggled: true/false"
                    root.overviewOpen = data.indexOf("true") !== -1;
                }
                // Check for window/workspace changes
                if (data.indexOf("Window") !== -1 || data.indexOf("Workspace") !== -1) {
                    // Immediate check on relevant events
                    checkProc.running = true;
                }
            }
        }

        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: eventProc.running = true
    }
}
