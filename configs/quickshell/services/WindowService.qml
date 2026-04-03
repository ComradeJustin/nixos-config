import Quickshell
import Quickshell.Io
import QtQuick

// Tracks window state and overview mode for widget occlusion
Scope {
    id: root

    // Per-output window counts: { "DP-1": 3, "HDMI-A-1": 0 }
    property var windowCounts: ({})
    property bool overviewOpen: false

    // Check if a specific screen has no windows on its active workspace
    function screenEmpty(screenName) {
        return (windowCounts[screenName] || 0) === 0;
    }

    Component.onCompleted: {
        checkProc.running = true;
        overviewProc.running = true;
    }

    // Get per-output window counts for all active workspaces
    Process {
        id: checkProc
        command: ["bash", "-c",
            "ws=$(niri msg -j workspaces 2>/dev/null) || exit 0; " +
            "wins=$(niri msg -j windows 2>/dev/null) || exit 0; " +
            "echo \"$ws\" | jq -r '.[] | select(.is_active) | \"\\(.output) \\(.id)\"' | while IFS=' ' read -r out wsid; do " +
            "  count=$(echo \"$wins\" | jq --argjson ws \"$wsid\" '[.[] | select(.workspace_id == $ws)] | length'); " +
            "  echo \"$out $count\"; " +
            "done"
        ]

        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(" ");
                if (parts.length >= 2) {
                    let output = parts.slice(0, parts.length - 1).join(" ");
                    let count = parseInt(parts[parts.length - 1]);
                    if (!isNaN(count)) {
                        // Create new object to ensure QML property change fires
                        let fresh = {};
                        let old = root.windowCounts;
                        for (let k in old) fresh[k] = old[k];
                        fresh[output] = count;
                        root.windowCounts = fresh;
                    }
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
