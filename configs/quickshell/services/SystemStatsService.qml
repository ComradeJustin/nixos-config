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

    // Disk stats
    property real diskUsedGb: -1
    property real diskTotalGb: -1
    property int diskPercent: diskTotalGb > 0 ? Math.round(diskUsedGb / diskTotalGb * 100) : -1

    // Uptime
    property string uptime: ""

    // ── CPU history (sparkline data) ──
    // Lives here so it survives bar module re-creation (toggling features).
    // Persisted to /tmp so it also survives config reloads.
    property var cpuHistory: []
    property int historyMax: 30
    readonly property string _historyPath: "/tmp/qs-cpu-history.json"

    onCpuPercentChanged: {
        if (cpuPercent < 0) return;
        let h = cpuHistory.slice();
        h.push(cpuPercent / 100);
        if (h.length > historyMax) h.shift();
        cpuHistory = h;
    }

    // Persist history every 5 ticks (~10s at default poll rate) so we
    // don't thrash disk on every sample. Also save on any push that
    // fills the buffer to historyMax (ensures a full graph survives reload).
    property int _saveCounter: 0
    onCpuHistoryChanged: {
        _saveCounter++;
        if (_saveCounter >= 5 || cpuHistory.length === historyMax) {
            _saveCounter = 0;
            historySaveProc._json = JSON.stringify(cpuHistory);
            historySaveProc.running = true;
        }
    }

    Process {
        id: historySaveProc
        property string _json: "[]"
        command: ["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "--", _json, root._historyPath]
    }

    Process {
        id: historyLoadProc
        command: ["cat", root._historyPath]
        running: true
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    let arr = JSON.parse(data);
                    if (Array.isArray(arr) && arr.length > 0)
                        root.cpuHistory = arr.slice(-root.historyMax);
                } catch(e) {}
            }
        }
    }

    // ── RAM history (sparkline data) ──
    // Driven by ramUsedGb (a real) rather than ramPercent (an int) because
    // RAM usage is stable enough that the integer-rounded percentage often
    // doesn't change between polls, which would starve the graph of data.
    property var ramHistory: []

    onRamUsedGbChanged: {
        if (ramUsedGb < 0 || ramTotalGb <= 0) return;
        let h = ramHistory.slice();
        h.push(ramUsedGb / ramTotalGb);
        if (h.length > historyMax) h.shift();
        ramHistory = h;
    }

    // User identity
    // username comes from the USER env var (cheap, no subprocess). hostname
    // is read once at startup from /proc/sys/kernel/hostname — it almost
    // never changes during a session, so re-polling it is pointless.
    readonly property string username: Quickshell.env("USER") || ""
    property string hostname: ""

    property real prevIdle: 0
    property real prevTotal: 0

    Component.onCompleted: hostProc.running = true

    Process {
        id: hostProc
        command: ["cat", "/proc/sys/kernel/hostname"]
        stdout: SplitParser {
            onRead: data => { root.hostname = (data || "").trim(); }
        }
    }

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
        onExited: diskProc.running = true
    }

    Process {
        id: diskProc
        command: ["df", "--output=used,size", "-B1", "/"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(/\s+/);
                if (parts.length >= 2) {
                    let used = parseFloat(parts[0]);
                    let total = parseFloat(parts[1]);
                    if (total > 0 && !isNaN(used)) {
                        root.diskUsedGb = used / 1073741824;
                        root.diskTotalGb = total / 1073741824;
                    }
                }
            }
        }
        onExited: uptimeProc.running = true
    }

    Process {
        id: uptimeProc
        command: ["awk", "{d=int($1/86400);h=int($1%86400/3600);m=int($1%3600/60);if(d>0)printf\"%dd %dh\",d,h;else if(h>0)printf\"%dh %dm\",h,m;else printf\"%dm\",m}", "/proc/uptime"]
        stdout: SplitParser {
            onRead: data => { root.uptime = data.trim(); }
        }
        onExited: pollTimer.start()
    }

    Timer {
        id: pollTimer
        interval: Root.Config.behavior.systemStatsInterval
        onTriggered: cpuProc.running = true
    }
}
