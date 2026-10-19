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

    // Initial state comes from eventProc.onStarted (which also covers
    // event-stream restarts, resyncing anything missed during the gap).

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

    // Coalesce event bursts (window drags, workspace switches) into one recount
    Timer {
        id: checkDebounce
        interval: 150
        onTriggered: checkProc.running = true
    }

    // Event-driven: niri pushes window/workspace/overview events; no polling.
    Process {
        id: eventProc
        command: ["niri", "msg", "event-stream"]
        running: true

        onStarted: {
            checkProc.running = true;
            overviewProc.running = true;
        }

        stdout: SplitParser {
            onRead: data => {
                // Parse "Overview toggled: true/false"
                if (data.indexOf("Overview toggled") !== -1) {
                    root.overviewOpen = data.indexOf("true") !== -1;
                }
                if (data.indexOf("Window") !== -1 || data.indexOf("Workspace") !== -1) {
                    checkDebounce.restart();
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
