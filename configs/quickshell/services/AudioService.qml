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
    property string activeDeviceLabel: ""

    // Signals for OSD integration (named to avoid conflict with auto-generated property signals)
    signal volumeUpdated(int oldValue, int newValue)
    signal muteToggled(bool oldMuted, bool newMuted)
    signal deviceSwitched(string oldDevice, string newDevice)

    Component.onCompleted: { pollProc.running = true; sinkProc.running = true; sourceProc.running = true; devProc.running = true; }

    // Guard: ignore poll results briefly after a manual set to prevent jitter
    property bool suppressPoll: false
    Timer { id: suppressTimer; interval: 300; onTriggered: root.suppressPoll = false }

    function setVolume(v) {
        v = Math.max(0, Math.min(100, v));
        let old = root.volume;
        root.volume = v;
        if (old !== v) root.volumeUpdated(old, v);
        root.suppressPoll = true;
        suppressTimer.restart();
        setProc.vol = v;
        setProc.running = true;
    }

    function toggleMute() {
        let wasMuted = root.muted;
        root.muted = !root.muted;
        root.muteToggled(wasMuted, root.muted);
        root.suppressPoll = true;
        suppressTimer.restart();
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
        appSetProc.vol = v / 100;  // wpctl uses 0.0-1.0 scale
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
                if (root.suppressPoll) return;

                let wasMuted = root.muted;
                let wasVol = root.volume;

                let newMuted = data.indexOf("[MUTED]") !== -1;
                let newVol = wasVol;

                let p = data.split(" ");
                if (p.length >= 2) {
                    let f = parseFloat(p[1]);
                    if (!isNaN(f)) newVol = Math.round(f * 100);
                }

                // Update and emit signals
                if (newMuted !== wasMuted) {
                    root.muted = newMuted;
                    root.muteToggled(wasMuted, newMuted);
                }
                if (newVol !== wasVol) {
                    root.volume = newVol;
                    if (wasVol >= 0) root.volumeUpdated(wasVol, newVol);
                }
            }
        }
        onExited: pollTimer.start()
    }
    // Adaptive polling: faster when recently active
    property bool recentlyActive: false
    Timer { id: activityCooldown; interval: 2000; onTriggered: root.recentlyActive = false }
    function markActive() { recentlyActive = true; activityCooldown.restart(); }

    Timer { id: pollTimer; interval: root.recentlyActive ? 100 : 300; onTriggered: pollProc.running = true }
    Process { id: setProc; property int vol: 0; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", vol + "%"]; onStarted: root.markActive() }
    Process { id: muteProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }

    // ── Per-app volume (PipeWire native) ──
    // Use a temporary list to avoid flicker from clear/repopulate
    property var pendingApps: []

    Process {
        id: appScanProc
        command: ["bash", "-c",
            "pw-dump 2>/dev/null | jq -r '.[] | select(.info.props.\"media.class\" == \"Stream/Output/Audio\") | " +
            "[.id, (.info.props.\"application.name\" // \"Unknown\"), (.info.props.\"application.icon_name\" // \"\"), " +
            "(((.info.params.Props[0]?.volume // 1) * 100) | floor)] | @tsv'"
        ]
        stdout: SplitParser {
            onRead: data => {
                let p = data.split("\t");
                if (p.length < 4) return;
                root.pendingApps.push({ "appIdx": p[0], "appName": p[1] || "Unknown", "appIcon": p[2] || "", "appVol": parseInt(p[3]) || 100 });
            }
        }
        onStarted: root.pendingApps = []
        onExited: {
            // Smart update: only modify what changed to prevent flicker
            let newApps = root.pendingApps;
            let oldCount = root.appStreams.count;
            let newCount = newApps.length;

            // Update existing items or add new ones
            for (let i = 0; i < newCount; i++) {
                if (i < oldCount) {
                    // Update existing item if different
                    let old = root.appStreams.get(i);
                    let neu = newApps[i];
                    if (old.appIdx !== neu.appIdx || old.appName !== neu.appName || old.appVol !== neu.appVol) {
                        root.appStreams.set(i, neu);
                    }
                } else {
                    // Add new item
                    root.appStreams.append(newApps[i]);
                }
            }

            // Remove extra items from the end
            while (root.appStreams.count > newCount) {
                root.appStreams.remove(root.appStreams.count - 1);
            }
        }
    }
    Process { id: appSetProc; property string idx: ""; property real vol: 0; command: ["wpctl", "set-volume", idx, vol.toString()] }

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

    // ── Device label polling (for OSD) ──
    Process {
        id: devProc
        command: [
            "bash", "-c",
            "wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | " +
            "grep -oP 'node\\.description\\s*=\\s*\"\\K[^\"]+' || echo ''"
        ]
        stdout: SplitParser {
            onRead: data => {
                let name = data.trim();
                if (name.length === 0) return;

                let wasDevice = root.activeDeviceLabel;
                if (name !== wasDevice) {
                    root.activeDeviceLabel = name;
                    if (wasDevice.length > 0) {
                        root.deviceSwitched(wasDevice, name);
                    }
                }
            }
        }
        onExited: devPollTimer.start()
    }
    Timer { id: devPollTimer; interval: 800; onTriggered: devProc.running = true }
}
