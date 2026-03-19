import Quickshell
import Quickshell.Io
import QtQuick

// Tracks window state for widget occlusion
Scope {
    id: root

    // True when widgets should be visible (no windows on active workspace)
    property bool widgetsVisible: windowCount === 0
    property int windowCount: 0

    Component.onCompleted: checkProc.running = true

    // Single combined check - gets active workspace and counts its windows
    Process {
        id: checkProc
        command: ["bash", "-c",
            "ws=$(niri msg workspaces 2>/dev/null | grep -E '^\\s*\\*' | awk '{print $2}'); " +
            "niri msg windows 2>/dev/null | grep -c \"Workspace ID: $ws\" || echo 0"
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

    // Poll regularly
    Timer {
        id: pollTimer
        interval: 500
        onTriggered: checkProc.running = true
    }

    // Also listen to niri events for faster response
    Process {
        id: eventProc
        command: ["niri", "msg", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: data => {
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
