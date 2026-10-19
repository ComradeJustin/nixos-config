import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Audio state via Quickshell's native Pipewire service — fully event-driven.
// Replaces the old wpctl/pactl pollers (which spawned ~3 processes/second).
// Public API (properties, signals, functions) is unchanged for consumers:
// Bar wheel, AudioModule, ControlCenter/VolumeTab, Osd.
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

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource

    // A node's .audio values are only live while the node is tracked.
    PwObjectTracker { objects: Pipewire.nodes.values }

    onDefaultSinkChanged: { syncFromSink(); rebuildDevices(); }
    onDefaultSourceChanged: rebuildDevices()

    // Volume/mute changed externally (keyboard keys, another mixer, ...)
    Connections {
        target: root.defaultSink ? root.defaultSink.audio : null
        function onVolumeChanged() { root.syncFromSink(); }
        function onMutedChanged() { root.syncFromSink(); }
    }

    // Nodes appearing/disappearing (device plugged, app started/stopped).
    // Debounced: node bursts (e.g. an app opening several streams) rebuild once.
    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { rebuildTimer.restart(); }
    }
    Timer {
        id: rebuildTimer
        interval: 100
        onTriggered: { root.rebuildDevices(); root.rebuildApps(); }
    }

    Component.onCompleted: { syncFromSink(); rebuildDevices(); rebuildApps(); }

    // node.type is a flag set; true if it contains all bits of `flags`
    function hasType(node, flags) { return (node.type & flags) === flags; }

    function nodeById(id) {
        let all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++)
            if (all[i].id === id) return all[i];
        return null;
    }

    function syncFromSink() {
        let node = root.defaultSink;
        if (!node || !node.audio) return;

        let newVol = Math.round(node.audio.volume * 100);
        if (newVol !== root.volume) {
            let oldVol = root.volume;
            root.volume = newVol;
            root.volumeUpdated(oldVol, newVol);
        }

        let newMuted = node.audio.muted;
        if (newMuted !== root.muted) {
            let oldMuted = root.muted;
            root.muted = newMuted;
            root.muteToggled(oldMuted, newMuted);
        }

        let newLabel = node.description || node.nickname || node.name || "";
        if (newLabel.length > 0 && newLabel !== root.activeDeviceLabel) {
            let oldLabel = root.activeDeviceLabel;
            root.activeDeviceLabel = newLabel;
            if (oldLabel.length > 0) root.deviceSwitched(oldLabel, newLabel);
        }
    }

    function setVolume(v) {
        v = Math.max(0, Math.min(100, v));
        if (root.defaultSink && root.defaultSink.audio)
            root.defaultSink.audio.volume = v / 100;
        // Update immediately so the UI doesn't wait for the event echo
        if (v !== root.volume) {
            let oldVol = root.volume;
            root.volume = v;
            root.volumeUpdated(oldVol, v);
        }
    }

    function toggleMute() {
        if (root.defaultSink && root.defaultSink.audio)
            root.defaultSink.audio.muted = !root.defaultSink.audio.muted;
    }

    function setAppVolume(idx, v) {
        v = Math.max(0, Math.min(100, v));
        let node = nodeById(idx);
        if (node && node.audio) node.audio.volume = v / 100;
        for (let i = 0; i < appStreams.count; i++) {
            if (appStreams.get(i).appIdx === idx) {
                appStreams.setProperty(i, "appVol", v);
                break;
            }
        }
    }

    function refreshApps() { rebuildApps(); }
    function refreshDevices() { rebuildDevices(); }

    function setSink(name) {
        let all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            if (all[i].name === name) {
                Pipewire.preferredDefaultAudioSink = all[i];
                root.activeSink = name;
                break;
            }
        }
    }

    function setSource(name) {
        let all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            if (all[i].name === name) {
                Pipewire.preferredDefaultAudioSource = all[i];
                root.activeSource = name;
                break;
            }
        }
    }

    // App playback streams → appStreams model (roles: appIdx/appName/appIcon/appVol)
    function rebuildApps() {
        let all = Pipewire.nodes.values;
        let apps = [];
        for (let i = 0; i < all.length; i++) {
            let n = all[i];
            if (!hasType(n, PwNodeType.AudioOutStream) || !n.audio) continue;
            apps.push({
                "appIdx": n.id,
                "appName": n.properties["application.name"] || n.description || n.name || "Unknown",
                "appIcon": n.properties["application.icon-name"] || "",
                "appVol": Math.round(n.audio.volume * 100)
            });
        }

        // Smart update: only modify what changed to prevent flicker
        for (let i = 0; i < apps.length; i++) {
            if (i < appStreams.count) {
                let old = appStreams.get(i);
                let neu = apps[i];
                if (old.appIdx !== neu.appIdx || old.appName !== neu.appName || old.appVol !== neu.appVol)
                    appStreams.set(i, neu);
            } else {
                appStreams.append(apps[i]);
            }
        }
        while (appStreams.count > apps.length)
            appStreams.remove(appStreams.count - 1);
    }

    // Output/input devices → sinks/sources models (roles: devName/devDesc/devActive)
    function rebuildDevices() {
        sinks.clear();
        sources.clear();
        let all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            let n = all[i];
            if (n.isStream) continue;
            let desc = n.description || n.nickname || n.name;
            if (hasType(n, PwNodeType.AudioSink)) {
                let active = n === Pipewire.defaultAudioSink;
                sinks.append({ "devName": n.name, "devDesc": desc, "devActive": active });
                if (active) root.activeSink = n.name;
            } else if (hasType(n, PwNodeType.AudioSource)) {
                let active = n === Pipewire.defaultAudioSource;
                sources.append({ "devName": n.name, "devDesc": desc, "devActive": active });
                if (active) root.activeSource = n.name;
            }
        }
    }
}
