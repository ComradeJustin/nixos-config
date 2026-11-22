import QtQuick
import Quickshell
import Quickshell.Io

// What the monitor shows. While the monitor is open, and only then, it
// reads the system every two seconds (system-readings.sh) and lays the
// readings out as the monitor's applets. Processor use and network speed
// are worked out from the difference between two readings.
//
// An applet is { title, alert, summary, rows }: four summary rows for its
// tile and the rows of its expanded view. The rows are the kinds Pages.qml
// describes. A tile's labels have room for seven characters and its values
// for about ten.
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
    // Bytes a second down and up, and their recent history.
    property real downRate: 0
    property real upRate: 0
    property var downHistory: []
    property var upHistory: []
    // The counters of the reading before, to take differences from.
    property var earlierCores: []
    property var earlierNetwork: null

    readonly property int historyLength: 60

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

    // Exactly four rows for a tile: the first four, or blank lines added
    // to make four, so every tile is the same height.
    function tileRows(rows: var): var {
        const four = rows.slice(0, 4);
        while (four.length < 4)
            four.push({
                label: "",
                kind: "note"
            });
        return four;
    }

    // --- The applets, in the order they sit in the grid ---
    readonly property var applets: [buildApplet(), processorApplet(), memoryApplet(), networkApplet(), storageApplet(), processesApplet(), powerApplet(), servicesApplet(), systemApplet()]

    // The system's generation number, out of a link named "system-287-link".
    function generation(): string {
        const link = readings.section("generation")[0] || "";
        const parts = link.split("-");
        return parts.length >= 2 ? parts[1] : "";
    }

    function buildApplet(): var {
        const builders = Number(readings.section("builders")[0] || 0);
        const building = builders > 0;
        const state = {
            label: "Status",
            kind: building ? "busy" : "text",
            value: building ? builders + " build processes" : "idle"
        };
        return {
            title: "Build",
            alert: false,
            summary: readings.tileRows([state,
                {
                    label: "System",
                    kind: "text",
                    value: "generation " + readings.generation()
                }
            ]),
            rows: [state,
                {
                    label: "System generation",
                    kind: "text",
                    value: readings.generation()
                }
            ]
        };
    }

    function processorApplet(): var {
        const load = (readings.section("load")[0] || "").split(" ").slice(0, 3).join(" ");
        const degrees = Number(readings.section("temperature")[0] || 0) / 1000;
        const hot = degrees >= 90;
        const heat = {
            label: "Heat",
            kind: "level",
            value: Math.round(degrees) + "°",
            level: degrees / 100,
            alert: hot
        };
        const rows = [
            {
                label: "All cores",
                kind: "graph",
                value: readings.percent(readings.processorUse),
                samples: readings.processorHistory
            }
        ];
        for (let core = 0; core < readings.coreUse.length; core++) {
            rows.push({
                label: "Core " + (core + 1),
                kind: "level",
                value: readings.percent(readings.coreUse[core]),
                level: readings.coreUse[core]
            });
        }
        rows.push({
            label: "Load average",
            kind: "text",
            value: load
        });
        rows.push(heat);
        return {
            title: "Processor",
            alert: hot,
            summary: [
                {
                    label: "Load",
                    kind: "graph",
                    value: readings.percent(readings.processorUse),
                    samples: readings.processorHistory
                },
                {
                    label: "Cores",
                    kind: "text",
                    value: String(readings.coreUse.length)
                },
                {
                    label: "Average",
                    kind: "text",
                    value: load
                },
                heat],
            rows: rows
        };
    }

    function memoryApplet(): var {
        const total = readings.memory("MemTotal");
        const used = total - readings.memory("MemAvailable");
        const cached = readings.memory("Cached");
        const swapTotal = readings.memory("SwapTotal");
        const swapUsed = swapTotal - readings.memory("SwapFree");
        const rows = [
            {
                label: "Used",
                kind: "level",
                value: readings.size(used) + " of " + readings.size(total),
                level: total > 0 ? used / total : 0
            },
            {
                label: "Cache",
                kind: "level",
                value: readings.size(cached),
                level: total > 0 ? cached / total : 0
            },
            {
                label: "Swap",
                kind: "level",
                value: readings.size(swapUsed) + " of " + readings.size(swapTotal),
                level: swapTotal > 0 ? swapUsed / swapTotal : 0
            }
        ];
        const top = readings.processRows(1);
        return {
            title: "Memory",
            alert: false,
            summary: [
                {
                    label: "Used",
                    kind: "level",
                    value: readings.size(used),
                    level: total > 0 ? used / total : 0
                },
                {
                    label: "Cache",
                    kind: "level",
                    value: readings.size(cached),
                    level: total > 0 ? cached / total : 0
                },
                {
                    label: "Swap",
                    kind: "level",
                    value: readings.size(swapUsed),
                    level: swapTotal > 0 ? swapUsed / swapTotal : 0
                },
                {
                    label: "Top",
                    kind: "text",
                    value: top.length > 0 ? top[0].label : ""
                }
            ],
            rows: rows.concat(readings.processRows(8))
        };
    }

    // The processes using the most memory, as level rows.
    function processRows(count: int): var {
        const total = readings.memory("MemTotal");
        const rows = [];
        for (const line of readings.section("processes").slice(0, count)) {
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
        return rows;
    }

    function networkApplet(): var {
        const online = readings.shell.online;
        const rows = [
            {
                label: "Down",
                kind: "graph",
                value: readings.rate(readings.downRate),
                samples: readings.scaled(readings.downHistory)
            },
            {
                label: "Up",
                kind: "graph",
                value: readings.rate(readings.upRate),
                samples: readings.scaled(readings.upHistory)
            },
            {
                label: "Wi-Fi",
                kind: "signal",
                value: readings.shell.networkName,
                level: readings.shell.networkSignal,
                alert: !online
            }
        ];
        return {
            title: "Network",
            alert: !online,
            summary: readings.tileRows(rows),
            rows: rows
        };
    }

    function storageApplet(): var {
        const rows = [];
        const summary = [];
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
            summary.push({
                label: fields[2],
                kind: "level",
                value: readings.percent(share),
                level: share,
                alert: nearlyFull
            });
        }
        return {
            title: "Storage",
            alert: full,
            summary: readings.tileRows(summary),
            rows: rows
        };
    }

    function processesApplet(): var {
        const rows = readings.processRows(12);
        rows.push({
            label: "Running",
            kind: "text",
            value: (readings.section("processCount")[0] || "0") + " processes"
        });
        return {
            title: "Processes",
            alert: false,
            summary: readings.processRows(4),
            rows: rows
        };
    }

    function powerApplet(): var {
        const shell = readings.shell;
        const device = shell.batteryDevice;
        if (!shell.batteryPresent) {
            const mains = [
                {
                    label: "Power",
                    kind: "text",
                    value: "from the mains, no battery"
                }
            ];
            return {
                title: "Power",
                alert: false,
                summary: readings.tileRows(mains),
                rows: mains
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
            summary: readings.tileRows(rows),
            rows: rows
        };
    }

    function servicesApplet(): var {
        const failed = readings.section("failed");
        const running = readings.section("running");
        const rows = [
            {
                label: "Failed",
                kind: "text",
                value: failed.length === 0 ? "none" : failed.length + " units",
                alert: failed.length > 0
            },
            {
                label: "System",
                kind: "text",
                value: (running[0] || "0") + " running"
            },
            {
                label: "Yours",
                kind: "text",
                value: (running[1] || "0") + " running"
            }
        ];
        for (const unit of failed) {
            rows.push({
                label: unit,
                kind: "line",
                note: "failed"
            });
        }
        return {
            title: "Services",
            alert: failed.length > 0,
            summary: readings.tileRows(rows),
            rows: rows
        };
    }

    function systemApplet(): var {
        const uptime = Number((readings.section("uptime")[0] || "0").split(" ")[0]);
        const rows = [
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
                value: "generation " + readings.generation()
            }
        ];
        return {
            title: "System",
            alert: false,
            summary: rows,
            rows: rows
        };
    }
}
