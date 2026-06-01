import Quickshell
import Quickshell.Io
import QtQuick
import ".." as Root

// Wallpaper data/IO service — extracted from WallpaperView so the view is
// pure UI. Owns the local wallpaper model + thumbnail cache, the current
// wallpaper, applying via awww, the wallhaven.cc online search/tag lookup,
// and downloads. The view drives it through the functions below and binds to
// its state; search-form options (categories/purity/resolution/sort) live in
// the view and are passed in per query.
//
// Registered in shell.qml as "wallpaper" → ServiceManager.wallpaper.
Scope {
    id: svc

    // ── Config ──
    property string wallpaperDir: Root.Theme.wpDirectory
    property string cacheDir: (Quickshell.env("HOME") || "/home/justin") + "/.cache/quickshell/wallpaper-thumbs"

    // ── Local state ──
    readonly property alias wallpapers: wpModel
    property string currentWallpaper: ""
    property bool scanned: false

    // ── Online (wallhaven) state ──
    property var onlineResults: []
    property bool onlineSearching: false
    property string onlineQuery: ""
    property int onlinePage: 1
    property int onlineTotalPages: 1
    property bool onlineLoadingMore: false
    property var tagSuggestions: []
    property bool tagSearching: false

    // ── Per-query search options (set by searchOnline/loadMore before running) ──
    property string _cats: "111"
    property string _purity: "100"
    property string _res: "1920x1080"
    property string _sorting: "relevance"

    // Emitted whenever a wallpaper is applied (view bubbles this to close Spotlight).
    signal wallpaperApplied()
    // Emitted after a directory (re)scan completes.
    signal rescanned()

    ListModel { id: wpModel }

    // ── Public API ──────────────────────────────────────────────────────

    // Scan once if not yet scanned; otherwise no-op (caller refreshes its view).
    function ensureScanned() {
        if (!scanned)
            scanProc.running = true;
    }

    // Force a rescan (filesystem watcher / after download).
    function forceRescan() {
        scanned = false;
        scanProc.running = true;
    }

    // Query the live current wallpaper.
    function queryCurrent() {
        currentProc.running = true;
    }

    // Apply a local wallpaper by path.
    function apply(path) {
        if (!path)
            return;
        setProc.wallpaper = path;
        setProc.running = true;
        wallpaperApplied();
    }

    // Online search. opts = { categories, purity, resolution, sorting }.
    function searchOnline(query, page, opts) {
        if (!query || query.trim().length === 0)
            return;
        let p = page || 1;
        onlineQuery = query.trim();
        if (opts) {
            if (opts.categories !== undefined) _cats = opts.categories;
            if (opts.purity !== undefined) _purity = opts.purity;
            if (opts.resolution !== undefined) _res = opts.resolution;
            if (opts.sorting !== undefined) _sorting = opts.sorting;
        }
        if (p === 1) {
            onlineSearching = true;
            onlineResults = [];
            tagSuggestions = [];
        } else {
            onlineLoadingMore = true;
        }
        onlinePage = p;
        onlineSearchProc._appendMode = (p > 1);
        onlineSearchProc._buf = "";
        onlineSearchProc.running = true;
    }

    // Load the next page of the current online query, reusing the same opts.
    function loadMore(opts) {
        if (onlineLoadingMore || onlineSearching)
            return;
        if (onlinePage >= onlineTotalPages)
            return;
        searchOnline(onlineQuery, onlinePage + 1, opts);
    }

    // Look up tag suggestions for a query.
    function searchTags(query) {
        if (!query || query.trim().length < 2)
            return;
        tagSearchProc._tagQuery = query.trim();
        tagSearchProc._buf = "";
        tagSearchProc.running = true;
    }

    // Clear tag suggestions (e.g. when the query is too short).
    function clearTags() {
        tagSuggestions = [];
    }

    // Reset all online search state (when the view re-opens).
    function resetOnline() {
        onlineResults = [];
        onlineQuery = "";
        onlinePage = 1;
        onlineTotalPages = 1;
        onlineLoadingMore = false;
        tagSuggestions = [];
    }

    // Download an online wallpaper into the local dir, then apply + rescan.
    function downloadAndApply(url) {
        if (!url)
            return;
        downloadProc._url = url;
        downloadProc.running = true;
    }

    // ── Processes ───────────────────────────────────────────────────────

    // Scan wallpaper directory and generate thumbnails.
    // SECURITY: positional parameters prevent command injection.
    Process {
        id: scanProc
        property string expandedWpDir: svc.wallpaperDir.replace(/^~/, Quickshell.env("HOME") || "/home/justin")
        command: [
            "bash", "-c",
            'cache="$1"; wpdir="$2"; ' +
            'mkdir -p "$cache"; ' +
            'find "$wpdir" -maxdepth 2 -type f \\( ' +
            "-iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' " +
            "-o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' " +
            '\\) 2>/dev/null | sort | while IFS= read -r f; do ' +
            'hash=$(echo -n "$f" | sha256sum | cut -c1-16); ' +
            'thumb="$cache/${hash}.jpg"; ' +
            'if [ ! -f "$thumb" ] || [ "$f" -nt "$thumb" ]; then ' +
            'magick "${f}[0]" -thumbnail 320x192^ -gravity center -extent 320x192 -quality 85 "$thumb" 2>/dev/null || ' +
            'convert "${f}[0]" -thumbnail 320x192^ -gravity center -extent 320x192 -quality 85 "$thumb" 2>/dev/null || ' +
            'thumb="$f"; ' +
            'fi; ' +
            'printf "%s|%s\\n" "$f" "$thumb"; ' +
            'done',
            "--", svc.cacheDir, expandedWpDir
        ]

        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (line.length === 0) return;
                let sep = line.indexOf("|");
                let path = sep > 0 ? line.substring(0, sep) : line;
                let thumb = sep > 0 ? line.substring(sep + 1) : path;
                let name = path.substring(path.lastIndexOf("/") + 1);
                let dot = name.lastIndexOf(".");
                let label = dot > 0 ? name.substring(0, dot) : name;
                wpModel.append({ "wpPath": path, "wpThumb": thumb, "wpName": name, "wpLabel": label });
            }
        }
        onStarted: wpModel.clear()
        onExited: {
            svc.scanned = true;
            svc.rescanned();
        }
    }

    // Get current wallpaper.
    Process {
        id: currentProc
        command: ["bash", "-c", "awww query 2>/dev/null | head -1 | sed 's/.*image: //'"]
        stdout: SplitParser {
            onRead: data => { svc.currentWallpaper = data.trim(); }
        }
    }

    // Set wallpaper.
    // SECURITY: positional parameter safely passes the file path.
    Process {
        id: setProc
        property string wallpaper: ""
        command: [
            "sh", "-c",
            'exec awww img "$1" --transition-type wipe --transition-duration 1',
            "--", wallpaper
        ]
        onExited: { svc.currentWallpaper = wallpaper; }
    }

    // Watch wallpaper directory for changes (live detection).
    // Requires inotify-tools; fails gracefully if unavailable.
    // SECURITY: positional parameter safely passes the directory path.
    Process {
        id: watchProc
        property string expandedDir: svc.wallpaperDir.replace(/^~/, Quickshell.env("HOME") || "/home/justin")
        command: [
            "bash", "-c",
            'command -v inotifywait >/dev/null 2>&1 || exit 0; ' +
            'exec inotifywait -m -q -e create -e delete -e moved_to -e moved_from --format "%e" "$1"',
            "--", expandedDir
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                if (!rescanTimer.running)
                    rescanTimer.start();
            }
        }
    }

    // Debounce timer to avoid excessive rescans.
    Timer {
        id: rescanTimer
        interval: 500
        onTriggered: svc.forceRescan()
    }

    // Online search via wallhaven API.
    Process {
        id: onlineSearchProc
        property string _buf: ""
        property bool _appendMode: false
        command: [
            "bash", "-c",
            'q="$1"; cats="$2"; pur="$3"; res="$4"; sort="$5"; page="$6"; ' +
            'curl -sf "https://wallhaven.cc/api/v1/search?q=${q}&sorting=${sort}&categories=${cats}&purity=${pur}&atleast=${res}&page=${page}" 2>/dev/null',
            "--", svc.onlineQuery, svc._cats, svc._purity, svc._res, svc._sorting, svc.onlinePage.toString()
        ]
        stdout: SplitParser {
            onRead: line => { onlineSearchProc._buf += line + "\n"; }
        }
        onExited: (code) => {
            svc.onlineSearching = false;
            svc.onlineLoadingMore = false;
            if (code !== 0) { onlineSearchProc._buf = ""; return; }
            try {
                let d = JSON.parse(onlineSearchProc._buf);
                let results = [];
                if (d.data) {
                    for (let i = 0; i < d.data.length; i++) {
                        let w = d.data[i];
                        results.push({
                            id: w.id || "",
                            url: w.path || "",
                            thumbUrl: w.thumbs ? (w.thumbs.small || w.thumbs.original || "") : "",
                            resolution: w.resolution || "",
                            fileSize: w.file_size || 0
                        });
                    }
                }
                if (d.meta)
                    svc.onlineTotalPages = d.meta.last_page || 1;
                if (onlineSearchProc._appendMode)
                    svc.onlineResults = svc.onlineResults.concat(results);
                else
                    svc.onlineResults = results;
            } catch (e) {
                console.log("WallpaperService: online search parse error:", e);
            }
            onlineSearchProc._buf = "";
        }
    }

    // Tag suggestion lookup — searches Wallhaven's tag endpoint.
    Process {
        id: tagSearchProc
        property string _buf: ""
        property string _tagQuery: ""
        command: [
            "bash", "-c",
            'curl -sf "https://wallhaven.cc/api/v1/search?q=$1&sorting=relevance&categories=111&purity=100&atleast=1920x1080&page=1" 2>/dev/null',
            "--", _tagQuery
        ]
        stdout: SplitParser {
            onRead: line => { tagSearchProc._buf += line + "\n"; }
        }
        onExited: (code) => {
            if (code !== 0) { tagSearchProc._buf = ""; return; }
            try {
                let d = JSON.parse(tagSearchProc._buf);
                let tagMap = {};
                if (d.data) {
                    for (let i = 0; i < d.data.length; i++) {
                        let tags = d.data[i].tags;
                        if (!tags) continue;
                        for (let j = 0; j < tags.length; j++) {
                            let t = tags[j];
                            let name = t.name || "";
                            if (name.length > 0 && !tagMap[name]) {
                                tagMap[name] = { name: name, id: t.id || 0, count: 1 };
                            } else if (tagMap[name]) {
                                tagMap[name].count++;
                            }
                        }
                    }
                }
                let sorted = Object.values(tagMap).sort((a, b) => b.count - a.count);
                svc.tagSuggestions = sorted.slice(0, 8);
            } catch (e) {
                svc.tagSuggestions = [];
            }
            tagSearchProc._buf = "";
        }
    }

    // Download online wallpaper to local dir then apply.
    Process {
        id: downloadProc
        property string _url: ""
        property string expandedWpDir: svc.wallpaperDir.replace(/^~/, Quickshell.env("HOME") || "/home/justin")
        command: [
            "bash", "-c",
            'url="$1"; dir="$2"; mkdir -p "$dir"; ' +
            'fname=$(basename "$url"); dest="$dir/$fname"; ' +
            'curl -sfL -o "$dest" "$url" 2>/dev/null && echo "$dest"',
            "--", _url, expandedWpDir
        ]
        stdout: SplitParser {
            onRead: data => {
                let path = data.trim();
                if (path.length > 0) {
                    svc.apply(path);
                    // Rescan to include the new file.
                    svc.forceRescan();
                }
            }
        }
    }
}
