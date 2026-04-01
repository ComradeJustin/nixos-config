import QtQuick
import Quickshell.Io

// Wraps the Process + SplitParser + Timer polling pattern.
// Usage:
//   ProcessPoller {
//       command: ["cat", "/sys/class/power_supply/BAT0/capacity"]
//       interval: 5000
//       onData: (line) => { root.capacity = parseInt(line) }
//   }
Item {
    id: root

    property var command: []
    property int interval: 5000
    property bool running: true

    signal data(string line)

    visible: false

    function restart() {
        proc.running = true;
    }

    Process {
        id: proc
        command: root.command
        running: root.running && root.command.length > 0

        stdout: SplitParser {
            onRead: line => { root.data(line); }
        }

        onExited: pollTimer.start()
    }

    Timer {
        id: pollTimer
        interval: root.interval
        onTriggered: {
            if (root.running) proc.running = true;
        }
    }
}
