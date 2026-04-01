import Quickshell
import QtQuick
import Quickshell.Io
import ".." as Root

Scope {
    id: root

    property int cpuPercent: -1
    property real ramUsedGb: -1
    property real ramTotalGb: -1
    property int ramPercent: ramTotalGb > 0 ? Math.round(ramUsedGb / ramTotalGb * 100) : -1

    property real prevIdle: 0
    property real prevTotal: 0

    Process {
        id: cpuProc
        command: ["head", "-1", "/proc/stat"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(/\s+/);
                if (parts.length < 5) return;
                let idle = parseFloat(parts[4]) + (parseFloat(parts[5]) || 0);
                let total = 0;
                for (let i = 1; i < parts.length; i++)
                    total += parseFloat(parts[i]) || 0;
                let dIdle = idle - root.prevIdle;
                let dTotal = total - root.prevTotal;
                if (root.prevTotal > 0 && dTotal > 0)
                    root.cpuPercent = Math.round(100 * (1 - dIdle / dTotal));
                root.prevIdle = idle;
                root.prevTotal = total;
            }
        }
        onExited: (code) => {
            if (code === 0) ramProc.running = true;
            else pollTimer.start();
        }
    }

    Process {
        id: ramProc
        command: ["awk", "/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf \"%d %d\", t, a}", "/proc/meminfo"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(/\s+/);
                if (parts.length >= 2) {
                    let totalKb = parseFloat(parts[0]);
                    let availKb = parseFloat(parts[1]);
                    if (totalKb > 0) {
                        root.ramTotalGb = totalKb / 1048576;
                        root.ramUsedGb = (totalKb - availKb) / 1048576;
                    }
                }
            }
        }
        onExited: pollTimer.start()
    }

    Timer {
        id: pollTimer
        interval: Root.Config.systemStatsInterval
        onTriggered: cpuProc.running = true
    }
}
