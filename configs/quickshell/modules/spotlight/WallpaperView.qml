import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../.." as Root
import "../../components" as Components

// Wallpaper selector view for the Spotlight popup.
// Scans directory once at startup, applies wallpapers via awww.
// Thumbnails are cached to ~/.cache/quickshell/wallpaper-thumbs/
Item {
    id: root
    implicitWidth: parent ? parent.width : 560
    implicitHeight: wpInner.implicitHeight

    // Theme is now a singleton - access via Root.Theme.propertyName

    signal wallpaperSet()

    property string wallpaperDir: Root.Theme.wpDirectory
    property string currentWallpaper: ""
    property string searchText: ""
    property int selectedIndex: 0
    property bool scanned: false
    property string cacheDir: (Quickshell.env("HOME") || "/home/justin") + "/.cache/quickshell/wallpaper-thumbs"

    property var filteredIndices: []

    // Called when the view opens
    function refresh() {
        if (!scanned)
            scanProc.running = true;
        else
            updateFilter();
        currentProc.running = true;
    }

    // Force a rescan (called by filesystem watcher)
    function forceRescan() {
        scanned = false;
        scanProc.running = true;
    }

    function updateFilter() {
        let indices = [];
        let query = searchText.toLowerCase();
        for (let i = 0; i < wpModel.count; i++) {
            let label = wpModel.get(i).wpLabel.toLowerCase();
            if (query.length === 0 || label.indexOf(query) !== -1)
                indices.push(i);
        }
        filteredIndices = indices;
        if (selectedIndex >= indices.length)
            selectedIndex = Math.max(0, indices.length - 1);
    }

    function resetSearch() {
        searchText = "";
        selectedIndex = 0;
        updateFilter();
    }

    property int columns: Math.max(1, Math.floor((root.width - Root.Theme.notifPadding * 2 + Root.Theme.wpSpacing) / (Root.Theme.wpThumbWidth + Root.Theme.wpSpacing)))

    function moveUp() {
        if (selectedIndex >= columns) selectedIndex -= columns;
        ensureVisible();
    }

    function moveDown() {
        if (selectedIndex + columns < filteredIndices.length)
            selectedIndex += columns;
        else
            selectedIndex = filteredIndices.length - 1;
        ensureVisible();
    }

    function moveLeft() {
        if (selectedIndex > 0) selectedIndex--;
        ensureVisible();
    }

    function moveRight() {
        if (selectedIndex < filteredIndices.length - 1) selectedIndex++;
        ensureVisible();
    }

    function applySelected() {
        if (filteredIndices.length === 0) return;
        let idx = filteredIndices[selectedIndex];
        let item = wpModel.get(idx);
        setProc.wallpaper = item.wpPath;
        setProc.running = true;
        wallpaperSet();
    }

    function ensureVisible() {
        let itemH = Root.Theme.wpThumbHeight + 24;  // Must match wpCard height
        let row = Math.floor(selectedIndex / columns);
        let y = row * (itemH + Root.Theme.wpSpacing);
        if (y < wpFlick.contentY)
            wpFlick.contentY = y;
        else if (y + itemH > wpFlick.contentY + wpFlick.height)
            wpFlick.contentY = y + itemH - wpFlick.height;
    }

    ListModel { id: wpModel }

    // Scan wallpaper directory and generate thumbnails
    // SECURITY: Uses positional parameters to prevent command injection
    Process {
        id: scanProc
        property string expandedWpDir: root.wallpaperDir.replace(/^~/, Quickshell.env("HOME") || "/home/justin")
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
            "--", root.cacheDir, expandedWpDir
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
            root.scanned = true;
            root.updateFilter();
        }
    }

    // Get current wallpaper
    Process {
        id: currentProc
        command: ["bash", "-c", "awww query 2>/dev/null | head -1 | sed 's/.*image: //'"]
        stdout: SplitParser {
            onRead: data => { root.currentWallpaper = data.trim(); }
        }
    }

    // Set wallpaper
    // SECURITY: Uses positional parameter to safely pass file path
    Process {
        id: setProc
        property string wallpaper: ""
        command: [
            "sh", "-c",
            'exec awww img "$1" --transition-type wipe --transition-duration 1',
            "--", wallpaper
        ]
        onExited: { root.currentWallpaper = wallpaper; }
    }

    // Watch wallpaper directory for changes (live detection)
    // Requires inotify-tools package; fails gracefully if unavailable
    // SECURITY: Uses positional parameter to safely pass directory path
    Process {
        id: watchProc
        property string expandedDir: root.wallpaperDir.replace(/^~/, Quickshell.env("HOME") || "/home/justin")
        command: [
            "bash", "-c",
            'command -v inotifywait >/dev/null 2>&1 || exit 0; ' +
            'exec inotifywait -m -q -e create -e delete -e moved_to -e moved_from --format "%e" "$1"',
            "--", expandedDir
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                if (!rescanTimer.running) {
                    rescanTimer.start();
                }
            }
        }
    }

    // Debounce timer to avoid excessive rescans
    Timer {
        id: rescanTimer
        interval: 500
        onTriggered: root.forceRescan()
    }

    Column {
        id: wpInner
        width: parent.width
        spacing: 0

        Text {
            visible: filteredIndices.length === 0
            text: !root.scanned ? "Scanning…" : "No matches"
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.notifBodySize }
            width: parent.width; height: 60
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Components.SmoothFlickable {
            id: wpFlick
            visible: filteredIndices.length > 0
            width: parent.width
            height: Math.min(gridContent.height + Root.Theme.wpSpacing * 2, Root.Theme.wpMaxHeight - 48)  // 46px search bar + 1px divider + 1px margin
            contentHeight: gridContent.height + Root.Theme.wpSpacing * 2
            clip: true

            Grid {
                id: gridContent
                y: Root.Theme.wpSpacing
                columns: root.columns
                spacing: Root.Theme.wpSpacing
                // Center the grid horizontally
                property int gridWidth: columns * Root.Theme.wpThumbWidth + (columns - 1) * Root.Theme.wpSpacing
                anchors.horizontalCenter: parent.horizontalCenter
                width: gridWidth

                Repeater {
                    model: root.filteredIndices.length

                    Rectangle {
                        id: wpCard
                        width: Root.Theme.wpThumbWidth
                        height: Root.Theme.wpThumbHeight + 24
                        radius: 8

                        property int sourceIndex: root.filteredIndices[index] ?? -1
                        property var entry: sourceIndex >= 0 ? wpModel.get(sourceIndex) : null
                        property bool isCurrent: entry ? entry.wpPath === root.currentWallpaper : false
                        property bool isSelected: index === root.selectedIndex

                        color: isSelected
                            ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.12)
                            : wpMouse.containsMouse
                              ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06)
                              : "transparent"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 2

                            Item {
                                id: thumbContainer
                                width: parent.width
                                height: Root.Theme.wpThumbHeight

                                // Background placeholder
                                Rectangle {
                                    id: thumbBg
                                    anchors.fill: parent
                                    radius: 6
                                    color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.15)
                                }

                                // Thumbnail image with rounded corners via OpacityMask
                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    source: wpCard.entry ? "file://" + (wpCard.entry.wpThumb || wpCard.entry.wpPath) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                    sourceSize.width: Root.Theme.wpThumbWidth * 2
                                    sourceSize.height: Root.Theme.wpThumbHeight * 2
                                    cache: true
                                    visible: false  // Hidden, rendered via OpacityMask
                                }

                                Rectangle {
                                    id: thumbMask
                                    anchors.fill: parent
                                    radius: 6
                                    visible: false  // Hidden, used as mask
                                }

                                OpacityMask {
                                    anchors.fill: parent
                                    source: thumbImg
                                    maskSource: thumbMask
                                }

                                // Border overlays
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"; radius: 6
                                    border.width: wpCard.isCurrent ? 2 : 0
                                    border.color: Root.Theme.textAccent
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"; radius: 6
                                    border.width: wpCard.isSelected ? 2 : 0
                                    border.color: Root.Theme.textPrimary
                                    opacity: 0.5
                                    visible: wpCard.isSelected && !wpCard.isCurrent
                                }
                            }

                            Text {
                                width: parent.width
                                text: wpCard.entry ? wpCard.entry.wpLabel : ""
                                color: wpCard.isCurrent ? Root.Theme.textAccent
                                     : wpCard.isSelected ? Root.Theme.textPrimary
                                     : Root.Theme.textDimmed
                                font {
                                    family: Root.Theme.fontFamily; pixelSize: 10
                                    bold: wpCard.isCurrent || wpCard.isSelected
                                }
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            id: wpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.selectedIndex = index; root.applySelected(); }
                            onPositionChanged: root.selectedIndex = index
                        }
                    }
                }
            }
        }
    }
}
