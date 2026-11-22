import QtQuick
import Quickshell
import Quickshell.Io

// What the monitor shows. While the monitor is open, and only then, it
// reads the system every two seconds (system-readings.sh) and lays the
// readings out as the monitor's panels. Processor use and network speed
// are worked out from the difference between two readings, and those and
// the memory in use are kept for a couple of minutes for the graphs.
//
// A panel is { title, alert, rows }, and may ask for its own `valueColumn`
// and `levelCells`. The rows are the kinds Pages.qml describes, and three
// more that only the monitor uses:
//   kind "graph"  a history (`samples`, each 0 to 1), then `value`. With
//                 `low` and `high` it draws only that band of the scale,
//                 which is how a graph gets to be several rows tall.
//   kind "bars"   several levels side by side (`levels`), then `value`
//   kind "busy"   a spinner, then `value`
// A wide panel's labels have room for nine characters and a narrow one's
// for seven.
Scope {
    id: readings

    // The shell root (shell.qml).
    required property var shell

    // --- The latest reading, by section name: a list of lines each ---
    property var sections: ({})

    // --- Worked out from two readings ---
    // How busy the processor is, from 0 to 1: all cores together, each
    // core, and the last minutes of the first for a graph.
    property real processorUse: 0
    property var coreUse: []
    property var processorHistory: []
    // The share of memory in use, over the same time.
    property var memoryHistory: []
    // Bytes a second down and up, and their recent history.
    property real downRate: 0
    property real upRate: 0
    property var downHistory: []
    property var upHistory: []
    // Bytes received and sent since the machine started.
    property real receivedTotal: 0
    property real sentTotal: 0
    // The counters of the reading before, to take differences from.
    property var earlierCores: []
    property var earlierNetwork: null

    // Two samples for each cell of the widest graph (Monitor.qml).
    readonly property int historyLength: 68

    Process {
        id: reader

        command: ["sh", Quickshell.shellDir + "/system-readings.sh"]
        stdout: StdioCollector {
            onStreamFinished: readings.take(text)
        }
    }

    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: readings.shell.monitorOpen
        onTriggered: reader.running = true
    }

    // Split a reading into its sections and work out what changes over time.
    function take(text: string): void {
        const sections = {};
        let lines = [];
        for (const line of text.split("\n")) {
            if (line.startsWith("== ")) {
                lines = [];
                sections[line.slice(3)] = lines;
            } else if (line !== "") {
                lines.push(line);
            }
        }
        readings.sections = sections;
        readings.takeProcessor(sections.processor || []);
        const memoryTotal = readings.memory("MemTotal");
        if (memoryTotal > 0)
            readings.memoryHistory = readings.extended(readings.memoryHistory, 1 - readings.memory("MemAvailable") / memoryTotal);
        readings.takeNetwork(sections.network || []);
    }

    // The lines of one section, or none.
    function section(name: string): var {
        return readings.sections[name] || [];
    }

    // A history with one more sample, kept to its length.
    function extended(history: var, sample: real): var {
        const longer = history.concat([sample]);
        return longer.slice(Math.max(0, longer.length - readings.historyLength));
    }

    // Each line is "cpu" or "cpuN" and the time spent so far in each state:
    // user, nice, system, idle, waiting for disk, and four kinds of interrupt
    // and stolen time. Busy is everything but idle and waiting.
    function takeProcessor(lines: var): void {
        const cores = [];
        for (const line of lines) {
            const fields = line.trim().split(/\s+/);
            const times = fields.slice(1, 9).map(Number);
            let total = 0;
            for (const time of times)
                total += time;
            cores.push({
                busy: total - times[3] - times[4],
                total: total
            });
        }
        const use = [];
        for (let index = 0; index < cores.length; index++) {
            const earlier = readings.earlierCores[index];
            const elapsed = earlier !== undefined ? cores[index].total - earlier.total : 0;
            use.push(elapsed > 0 ? (cores[index].busy - earlier.busy) / elapsed : 0);
        }
        readings.earlierCores = cores;
        if (use.length === 0)
            return;
        // The first line is all cores together.
        readings.processorUse = use[0];
        readings.coreUse = use.slice(1);
        readings.processorHistory = readings.extended(readings.processorHistory, use[0]);
    }

    // Each line is an interface name, a colon, then counters: bytes
    // received is the first and bytes sent the ninth. The loopback
    // interface is the machine talking to itself and is left out.
    function takeNetwork(lines: var): void {
        let received = 0;
        let sent = 0;
        for (const line of lines) {
            const colon = line.indexOf(":");
            if (line.slice(0, colon).trim() === "lo")
                continue;
            const counters = line.slice(colon + 1).trim().split(/\s+/).map(Number);
            received += counters[0];
            sent += counters[8];
        }
        readings.receivedTotal = received;
        readings.sentTotal = sent;
        const now = Date.now();
        const earlier = readings.earlierNetwork;
        readings.earlierNetwork = {
            received: received,
            sent: sent,
            time: now
        };
        if (earlier === null)
            return;
        const seconds = (now - earlier.time) / 1000;
        if (seconds <= 0)
            return;
        readings.downRate = Math.max(0, (received - earlier.received) / seconds);
        readings.upRate = Math.max(0, (sent - earlier.sent) / seconds);
        readings.downHistory = readings.extended(readings.downHistory, readings.downRate);
        readings.upHistory = readings.extended(readings.upHistory, readings.upRate);
    }

    // --- Putting numbers into words ---
    // Kilobytes as megabytes or gigabytes, e.g. 6.2G.
    function size(kilobytes: real): string {
        const gigabytes = kilobytes / 1048576;
        if (gigabytes >= 10)
            return Math.round(gigabytes) + "G";
        if (gigabytes >= 1)
            return gigabytes.toFixed(1) + "G";
        return Math.round(kilobytes / 1024) + "M";
    }

    // Bytes a second, e.g. 1.2M/s.
    function rate(bytes: real): string {
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + "M/s";
        if (bytes >= 1024)
            return Math.round(bytes / 1024) + "K/s";
        return Math.round(bytes) + "B/s";
    }

    // Seconds as days, hours and minutes, e.g. 6 h 37 min.
    function duration(seconds: real): string {
        const minutes = Math.floor(seconds / 60);
        const days = Math.floor(minutes / 1440);
        const hours = Math.floor((minutes % 1440) / 60);
        if (days > 0)
            return days + " d " + hours + " h";
        if (hours > 0)
            return hours + " h " + (minutes % 60) + " min";
        return minutes + " min";
    }

    function percent(share: real): string {
        return Math.round(share * 100) + "%";
    }

    // A history as shares of its own largest value, for a graph.
    function scaled(history: var): var {
        let largest = 0;
        for (const sample of history)
            largest = Math.max(largest, sample);
        if (largest === 0)
            return history;
        return history.map(sample => sample / largest);
    }

    // One number out of the memory section, in kilobytes.
    function memory(name: string): real {
        for (const line of readings.section("memory")) {
            if (line.startsWith(name + ":"))
                return Number(line.split(/\s+/)[1]);
        }
        return 0;
    }

    // The same rows with blank lines added to make this many.
    function padded(rows: var, count: int): var {
        const longer = rows.slice();
        while (longer.length < count)
            longer.push({
                label: "",
                kind: "note"
            });
        return longer;
    }

    // A graph several rows tall: one "graph" row for each band of the
    // scale, the highest first. The first row carries the label and value.
    function tallGraph(label: string, value: string, samples: var, rowCount: int): var {
        const rows = [];
        for (let row = 0; row < rowCount; row++) {
            const band = rowCount - 1 - row;
            rows.push({
                label: row === 0 ? label : "",
                kind: "graph",
                value: row === 0 ? value : "",
                samples: samples,
                low: band / rowCount,
                high: (band + 1) / rowCount
            });
        }
        return rows;
    }

    // --- The panels ---
    // The monitor is bands of panels, top to bottom. The panels of a band
    // sit side by side: two wide ones or three narrow ones.
    // The power panel's rows are also the top of the panel that drops out
    // of the bar's battery (Pages.qml).
    readonly property var power: powerPanel()
    readonly property var bands: [band([processorPanel(), memoryPanel()]), band([networkPanel(), processesPanel()]), band([storagePanel(), power, systemPanel()])]

    // These panels with blank rows added, so that all are as tall as the
    // tallest of them.
    function band(panels: var): var {
        let tallest = 0;
        for (const panel of panels)
            tallest = Math.max(tallest, panel.rows.length);
        const even = [];
        for (const panel of panels) {
            even.push({
                title: panel.title,
                alert: panel.alert,
                valueColumn: panel.valueColumn,
                levelCells: panel.levelCells,
                rows: readings.padded(panel.rows, tallest)
            });
        }
        return even;
    }

    function processorPanel(): var {
        const load = (readings.section("load")[0] || "").split(" ").slice(0, 3).join(" ");
        const degrees = Number(readings.section("temperature")[0] || 0) / 1000;
        const hot = degrees >= 90;
        const rows = readings.tallGraph("Use", readings.percent(readings.processorUse), readings.processorHistory, 3);
        rows.push({
            label: "Cores",
            kind: "bars",
            value: String(readings.coreUse.length),
            levels: readings.coreUse
        });
        rows.push({
            label: "Load",
            kind: "text",
            value: load + "  over 1, 5 and 15 minutes"
        });
        rows.push({
            label: "Heat",
            kind: "level",
            value: Math.round(degrees) + "°",
            level: degrees / 100,
            alert: hot
        });
        return {
            title: "Processor",
            alert: hot,
            rows: rows
        };
    }

    function memoryPanel(): var {
        const total = readings.memory("MemTotal");
        const available = readings.memory("MemAvailable");
        const used = total - available;
        const cached = readings.memory("Cached");
        const swapTotal = readings.memory("SwapTotal");
        const swapUsed = swapTotal - readings.memory("SwapFree");
        const rows = readings.tallGraph("Used", readings.size(used) + " of " + readings.size(total), readings.memoryHistory, 3);
        rows.push({
            label: "Cache",
            kind: "level",
            value: readings.size(cached),
            level: total > 0 ? cached / total : 0
        });
        rows.push({
            label: "Swap",
            kind: "level",
            value: readings.size(swapUsed) + " of " + readings.size(swapTotal),
            level: swapTotal > 0 ? swapUsed / swapTotal : 0
        });
        rows.push({
            label: "Free",
            kind: "text",
            value: readings.size(available)
        });
        return {
            title: "Memory",
            alert: false,
            rows: rows
        };
    }

    function networkPanel(): var {
        const online = readings.shell.online;
        const down = readings.tallGraph("Down", readings.rate(readings.downRate), readings.scaled(readings.downHistory), 2);
        const up = readings.tallGraph("Up", readings.rate(readings.upRate), readings.scaled(readings.upHistory), 2);
        const rows = down.concat(up);
        rows.push({
            label: "Wi-Fi",
            kind: "signal",
            value: readings.shell.networkName,
            level: readings.shell.networkSignal,
            alert: !online
        });
        rows.push({
            label: "Total",
            kind: "text",
            value: readings.size(readings.receivedTotal / 1024) + " down, " + readings.size(readings.sentTotal / 1024) + " up since it started"
        });
        return {
            title: "Network",
            alert: !online,
            rows: rows
        };
    }

    // The processes using the most memory.
    function processesPanel(): var {
        const total = readings.memory("MemTotal");
        const rows = [];
        for (const line of readings.section("processes").slice(0, 6)) {
            // The name may hold spaces; the number is the last field.
            const lastSpace = line.lastIndexOf(" ");
            const kilobytes = Number(line.slice(lastSpace + 1));
            rows.push({
                label: line.slice(0, lastSpace).trim(),
                kind: "level",
                value: readings.size(kilobytes),
                level: total > 0 ? kilobytes / total : 0
            });
        }
        rows.push({
            label: "Running",
            kind: "text",
            value: (readings.section("processCount")[0] || "0") + " processes"
        });
        return {
            title: "Processes",
            alert: false,
            // Process names are long.
            valueColumn: 22,
            levelCells: 26,
            rows: rows
        };
    }

    function storagePanel(): var {
        const rows = [];
        let full = false;
        for (const line of readings.section("storage")) {
            const fields = line.split(" ");
            const share = Number(fields[1]) / Number(fields[0]);
            const nearlyFull = share >= 0.9;
            if (nearlyFull)
                full = true;
            rows.push({
                label: fields[2],
                kind: "level",
                value: readings.percent(share) + " of " + readings.size(Number(fields[0])),
                level: share,
                alert: nearlyFull
            });
        }
        return {
            title: "Storage",
            alert: full,
            rows: rows
        };
    }

    function powerPanel(): var {
        const shell = readings.shell;
        const device = shell.batteryDevice;
        if (!shell.batteryPresent) {
            return {
                title: "Power",
                alert: false,
                rows: [
                    {
                        label: "Power",
                        kind: "text",
                        value: "from the mains, no battery"
                    }
                ]
            };
        }
        const low = shell.battery <= 0.2 && !shell.charging;
        const seconds = shell.charging ? device.timeToFull : device.timeToEmpty;
        const rows = [
            {
                label: "Charge",
                kind: "level",
                value: readings.percent(shell.battery),
                level: shell.battery,
                alert: low
            },
            {
                label: "Rate",
                kind: "text",
                value: Math.abs(device.changeRate).toFixed(1) + " W " + (shell.charging ? "in" : "out")
            },
            {
                label: shell.charging ? "Full in" : "Left",
                kind: "text",
                value: seconds > 0 ? readings.duration(seconds) : "working it out",
                alert: low
            }
        ];
        if (device.healthSupported) {
            rows.push({
                label: "Health",
                kind: "text",
                value: Math.round(device.healthPercentage) + "% of new"
            });
        }
        return {
            title: "Power",
            alert: low,
            rows: rows
        };
    }

    // The machine itself, what is being built, and its services.
    function systemPanel(): var {
        const uptime = Number((readings.section("uptime")[0] || "0").split(" ")[0]);
        // The system's generation number, out of a link named "system-287-link".
        const link = (readings.section("generation")[0] || "").split("-");
        const generation = link.length >= 2 ? link[1] : "";
        const builders = Number(readings.section("builders")[0] || 0);
        const running = readings.section("running");
        const failed = readings.section("failed");
        return {
            title: "System",
            alert: failed.length > 0,
            rows: [
                {
                    label: "Host",
                    kind: "text",
                    value: readings.section("host")[0] || ""
                },
                {
                    label: "Up",
                    kind: "text",
                    value: readings.duration(uptime)
                },
                {
                    label: "Kernel",
                    kind: "text",
                    value: "Linux " + (readings.section("kernel")[0] || "")
                },
                {
                    label: "System",
                    kind: "text",
                    value: "generation " + generation
                },
                {
                    label: "Build",
                    kind: builders > 0 ? "busy" : "text",
                    value: builders > 0 ? builders + " build processes" : "idle"
                },
                {
                    label: "Running",
                    kind: "text",
                    value: (running[0] || "0") + " services, " + (running[1] || "0") + " yours"
                },
                {
                    label: "Failed",
                    kind: "text",
                    value: failed.length === 0 ? "none" : failed.join(", "),
                    alert: failed.length > 0
                }
            ]
        };
    }
}
