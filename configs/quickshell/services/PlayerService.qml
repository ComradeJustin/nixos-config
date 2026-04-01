import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Scope {
    id: root

    property var player: {
        let players = Mpris.players.values;
        if (!players || players.length === 0) return null;
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i];
        }
        return players[0];
    }

    property bool isPlaying: player ? player.playbackState === MprisPlaybackState.Playing : false
    property bool hasMedia: player ? (player.trackTitle || "").length > 0 : false
    property string trackTitle:  player?.trackTitle ?? ""
    property string trackArtist: player?.trackArtist ?? ""
    property string trackArtUrl: player?.trackArtUrl ?? ""
    property real position: 0
    property real length: 0
    property var cavaBars: []

    property string displayText: {
        if (!hasMedia) return "";
        if (trackArtist.length > 0) return trackArtist + " — " + trackTitle;
        return trackTitle;
    }

    Timer {
        interval: 1000; repeat: true; running: root.hasMedia
        onTriggered: {
            if (root.player) {
                root.player.positionChanged();
                root.position = root.player.position ?? 0;
                root.length = root.player.length ?? 0;
            }
        }
    }

    function togglePlaying() { if (player && player.canTogglePlaying) player.isPlaying = !player.isPlaying; }
    function next() { if (player && player.canGoNext) player.next(); }
    function previous() { if (player && player.canGoPrevious) player.previous(); }
    function seek(secs) { if (player) player.position = secs; }

    function formatTime(secs) {
        if (secs <= 0) return "0:00";
        let s = Math.floor(secs);
        let m = Math.floor(s / 60);
        s = s % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Process {
        id: cavaProc
        command: ["bash", "-c",
            "cava -p /dev/stdin <<'EOF'\n[general]\nbars = 24\nframerate = 30\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nEOF"
        ]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let parts = data.trim().split(";").filter(s => s.length > 0);
                let v = [];
                for (let i = 0; i < parts.length; i++) { let n = parseInt(parts[i]); v.push(isNaN(n) ? 0 : n / 100); }
                if (v.length > 0) root.cavaBars = v;
            }
        }
    }
}
