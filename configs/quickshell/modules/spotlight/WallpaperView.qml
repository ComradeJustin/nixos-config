import QtQuick
import Quickshell.Io
import "../.." as Root

// Wallpaper selector view for the Spotlight popup.
// Scans directory once at startup, applies wallpapers via awww.
Item {
    id: root
    implicitWidth: parent ? parent.width : 560
    implicitHeight: wpInner.implicitHeight

    Root.Theme { id: theme }

    signal wallpaperSet()

    property string wallpaperDir: theme.wpDirectory
    property string currentWallpaper: ""
    property string searchText: ""
    property int selectedIndex: 0
    property bool scanned: false

    property var filteredIndices: []

    // Called when the view opens
    function refresh() {
        // Only scan once — wallpapers don't change at runtime
        if (!scanned)
            scanProc.running = true;
        else
            updateFilter();
        currentProc.running = true;
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

    property int columns: Math.max(1, Math.floor((root.width - theme.notifPadding * 2 + theme.wpSpacing) / (theme.wpThumbWidth + theme.wpSpacing)))

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
        let itemH = theme.wpThumbHeight + 28;
        let row = Math.floor(selectedIndex / columns);
        let y = row * (itemH + theme.wpSpacing);
        if (y < wpFlick.contentY)
            wpFlick.contentY = y;
        else if (y + itemH > wpFlick.contentY + wpFlick.height)
            wpFlick.contentY = y + itemH - wpFlick.height;
    }

    ListModel { id: wpModel }

    // Scan wallpaper directory once
    Process {
        id: scanProc
        command: [
            "bash", "-c",
            "dir=\"" + root.wallpaperDir + "\"; " +
            "dir=\"${dir/#\\~/$HOME}\"; " +
            "find \"$dir\" -maxdepth 2 -type f \\( " +
            "  -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' " +
            "  -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' " +
            "\\) 2>/dev/null | sort"
        ]

        stdout: SplitParser {
            onRead: data => {
                let path = data.trim();
                if (path.length === 0) return;
                let name = path.substring(path.lastIndexOf("/") + 1);
                let dot = name.lastIndexOf(".");
                let label = dot > 0 ? name.substring(0, dot) : name;
                wpModel.append({ "wpPath": path, "wpName": name, "wpLabel": label });
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
    Process {
        id: setProc
        property string wallpaper: ""
        command: [
            "awww", "img", wallpaper,
            "--transition-type", "wipe",
            "--transition-duration", "1"
        ]
        onExited: { root.currentWallpaper = wallpaper; }
    }

    Column {
        id: wpInner
        width: parent.width
        spacing: 0

        Text {
            visible: filteredIndices.length === 0
            text: !root.scanned ? "Scanning…" : "No matches"
            color: theme.textDimmed
            font { family: theme.fontFamily; pixelSize: theme.notifBodySize }
            width: parent.width; height: 60
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Flickable {
            id: wpFlick
            visible: filteredIndices.length > 0
            width: parent.width
            height: Math.min(gridContent.height + theme.wpSpacing * 2, theme.wpMaxHeight - 60)
            contentHeight: gridContent.height + theme.wpSpacing * 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Grid {
                id: gridContent
                x: theme.notifPadding
                y: theme.wpSpacing
                columns: root.columns
                spacing: theme.wpSpacing
                width: parent.width - theme.notifPadding * 2

                Repeater {
                    model: root.filteredIndices.length

                    Rectangle {
                        id: wpCard
                        width: theme.wpThumbWidth
                        height: theme.wpThumbHeight + 24
                        radius: 8

                        property int sourceIndex: root.filteredIndices[index] ?? -1
                        property var entry: sourceIndex >= 0 ? wpModel.get(sourceIndex) : null
                        property bool isCurrent: entry ? entry.wpPath === root.currentWallpaper : false
                        property bool isSelected: index === root.selectedIndex

                        color: isSelected
                            ? Qt.rgba(theme.textAccent.r, theme.textAccent.g, theme.textAccent.b, 0.12)
                            : wpMouse.containsMouse
                              ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.06)
                              : "transparent"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 2

                            Rectangle {
                                width: parent.width
                                height: theme.wpThumbHeight
                                radius: 6
                                color: Qt.rgba(theme.textDimmed.r, theme.textDimmed.g, theme.textDimmed.b, 0.15)
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: wpCard.entry ? "file://" + wpCard.entry.wpPath : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                    sourceSize.width: theme.wpThumbWidth
                                    sourceSize.height: theme.wpThumbHeight
                                    cache: true
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"; radius: 6
                                    border.width: wpCard.isCurrent ? 2 : 0
                                    border.color: theme.textAccent
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"; radius: 6
                                    border.width: wpCard.isSelected ? 2 : 0
                                    border.color: theme.textPrimary
                                    opacity: 0.5
                                    visible: wpCard.isSelected && !wpCard.isCurrent
                                }
                            }

                            Text {
                                width: parent.width
                                text: wpCard.entry ? wpCard.entry.wpLabel : ""
                                color: wpCard.isCurrent ? theme.textAccent
                                     : wpCard.isSelected ? theme.textPrimary
                                     : theme.textDimmed
                                font {
                                    family: theme.fontFamily; pixelSize: 10
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
