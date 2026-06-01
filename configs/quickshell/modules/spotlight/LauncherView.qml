import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.." as Root
import "../../components" as Components

// App launcher view for the Spotlight popup.
// Caches desktop entries on load, filters by search.
// Uses frecency scoring to boost recently/frequently launched apps.
SpotlightProvider {
    id: root
    implicitWidth: parent ? parent.width : 500
    implicitHeight: launchInner.implicitHeight

    // ── Provider identity ──
    providerKey: "launcher"
    providerLabel: "Apps"
    providerIcon: "󰍃"
    hasSearch: true
    hasGrid: false
    preferredWidth: Root.Theme.launchWidth
    preferredMaxHeight: Root.Theme.launchMaxHeight

    // ── Provider interface ──
    function activate() { resetSearch(); cascadeArmTimer.restart(); }
    function deactivate() {}
    function handleSearchText(text) {
        searchText = text;
        selectedIndex = 0;
        updateFilter();
    }
    function moveUp() { if (selectedIndex > 0) selectedIndex--; appFlick.ensureVisible(selectedIndex); }
    function moveDown() { if (selectedIndex < filteredIndices.length - 1) selectedIndex++; appFlick.ensureVisible(selectedIndex); }
    function accept() { launchSelected(); }

    property string searchText: ""
    property int selectedIndex: 0
    property var filteredIndices: []
    property int _cascadeGen: 0      // bumping this replays the result cascade (on open)

    signal launched()

    // Re-arm the cascade a tick after activate() so the Repeater has finished
    // rebuilding the (frecency-sorted) results before we replay. Keystroke
    // updates do NOT bump this, so typing filters instantly with no cascade.
    Timer { id: cascadeArmTimer; interval: 16; onTriggered: root._cascadeGen++ }

    // ── Frecency tracking ──
    // Stores { "appName": { count: N, lastUsed: timestamp } }
    // Score = count * recencyMultiplier, where recency decays over days.
    property var frecencyData: ({})
    property string frecencyPath: (Quickshell.env("HOME") || "/home/justin") + "/.cache/quickshell/app-frecency.json"

    function loadFrecency() {
        frecencyLoadProc.running = true;
    }

    function saveFrecency() {
        frecencySaveProc._json = JSON.stringify(frecencyData);
        frecencySaveProc.running = true;
    }

    function recordLaunch(appName) {
        let now = Date.now();
        let d = frecencyData;
        if (!d[appName]) d[appName] = { count: 0, lastUsed: 0 };
        d[appName].count++;
        d[appName].lastUsed = now;
        frecencyData = d;
        saveFrecency();
    }

    // Frecency score: count * recency_multiplier
    // Recency: 1.0 if used today, 0.7 if this week, 0.4 if this month, 0.2 if older
    function _frecencyScore(appName) {
        let entry = frecencyData[appName];
        if (!entry || entry.count === 0) return 0;
        let daysSince = (Date.now() - entry.lastUsed) / (1000 * 60 * 60 * 24);
        let recency = daysSince < 1 ? 1.0 : daysSince < 7 ? 0.7 : daysSince < 30 ? 0.4 : 0.2;
        return entry.count * recency;
    }

    Process {
        id: frecencyLoadProc
        command: ["cat", root.frecencyPath]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try { root.frecencyData = JSON.parse(data); }
                catch(e) { root.frecencyData = {}; }
            }
        }
        onExited: (code) => {
            if (code !== 0) root.frecencyData = {};
        }
    }

    Process {
        id: frecencySaveProc
        property string _json: "{}"
        command: [
            "bash", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"',
            "--", root.frecencyPath, _json
        ]
    }

    // Fuzzy score: returns 0 (no match) or a positive score.
    // Higher = better. Rewards: exact prefix > word-boundary >
    // substring > character-skip (fuzzy). Each query character must
    // appear in order somewhere in `text`.
    function _fuzzyScore(query, text) {
        if (query.length === 0) return 1;
        let tLen = text.length;
        let qLen = query.length;
        if (qLen > tLen) return 0;

        // Fast path: exact prefix
        if (text.startsWith(query)) return 100 + (qLen / tLen) * 50;

        // Fast path: substring
        let subIdx = text.indexOf(query);
        if (subIdx >= 0) return 60 + (qLen / tLen) * 30;

        // Fuzzy: each query char must appear in order
        let score = 0;
        let qi = 0;
        let prevMatch = -1;
        for (let ti = 0; ti < tLen && qi < qLen; ti++) {
            if (text[ti] === query[qi]) {
                // Bonus for consecutive matches
                if (prevMatch === ti - 1) score += 8;
                // Bonus for word-boundary match (after space, -, _)
                else if (ti === 0 || " -_".indexOf(text[ti - 1]) >= 0) score += 5;
                else score += 1;
                prevMatch = ti;
                qi++;
            }
        }
        if (qi < qLen) return 0; // Not all query chars found
        return score;
    }

    function updateFilter() {
        let query = searchText.toLowerCase();
        if (query.length === 0) {
            // No query: sort by frecency (most-used first), then alphabetical
            let scored = [];
            for (let i = 0; i < appModel.count; i++) {
                let item = appModel.get(i);
                let fs = _frecencyScore(item.appName);
                scored.push({ idx: i, score: fs });
            }
            scored.sort((a, b) => {
                if (b.score !== a.score) return b.score - a.score;
                // Alphabetical tiebreak
                let na = appModel.get(a.idx).appName.toLowerCase();
                let nb = appModel.get(b.idx).appName.toLowerCase();
                return na < nb ? -1 : na > nb ? 1 : 0;
            });
            filteredIndices = scored.map(s => s.idx);
        } else {
            // Score each app across name, comment, generic name, and binary name.
            // Frecency acts as a tiebreaker boost for equally-scored matches.
            let scored = [];
            for (let i = 0; i < appModel.count; i++) {
                let item = appModel.get(i);
                let nameScore   = _fuzzyScore(query, item.appName.toLowerCase()) * 1.0;
                let genScore    = _fuzzyScore(query, (item.appGeneric || "").toLowerCase()) * 0.7;
                let commentScore = _fuzzyScore(query, (item.appComment || "").toLowerCase()) * 0.5;
                let binScore    = _fuzzyScore(query, (item.appBin || "").toLowerCase()) * 0.6;
                let best = Math.max(nameScore, genScore, commentScore, binScore);
                if (best > 0) {
                    // Blend: fuzzy score dominates, frecency adds a small boost (up to ~10%)
                    let fs = _frecencyScore(item.appName);
                    let boost = Math.min(fs * 0.5, best * 0.1);
                    scored.push({ idx: i, score: best + boost });
                }
            }
            scored.sort((a, b) => b.score - a.score);
            filteredIndices = scored.map(s => s.idx);
        }
        resultCount = filteredIndices.length;
        totalCount = appModel.count;
        if (selectedIndex >= filteredIndices.length)
            selectedIndex = Math.max(0, filteredIndices.length - 1);
    }

    function resetSearch() {
        searchText = "";
        selectedIndex = 0;
        updateFilter();
    }

    function launchSelected() {
        if (filteredIndices.length === 0) return;
        let idx = filteredIndices[selectedIndex];
        let item = appModel.get(idx);

        // Record frecency before launching
        recordLaunch(item.appName);

        if (item.appDbusId && item.appDbusId.length > 0) {
            dbusProc.appId = item.appDbusId;
            dbusProc.objPath = "/" + item.appDbusId.replace(/\./g, "/");
            dbusProc.running = true;
        } else {
            execProc.cmd = item.appExec;
            execProc.running = true;
        }
        launched();
    }

    ListModel { id: appModel }

    // Cache on startup — resolves binary to full nix store path
    // For DBusActivatable apps, stores the app ID for D-Bus activation
    Process {
        id: cacheProc
        command: [
            "bash", "-c",
            "IFS=':'; " +
            "paths=\"$XDG_DATA_DIRS:$HOME/.local/share:/run/current-system/sw/share:/usr/share\"; " +
            "for dir in $paths; do " +
            "  [ -d \"$dir/applications\" ] && echo \"$dir/applications\"; " +
            "done | sort -u | while IFS= read -r d; do " +
            "  find \"$d\" -maxdepth 2 -name '*.desktop' 2>/dev/null; " +
            "done | sort -u | while IFS= read -r f; do " +
            "  name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "  icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-); " +
            "  comment=$(grep -m1 '^Comment=' \"$f\" | cut -d= -f2-); " +
            "  generic=$(grep -m1 '^GenericName=' \"$f\" | cut -d= -f2-); " +
            "  exec_line=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[fFuUdDnNickvm]//g'); " +
            "  nodisplay=$(grep -m1 '^NoDisplay=' \"$f\" | cut -d= -f2-); " +
            "  type=$(grep -m1 '^Type=' \"$f\" | cut -d= -f2-); " +
            "  dbus=$(grep -m1 '^DBusActivatable=' \"$f\" | cut -d= -f2-); " +
            "  [ \"$nodisplay\" = 'true' ] && continue; " +
            "  [ \"$type\" != 'Application' ] && [ -n \"$type\" ] && continue; " +
            "  [ -z \"$name\" ] && continue; " +
            "  [ -z \"$exec_line\" ] && continue; " +
            "  bin=\"${exec_line%% *}\"; " +
            "  binname=$(basename \"$bin\"); " +
            "  args=\"${exec_line#\"$bin\"}\"; " +
            "  found=$(command -v \"$bin\" 2>/dev/null || echo \"$bin\"); " +
            "  if [ -L \"$found\" ]; then " +
            "    full=$(realpath \"$found\" 2>/dev/null || echo \"$found\"); " +
            "  else " +
            "    full=\"$found\"; " +
            "  fi; " +
            "  resolved=\"${full}${args}\"; " +
            "  appid=''; " +
            "  if [ \"$dbus\" = 'true' ]; then " +
            "    appid=$(basename \"$f\" .desktop); " +
            "  fi; " +
            "  printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$name\" \"$icon\" \"$resolved\" \"$appid\" \"$comment\" \"$generic\" \"$binname\"; " +
            "done | sort -t$'\\t' -k1,1f -u"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let parts = data.split("\t");
                if (parts.length < 3) return;
                appModel.append({
                    "appName":    parts[0] || "",
                    "appIcon":    parts[1] || "",
                    "appExec":    parts[2] || "",
                    "appDbusId":  parts[3] || "",
                    "appComment": parts[4] || "",
                    "appGeneric": parts[5] || "",
                    "appBin":     parts[6] || ""
                });
            }
        }
        onExited: { root.loadFrecency(); root.updateFilter(); }
    }

    // For DBusActivatable apps: gdbus Activate (same as rofi)
    Process {
        id: dbusProc
        property string appId: ""
        property string objPath: ""
        command: [
            "gdbus", "call", "--session",
            "--dest", appId,
            "--object-path", objPath,
            "--method", "org.freedesktop.Application.Activate",
            "[]"
        ]
    }

    // For regular apps: run exec line directly
    // SECURITY: Use positional parameter to prevent command injection
    Process {
        id: execProc
        property string cmd: ""
        command: ["sh", "-c", "$1 &>/dev/null &", "--", cmd]
    }

    Column {
        id: launchInner
        width: parent.width
        spacing: 0

        Components.EmptyState {
            visible: filteredIndices.length === 0
            icon: Root.Icons.search
            message: searchText.length > 0 ? "No matches" : "Loading…"
            preferredHeight: 90
        }

        Components.SmoothFlickable {
            id: appFlick
            visible: filteredIndices.length > 0
            width: parent.width
            height: Math.min(appCol.implicitHeight, root.maxContentHeight - 20)
            contentHeight: appCol.implicitHeight
            clip: true

            function ensureVisible(selIdx) {
                let y = selIdx * Root.Theme.launchItemHeight;
                if (y < contentY) contentY = y;
                else if (y + Root.Theme.launchItemHeight > contentY + height)
                    contentY = y + Root.Theme.launchItemHeight - height;
            }

            Column {
                id: appCol
                width: parent.width; spacing: 0

                Repeater {
                    model: root.filteredIndices.length

                    Components.StaggerReveal {
                        width: appCol.width
                        shown: true
                        playOnCompleted: false          // keystroke rebuilds appear instantly
                        replayToken: root._cascadeGen   // ...the cascade replays on open
                        staggerIndex: Math.min(index, 8) // cap so a long app list doesn't drag
                        stagger: 28
                        fadeDuration: 200
                        slideDuration: 240
                        slideFrom: 12

                        Rectangle {
                        id: appItem
                        width: appCol.width
                        height: Root.Theme.launchItemHeight
                        transformOrigin: Item.Center
                        scale: appMouse.pressed ? 0.97 : 1.0
                        Behavior on scale { NumberAnimation { duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic } }

                        property int sourceIndex: root.filteredIndices[index] ?? -1
                        property var entry: sourceIndex >= 0 ? appModel.get(sourceIndex) : null
                        property bool isSelected: index === root.selectedIndex

                        color: isSelected
                            ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.12)
                            : appMouse.containsMouse
                              ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06)
                              : "transparent"

                        RowLayout {
                            anchors {
                                left: parent.left; right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: Root.Theme.notifPadding; rightMargin: Root.Theme.notifPadding
                            }
                            spacing: Root.Theme.spacingM

                            Image {
                                id: appIconImg
                                source: {
                                    if (!appItem.entry) return "";
                                    let p = appItem.entry.appIcon;
                                    if (!p || p === "") return "";
                                    if (p.indexOf("/") !== -1) return "file://" + p;
                                    // Use Quickshell.iconPath for proper icon theme support
                                    return Quickshell.iconPath(p, true);
                                }
                                sourceSize.width: Root.Theme.launchIconSize; sourceSize.height: Root.Theme.launchIconSize
                                Layout.preferredWidth: Root.Theme.launchIconSize; Layout.preferredHeight: Root.Theme.launchIconSize
                                visible: status === Image.Ready; smooth: true
                            }

                            Rectangle {
                                visible: appIconImg.status !== Image.Ready
                                Layout.preferredWidth: Root.Theme.launchIconSize; Layout.preferredHeight: Root.Theme.launchIconSize
                                radius: 8; color: Root.Theme.textDimmed; opacity: 0.2
                                Text {
                                    anchors.centerIn: parent
                                    text: appItem.entry ? appItem.entry.appName.charAt(0).toUpperCase() : ""
                                    color: Root.Theme.textPrimary
                                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize2XL; bold: true }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: appItem.entry ? appItem.entry.appName : ""
                                    color: appItem.isSelected ? Root.Theme.textAccent : Root.Theme.textPrimary
                                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.notifTitleSize; bold: appItem.isSelected }
                                    width: parent.width; elide: Text.ElideRight
                                }

                                Text {
                                    property string sub: {
                                        if (!appItem.entry) return "";
                                        return appItem.entry.appGeneric || appItem.entry.appComment || "";
                                    }
                                    visible: sub.length > 0
                                    text: sub
                                    color: Root.Theme.textDimmed
                                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                                    width: parent.width; elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: appMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.selectedIndex = index; root.launchSelected(); }
                            onPositionChanged: root.selectedIndex = index
                        }
                    }
                    }
                }
            }
        }

        // ── Result count footer ──
        Text {
            visible: filteredIndices.length > 0
            text: searchText.length > 0
                ? filteredIndices.length + " of " + appModel.count + " apps"
                : appModel.count + " apps"
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
            width: parent.width; height: 20
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: 0.6
        }
    }
}
