import QtQuick
import Quickshell
import Quickshell.Io
import ".." as Root

// Local wallpaper picker. `/` filters by filename; Enter applies via awww.
// Thumbs are small JPEGs in ~/.cache/quickshell/wallpaper-thumbs so the
// grid never decodes full-size wallpapers.
Item {
    id: root
    implicitHeight: inner.implicitHeight + 16

    property string filterText: ""
    property int selectedIndex: 0
    readonly property int resultCount: filteredIndices.length
    readonly property int columns: 3
    property var filteredIndices: []
    signal applied()

    readonly property string thumbDir: (Quickshell.env("HOME") || "/home/justin") + "/.cache/quickshell/wallpaper-thumbs"

    function activate() {
        root.filterText = "";
        root.selectedIndex = 0;
        if (wpModel.count === 0)
            scanProc.running = true;
        else
            updateFilter();
    }

    function reset() {
        root.filterText = "";
        root.selectedIndex = 0;
    }

    function applySelected() {
        if (filteredIndices.length === 0)
            return;
        const idx = filteredIndices[root.selectedIndex];
        const item = wpModel.get(idx);
        if (!item)
            return;
        setProc.wallpaper = item.wpPath;
        setProc.running = true;
        root.applied();
    }

    function updateFilter() {
        const query = root.filterText.toLowerCase();
        const matches = [];
        for (let i = 0; i < wpModel.count; i++) {
            const name = (wpModel.get(i).wpName || "").toLowerCase();
            if (query.length === 0 || name.indexOf(query) >= 0)
                matches.push(i);
        }
        filteredIndices = matches;
        if (root.selectedIndex >= filteredIndices.length)
            root.selectedIndex = Math.max(0, filteredIndices.length - 1);
    }

    onFilterTextChanged: updateFilter()
    onSelectedIndexChanged: {
        if (grid.visible)
            grid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
    }

    ListModel { id: wpModel }

    Process {
        id: scanProc
        command: [
            "bash", "-c",
            'cache="$1"; wpdir="$2"; ' +
            'mkdir -p "$cache"; ' +
            '[ -d "$wpdir" ] || exit 0; ' +
            'find "$wpdir" -maxdepth 1 -type f \\( ' +
            "-iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' " +
            "-o -iname '*.webp' -o -iname '*.gif' " +
            '\\) 2>/dev/null | sort | while IFS= read -r f; do ' +
            'hash=$(echo -n "$f" | sha256sum | cut -c1-16); ' +
            'thumb="$cache/${hash}.jpg"; ' +
            'if [ ! -f "$thumb" ] || [ "$f" -nt "$thumb" ]; then ' +
            'magick "${f}[0]" -thumbnail 240x144^ -gravity center -extent 240x144 -quality 80 "$thumb" 2>/dev/null || ' +
            'convert "${f}[0]" -thumbnail 240x144^ -gravity center -extent 240x144 -quality 80 "$thumb" 2>/dev/null || ' +
            'thumb="$f"; ' +
            'fi; ' +
            'printf "%s|%s\\n" "$f" "$thumb"; ' +
            'done',
            "--", root.thumbDir, Root.Theme.wallpaperDir
        ]
        stdout: SplitParser {
            onRead: line => {
                const text = line.trim();
                if (text.length === 0)
                    return;
                const sep = text.indexOf("|");
                const path = sep > 0 ? text.substring(0, sep) : text;
                const thumb = sep > 0 ? text.substring(sep + 1) : path;
                const parts = path.split("/");
                wpModel.append({
                    "wpPath": path,
                    "wpThumb": thumb,
                    "wpName": parts[parts.length - 1]
                });
            }
        }
        onExited: root.updateFilter()
    }

    Process {
        id: setProc
        property string wallpaper: ""
        command: [
            "sh", "-c",
            'exec awww img "$1" --transition-type wipe --transition-duration 1',
            "--", wallpaper
        ]
    }

    Column {
        id: inner
        width: parent.width
        topPadding: 4
        bottomPadding: 8
        spacing: 8

        Text {
            visible: filteredIndices.length === 0
            width: parent.width
            height: 72
            text: wpModel.count === 0 ? "No wallpapers in assets/wallpapers" : "No matches"
            color: Root.Theme.textDim
            font { family: Root.Theme.fontUi; pixelSize: 14 }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        GridView {
            id: grid
            visible: filteredIndices.length > 0
            width: parent.width - Root.Theme.cardPad * 2
            x: Root.Theme.cardPad
            height: Math.min(Math.ceil(filteredIndices.length / 3) * cellHeight, 336)
            cellWidth: width / 3
            cellHeight: 108
            clip: true
            model: filteredIndices
            currentIndex: root.selectedIndex
            cacheBuffer: cellHeight * 2

            delegate: Item {
                required property int modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight

                readonly property var entry: wpModel.get(modelData)
                readonly property bool isSelected: index === root.selectedIndex

                Column {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Item {
                        width: parent.width
                        height: 72

                        Image {
                            anchors.fill: parent
                            anchors.margins: isSelected ? 3 : 0
                            source: entry ? "file://" + (entry.wpThumb || entry.wpPath) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 240
                            sourceSize.height: 144
                            opacity: isSelected ? 1 : 0.72
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            radius: 4
                            border.width: isSelected ? 3 : 1
                            border.color: isSelected ? Root.Theme.accent : Root.Theme.border
                        }
                    }

                    Text {
                        width: parent.width
                        text: entry ? entry.wpName : ""
                        color: isSelected ? Root.Theme.accent : Root.Theme.textDim
                        font {
                            family: Root.Theme.fontUi
                            pixelSize: 11
                            weight: isSelected ? Font.DemiBold : Font.Normal
                        }
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = index
                    onClicked: {
                        root.selectedIndex = index;
                        root.applySelected();
                    }
                }
            }
        }
    }
}
