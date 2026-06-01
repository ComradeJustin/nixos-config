import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import ".." as Root

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

    // ── Lyrics (LRCLIB) ──
    property var lyrics: []           // [{time: seconds, text: "line"}, ...]
    property string currentLyric: ""
    property string nextLyric: ""
    property bool hasLyrics: lyrics.length > 0
    property bool fetchingLyrics: false
    property string _lyricsTrackKey: ""  // "artist|title" to avoid re-fetching same track

    onTrackTitleChanged: { _fetchLyricsIfNeeded(); _notifDebounce.restart(); }
    onTrackArtistChanged: { _fetchLyricsIfNeeded(); _notifDebounce.restart(); }
    // Capture the current track as the baseline when playback starts, so the
    // first change *after* pressing play notifies (and a resume never does).
    onIsPlayingChanged: _notifDebounce.restart()

    function _cleanTitle(title) {
        // Strip Spotify suffixes that break LRCLIB matching
        return title
            .replace(/\s*\(feat\..*?\)/gi, "")
            .replace(/\s*\(ft\..*?\)/gi, "")
            .replace(/\s*\(with\s+.*?\)/gi, "")
            .replace(/\s*\(.*?remaster.*?\)/gi, "")
            .replace(/\s*\(.*?deluxe.*?\)/gi, "")
            .replace(/\s*\(.*?bonus.*?\)/gi, "")
            .replace(/\s*\(.*?edition.*?\)/gi, "")
            .replace(/\s*\(.*?version.*?\)/gi, "")
            .replace(/\s*\(.*?mix\)/gi, "")
            .replace(/\s*-\s*remaster.*$/gi, "")
            .replace(/\s*-\s*deluxe.*$/gi, "")
            .replace(/\s*-\s*bonus.*$/gi, "")
            .trim();
    }

    function _fetchLyricsIfNeeded() {
        let key = trackArtist + "|" + trackTitle;
        if (key === _lyricsTrackKey || trackTitle.length === 0) return;
        _lyricsTrackKey = key;
        lyrics = [];
        currentLyric = "";
        nextLyric = "";
        fetchingLyrics = true;
        // Try exact match first
        lyricsProc._useSearch = false;
        lyricsProc.command = ["curl", "-s", "--max-time", "5",
            "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(trackArtist)
            + "&track_name=" + encodeURIComponent(trackTitle)];
        lyricsProc.running = true;
    }

    function _parseLrc(lrcText) {
        let lines = lrcText.split("\n");
        let parsed = [];
        for (let i = 0; i < lines.length; i++) {
            let match = lines[i].match(/^\[(\d+):(\d+)\.(\d+)\]\s*(.*)/);
            if (match) {
                let secs = parseInt(match[1]) * 60 + parseInt(match[2]) + parseInt(match[3]) / 100;
                let text = match[4].trim();
                if (text.length > 0) parsed.push({time: secs, text: text});
            }
        }
        parsed.sort((a, b) => a.time - b.time);
        return parsed;
    }

    function _updateCurrentLyric() {
        if (lyrics.length === 0) { currentLyric = ""; nextLyric = ""; return; }
        let pos = root.position;
        let idx = -1;
        for (let i = lyrics.length - 1; i >= 0; i--) {
            if (lyrics[i].time <= pos) { idx = i; break; }
        }
        currentLyric = idx >= 0 ? lyrics[idx].text : "";
        nextLyric = idx + 1 < lyrics.length ? lyrics[idx + 1].text : "";
    }

    Timer {
        interval: 1000; repeat: true; running: root.hasMedia
        onTriggered: {
            if (root.player) {
                root.player.positionChanged();
                root.position = root.player.position ?? 0;
                root.length = root.player.length ?? 0;
                root._updateCurrentLyric();
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

    // ── Now-playing track-change notifications ──
    // One notification per REAL track change. The title→artist→art burst from a
    // single change is coalesced by a debounce; the "artist|title" key stops the
    // same track re-notifying; the first detection is treated as a baseline (so
    // music already playing at startup doesn't fire); only fires while playing.
    // No synchronous tag → each change is its own history entry grouped under
    // "Now Playing" (rather than collapsing onto one). Gated by config.
    property string _notifTrackKey: ""
    property bool _notifInitialized: false

    Timer {
        id: _notifDebounce
        interval: 600
        onTriggered: {
            if (!root.isPlaying || root.trackTitle.length === 0) return;
            let key = root.trackArtist + "|" + root.trackTitle;
            if (key === root._notifTrackKey) return;          // same track
            let firstTime = !root._notifInitialized;
            root._notifTrackKey = key;                        // track the current song...
            root._notifInitialized = true;                    // ...even while disabled
            if (firstTime) return;                            // startup baseline — no notify
            if (!Root.Config.features.nowPlayingNotifications) return;
            root._fireTrackNotify(root.trackTitle, root.trackArtist, root.trackArtUrl);
        }
    }

    // createObject per fire so a hot-reload never leaves a Process with stale
    // argv cached (same rationale as PowerService).
    property Component _notifyRunner: Component {
        Process {
            property var argv: []
            command: argv
            running: true
            onExited: Qt.callLater(() => destroy())
        }
    }

    // Album art: notify-send -i needs a local PATH, but MPRIS art is usually an
    // http URL (Spotify) which the notification server's cp-based copy can't
    // fetch — so download it to a temp file first, then notify. Local art is
    // passed straight through. Title/artist go via the argv array (never a shell
    // string) so odd characters in metadata can't break or inject.
    readonly property string _npArtPath: "/tmp/qs-nowplaying-art"
    property string _npTitle: ""
    property string _npArtist: ""

    function _fireTrackNotify(title, artist, art) {
        _npTitle = title;
        _npArtist = artist;
        if (art && (art.indexOf("http://") === 0 || art.indexOf("https://") === 0)) {
            _artProc.command = ["curl", "-s", "--max-time", "4", "-o", _npArtPath, art];
            _artProc.running = true;       // _doNotify fires on exit (below)
        } else if (art && art.indexOf("file://") === 0) {
            // Pass a RAW path (strip file://) so NotifService SNAPSHOTS it — it
            // only copies "/"-prefixed paths. Without this a local player that
            // reuses one art file makes older toasts lose their covers when it's
            // overwritten on the next track.
            _doNotify(art.substring(7));
        } else if (art && art.indexOf("/") === 0) {
            _doNotify(art);
        } else {
            _doNotify("");
        }
    }

    function _doNotify(artPath) {
        let argv = ["notify-send", "-a", "Now Playing", "-t", "5000"];
        if (artPath && artPath.length > 0) argv.push("-i", artPath);
        argv.push(_npTitle.length > 0 ? _npTitle : "Now Playing");
        if (_npArtist.length > 0) argv.push(_npArtist);
        let p = _notifyRunner.createObject(root, { argv: argv });
        if (!p) console.log("PlayerService: failed to spawn track notify");
    }

    Process {
        id: _artProc
        onExited: (code, status) => root._doNotify(code === 0 ? root._npArtPath : "")
    }

    Process {
        id: lyricsProc
        property string buffer: ""
        property bool _useSearch: false
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { lyricsProc.buffer += data; }
        }
        onExited: (code, status) => {
            let buf = lyricsProc.buffer;
            lyricsProc.buffer = "";

            if (code !== 0 || buf.length === 0) {
                // If exact match failed, try with cleaned title
                if (!lyricsProc._useSearch) {
                    let cleaned = root._cleanTitle(root.trackTitle);
                    if (cleaned !== root.trackTitle) {
                        lyricsProc._useSearch = false;
                        lyricsProc.command = ["curl", "-s", "--max-time", "5",
                            "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(root.trackArtist)
                            + "&track_name=" + encodeURIComponent(cleaned)];
                        lyricsProc.running = true;
                        return;
                    }
                    // Cleaned title same as original, skip to search
                    lyricsProc._useSearch = true;
                    lyricsProc.command = ["curl", "-s", "--max-time", "5",
                        "https://lrclib.net/api/search?track_name=" + encodeURIComponent(root._cleanTitle(root.trackTitle))
                        + "&artist_name=" + encodeURIComponent(root.trackArtist)];
                    lyricsProc.running = true;
                    return;
                }
                root.fetchingLyrics = false;
                return;
            }

            try {
                let json = JSON.parse(buf);

                if (!lyricsProc._useSearch) {
                    // Exact/cleaned match response — single object
                    let lrc = json.syncedLyrics || "";
                    if (lrc.length > 0) {
                        root.lyrics = root._parseLrc(lrc);
                        root._updateCurrentLyric();
                        root.fetchingLyrics = false;
                        return;
                    }
                    // No synced lyrics in result, try search
                    lyricsProc._useSearch = true;
                    lyricsProc.command = ["curl", "-s", "--max-time", "5",
                        "https://lrclib.net/api/search?track_name=" + encodeURIComponent(root._cleanTitle(root.trackTitle))
                        + "&artist_name=" + encodeURIComponent(root.trackArtist)];
                    lyricsProc.running = true;
                    return;
                }

                // Search response — array, pick first with syncedLyrics
                if (Array.isArray(json)) {
                    for (let i = 0; i < json.length; i++) {
                        let lrc = json[i].syncedLyrics || "";
                        if (lrc.length > 0) {
                            root.lyrics = root._parseLrc(lrc);
                            root._updateCurrentLyric();
                            break;
                        }
                    }
                }
            } catch(e) { /* no lyrics available */ }
            root.fetchingLyrics = false;
        }
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
