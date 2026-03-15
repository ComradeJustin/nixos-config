import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    property int volume: 0
    property bool muted: false
    property var appStreams: ListModel {}
    property var sinks: ListModel {}
    property var sources: ListModel {}
    property string activeSink: ""
    property string activeSource: ""

    Component.onCompleted: { pollProc.running = true; sinkProc.running = true; sourceProc.running = true; }

    function setVolume(v) {
        v = Math.max(0, Math.min(100, v));
        root.volume = v;
        setProc.vol = v;
        setProc.running = true;
    }

    function toggleMute() {
        root.muted = !root.muted;
        muteProc.running = true;
    }

    function setAppVolume(idx, v) {
        v = Math.max(0, Math.min(100, v));
        for (let i = 0; i < appStreams.count; i++) {
            if (appStreams.get(i).appIdx === idx) {
                appStreams.setProperty(i, "appVol", v);
                break;
            }
        }
        appSetProc.idx = idx;
        appSetProc.vol = v;
        appSetProc.running = true;
    }

    function refreshApps() { appScanProc.running = true; }
    function refreshDevices() { sinkProc.running = true; sourceProc.running = true; }

    function setSink(name) {
        root.activeSink = name;
        sinkSetProc.sinkName = name;
        sinkSetProc.running = true;
    }

    function setSource(name) {
        root.activeSource = name;
        sourceSetProc.sourceName = name;
        sourceSetProc.running = true;
    }

    // ── Master volume ──
    Process {
        id: pollProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                root.muted = data.indexOf("[MUTED]") !== -1;
                let p = data.split(" ");
                if (p.length >= 2) {
                    let f = parseFloat(p[1]);
                    if (!isNaN(f)) root.volume = Math.round(f * 100);
                }
            }
        }
        onExited: pollTimer.start()
    }
    Timer { id: pollTimer; interval: 300; onTriggered: pollProc.running = true }
    Process { id: setProc; property int vol: 0; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", vol + "%"] }
    Process { id: muteProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }

    // ── Per-app volume ──
    Process {
        id: appScanProc
        command: ["bash", "-c",
            "pactl list sink-inputs 2>/dev/null | awk '\n" +
            "  /Sink Input #/ { idx=$3; sub(/#/,\"\",idx) }\n" +
            "  /application.name/ { name=$0; sub(/.*= \"/,\"\",name); sub(/\"$/,\"\",name) }\n" +
            "  /application.icon_name/ { icon=$0; sub(/.*= \"/,\"\",icon); sub(/\"$/,\"\",icon) }\n" +
            "  /Volume:/ && idx { vol=$0; match(vol,/([0-9]+)%/,m); pct=m[1]; print idx \"\\t\" name \"\\t\" icon \"\\t\" pct; idx=\"\" }\n" +
            "'"
        ]
        stdout: SplitParser {
            onRead: data => {
                let p = data.split("\t");
                if (p.length < 4) return;
                root.appStreams.append({ "appIdx": p[0], "appName": p[1] || "Unknown", "appIcon": p[2] || "", "appVol": parseInt(p[3]) || 0 });
            }
        }
        onStarted: root.appStreams.clear()
    }
    Process { id: appSetProc; property string idx: ""; property int vol: 0; command: ["pactl", "set-sink-input-volume", idx, vol + "%"] }

    // ── Output devices (sinks) ──
    Process {
        id: sinkProc
        command: ["bash", "-c",
            "default=$(pactl get-default-sink 2>/dev/null); " +
            "pactl list short sinks 2>/dev/null | while read -r idx name driver fmt state; do " +
            "  desc=$(pactl list sinks 2>/dev/null | awk -v n=\"$name\" '/Name: / { found=($2==n) } found && /Description:/ { sub(/.*Description: /,\"\"); print; exit }'); " +
            "  active='no'; [ \"$name\" = \"$default\" ] && active='yes'; " +
            "  echo \"$name\t$desc\t$active\"; " +
            "done"
        ]
        stdout: SplitParser {
            onRead: data => {
                let p = data.split("\t");
                if (p.length < 3) return;
                root.sinks.append({ "devName": p[0], "devDesc": p[1] || p[0], "devActive": p[2] === "yes" });
                if (p[2] === "yes") root.activeSink = p[0];
            }
        }
        onStarted: root.sinks.clear()
    }
    Process { id: sinkSetProc; property string sinkName: ""; command: ["pactl", "set-default-sink", sinkName] }

    // ── Input devices (sources) ──
    Process {
        id: sourceProc
        command: ["bash", "-c",
            "default=$(pactl get-default-source 2>/dev/null); " +
            "pactl list short sources 2>/dev/null | grep -v '\\.monitor' | while read -r idx name driver fmt state; do " +
            "  desc=$(pactl list sources 2>/dev/null | awk -v n=\"$name\" '/Name: / { found=($2==n) } found && /Description:/ { sub(/.*Description: /,\"\"); print; exit }'); " +
            "  active='no'; [ \"$name\" = \"$default\" ] && active='yes'; " +
            "  echo \"$name\t$desc\t$active\"; " +
            "done"
        ]
        stdout: SplitParser {
            onRead: data => {
                let p = data.split("\t");
                if (p.length < 3) return;
                root.sources.append({ "devName": p[0], "devDesc": p[1] || p[0], "devActive": p[2] === "yes" });
                if (p[2] === "yes") root.activeSource = p[0];
            }
        }
        onStarted: root.sources.clear()
    }
    Process { id: sourceSetProc; property string sourceName: ""; command: ["pactl", "set-default-source", sourceName] }
}
