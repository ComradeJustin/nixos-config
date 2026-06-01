import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.." as Root
import "../../components" as Components

// Clipboard history view for the Spotlight popup.
SpotlightProvider {
    id: root
    implicitWidth: parent ? parent.width : 420
    implicitHeight: clipInner.implicitHeight

    // ── Provider identity ──
    providerKey: "clipboard"
    providerLabel: "Clipboard"
    providerIcon: "󰅍"
    hasSearch: true
    hasGrid: false
    preferredWidth: Root.Theme.clipWidth
    preferredMaxHeight: Root.Theme.launchMaxHeight

    // ── Provider interface ──
    function activate() { refresh(); }
    function deactivate() {}
    function handleSearchText(text) {
        searchText = text;
        selectedIndex = 0;
        updateFilter();
    }
    function moveUp() { if (selectedIndex > 0) selectedIndex--; clipFlick.ensureVisible(selectedIndex); }
    function moveDown() { if (selectedIndex < filteredIndices.length - 1) selectedIndex++; clipFlick.ensureVisible(selectedIndex); }
    function accept() { selectCurrent(); }

    signal itemSelected()

    property string searchText: ""
    property int selectedIndex: 0
    property var filteredIndices: []

    function updateFilter() {
        let indices = [];
        let query = searchText.toLowerCase();
        for (let i = 0; i < clipModel.count; i++) {
            let item = clipModel.get(i);
            if (query.length === 0) { indices.push(i); continue; }
            // Text items: match on content
            if (!item.isImage && item.clipText.toLowerCase().indexOf(query) !== -1)
                indices.push(i);
            // Image items: match on mime type (e.g. "png", "jpeg")
            else if (item.isImage && item.mime.toLowerCase().indexOf(query) !== -1)
                indices.push(i);
        }
        filteredIndices = indices;
        resultCount = indices.length;
        totalCount = clipModel.count;
        if (selectedIndex >= indices.length)
            selectedIndex = Math.max(0, indices.length - 1);
    }

    function selectCurrent() {
        if (filteredIndices.length === 0) return;
        let idx = filteredIndices[selectedIndex];
        let item = clipModel.get(idx);
        copyProc.clipId = item.clipId;
        copyProc.running = true;
        root.itemSelected();
    }

    function refresh() {
        searchText = "";
        selectedIndex = 0;
        filteredIndices = [];
        refreshProc.running = true;
    }

    ListModel { id: clipModel }

    Process {
        id: refreshProc
        command: ["cliphist", "list"]
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (line.length === 0) return;
                let tabIdx = line.indexOf("\t");
                if (tabIdx === -1) return;
                let id = line.substring(0, tabIdx).trim();
                let text = line.substring(tabIdx + 1).trim();
                let isImage = text.startsWith("[[ binary data");
                let mime = "";
                if (isImage) { let m = text.match(/binary data \d+ (.+?) \]\]/); if (m) mime = m[1]; }
                if (clipModel.count < Root.Theme.clipMaxItems) {
                    clipModel.append({ "clipId": id, "clipText": isImage ? "" : text, "isImage": isImage, "imagePath": "", "mime": mime });
                    if (isImage) { thumbQueue.push({ id: id, index: clipModel.count - 1 }); processThumbQueue(); }
                }
            }
        }
        onStarted: { clipModel.clear(); thumbQueue = []; }
        onExited: root.updateFilter()
    }

    property var thumbQueue: []
    property bool thumbBusy: false
    function processThumbQueue() {
        if (thumbBusy || thumbQueue.length === 0) return;
        thumbBusy = true;
        let item = thumbQueue.shift();
        thumbProc.targetIndex = item.index;
        // SECURITY: Use positional parameter to prevent command injection from clipboard IDs
        thumbProc.command = ["sh", "-c", "f=/tmp/qs-clip-thumb-\"$1\".png; cliphist decode \"$1\" > \"$f\" 2>/dev/null && echo \"$f\" || echo ''", "--", item.id];
        thumbProc.running = true;
    }
    Process {
        id: thumbProc; property int targetIndex: -1
        stdout: SplitParser {
            onRead: data => { let p = data.trim(); if (p.length > 0 && thumbProc.targetIndex >= 0 && thumbProc.targetIndex < clipModel.count) clipModel.setProperty(thumbProc.targetIndex, "imagePath", p); }
        }
        onExited: { root.thumbBusy = false; root.processThumbQueue(); }
    }
    // Delete a single clipboard entry
    function deleteSelected() {
        if (filteredIndices.length === 0) return;
        let idx = filteredIndices[selectedIndex];
        let item = clipModel.get(idx);
        deleteProc.clipId = item.clipId;
        deleteProc.running = true;
        clipModel.remove(idx);
        updateFilter();
        if (selectedIndex >= filteredIndices.length)
            selectedIndex = Math.max(0, filteredIndices.length - 1);
    }

    // SECURITY: Use positional parameter to prevent command injection
    Process { id: copyProc; property string clipId: ""; command: ["sh", "-c", "cliphist decode \"$1\" | wl-copy", "--", clipId] }
    Process { id: deleteProc; property string clipId: ""; command: ["sh", "-c", "cliphist delete \"$1\"", "--", clipId] }
    Process { id: clearProc; command: ["cliphist", "wipe"] }

    Column {
        id: clipInner
        width: parent.width
        spacing: 0

        // ── Header with clear ──
        RowLayout {
            width: parent.width; height: 32
            Item { Layout.fillWidth: true }
            Text {
                text: Root.Icons.trash
                color: clipModel.count > 0 ? Root.Theme.textDimmed : "transparent"
                font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.iconSize }
                Layout.rightMargin: Root.Theme.notifPadding
                verticalAlignment: Text.AlignVCenter
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { clearProc.running = true; clipModel.clear(); } }
            }
        }

        Rectangle {
            width: parent.width - Root.Theme.notifPadding * 2; height: 1
            color: Root.Theme.textDimmed; opacity: 0.3
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            visible: filteredIndices.length === 0
            text: {
                if (clipModel.count === 0) return "No clipboard history";
                if (searchText.length > 0) return "No matches";
                return "No clipboard history";
            }
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.notifBodySize }
            width: parent.width; height: 60
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }

        Components.SmoothFlickable {
            id: clipFlick
            visible: filteredIndices.length > 0
            width: parent.width
            height: Math.min(clipCol.implicitHeight, root.maxContentHeight - 53)  // 32px header + 1px divider + 20px footer
            contentHeight: clipCol.implicitHeight
            clip: true

            function ensureVisible(selIdx) {
                // Estimate row height (same as delegate Math.max)
                let itemH = 36;
                let y = selIdx * itemH;
                if (y < contentY) contentY = y;
                else if (y + itemH > contentY + height)
                    contentY = y + itemH - height;
            }

            Column {
                id: clipCol; width: parent.width; spacing: 0

                Repeater {
                    model: root.filteredIndices.length

                    Rectangle {
                        id: clipItem
                        width: clipCol.width
                        height: Math.max(clipRow.implicitHeight + 12, 36)

                        property int sourceIndex: root.filteredIndices[index] ?? -1
                        property var entry: sourceIndex >= 0 ? clipModel.get(sourceIndex) : null
                        property bool isSelected: index === root.selectedIndex

                        color: isSelected
                            ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.12)
                            : clipMouse.containsMouse
                              ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06)
                              : "transparent"

                        // Detect content type for icon hint
                        property string contentType: {
                            if (!entry) return "text";
                            if (entry.isImage) return "image";
                            let t = entry.clipText || "";
                            if (/^https?:\/\//.test(t)) return "url";
                            if (/^\/[\w\/\-\.]+/.test(t)) return "path";
                            if (/[{}\[\]<>]|function |=>|import |def |class /.test(t)) return "code";
                            if (/^\d+(\.\d+)?$/.test(t.trim())) return "number";
                            if (/^#[0-9a-fA-F]{3,8}$/.test(t.trim()) || /^rgba?\(/.test(t.trim())) return "color";
                            return "text";
                        }

                        // Content type icon glyph
                        property string typeIcon: {
                            switch (contentType) {
                                case "url":    return "󰌷";  // nf-md-link
                                case "path":   return "󰈔";  // nf-md-file
                                case "code":   return "󰅩";  // nf-md-code_braces
                                case "number": return "󰎠";  // nf-md-numeric
                                case "color":  return "󰏘";  // nf-md-palette
                                case "image":  return "󰋩";  // nf-md-image
                                default:       return "󰦪";  // nf-md-text_short
                            }
                        }

                        RowLayout {
                            id: clipRow
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: Root.Theme.notifPadding; rightMargin: Root.Theme.notifPadding }
                            spacing: 10

                            // Content type indicator
                            Text {
                                visible: clipItem.entry && !clipItem.entry.isImage
                                text: clipItem.typeIcon
                                color: clipItem.isSelected ? Root.Theme.textAccent : Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXL }
                                Layout.preferredWidth: 18
                                horizontalAlignment: Text.AlignHCenter
                                opacity: 0.7
                            }

                            Image {
                                visible: clipItem.entry && clipItem.entry.isImage && clipItem.entry.imagePath !== ""
                                source: (clipItem.entry && clipItem.entry.imagePath !== "") ? "file://" + clipItem.entry.imagePath : ""
                                sourceSize.width: Root.Theme.clipThumbSize; sourceSize.height: Root.Theme.clipThumbSize
                                Layout.preferredWidth: Root.Theme.clipThumbSize; Layout.preferredHeight: Root.Theme.clipThumbSize
                                fillMode: Image.PreserveAspectCrop; smooth: true
                            }
                            Rectangle {
                                visible: clipItem.entry && clipItem.entry.isImage && clipItem.entry.imagePath === ""
                                Layout.preferredWidth: Root.Theme.clipThumbSize; Layout.preferredHeight: Root.Theme.clipThumbSize
                                color: Root.Theme.textDimmed; opacity: 0.2; radius: 4
                                Text { anchors.centerIn: parent; text: "IMG"; color: Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS } }
                            }
                            Text {
                                visible: clipItem.entry && !clipItem.entry.isImage
                                text: { if (!clipItem.entry) return ""; let t = (clipItem.entry.clipText || "").replace(/\s+/g, " "); return t.length > 100 ? t.substring(0, 100) + "…" : t; }
                                color: clipItem.isSelected ? Root.Theme.textAccent : Root.Theme.textPrimary
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.notifBodySize }
                                Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
                            }
                            Text {
                                visible: clipItem.entry && clipItem.entry.isImage; text: (clipItem.entry ? clipItem.entry.mime : "") || "image"
                                color: Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: clipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.selectedIndex = index; root.selectCurrent(); }
                            onPositionChanged: root.selectedIndex = index
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width - Root.Theme.notifPadding * 2; height: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Root.Theme.textDimmed; opacity: 0.1
                        }
                    }
                }
            }
        }

        // ── Result count footer ──
        Text {
            visible: filteredIndices.length > 0 || clipModel.count > 0
            text: searchText.length > 0
                ? filteredIndices.length + " of " + clipModel.count + " items"
                : clipModel.count + " items"
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
            width: parent.width; height: 20
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: 0.6
        }
    }
}
