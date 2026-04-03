import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.." as Root
import "../../components" as Components

// Clipboard history view for the Spotlight popup.
Item {
    id: root
    implicitWidth: parent ? parent.width : 420
    implicitHeight: clipInner.implicitHeight

    // Theme is now a singleton - access via Root.Theme.propertyName

    signal itemSelected()

    function refresh() {
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
    // SECURITY: Use positional parameter to prevent command injection
    Process { id: copyProc; property string clipId: ""; command: ["sh", "-c", "cliphist decode \"$1\" | wl-copy", "--", clipId] }
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
                text: Root.Theme.iconTrash
                color: clipModel.count > 0 ? Root.Theme.textDimmed : "transparent"
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
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
            visible: clipModel.count === 0
            text: "No clipboard history"
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.notifBodySize }
            width: parent.width; height: 60
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }

        Components.SmoothFlickable {
            visible: clipModel.count > 0
            width: parent.width
            height: Math.min(clipCol.implicitHeight, Root.Theme.clipMaxHeight - 80)
            contentHeight: clipCol.implicitHeight
            clip: true

            Column {
                id: clipCol; width: parent.width; spacing: 0

                Repeater {
                    model: clipModel
                    Rectangle {
                        width: clipCol.width
                        height: Math.max(clipRow.implicitHeight + 12, 36)
                        color: clipMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06) : "transparent"

                        RowLayout {
                            id: clipRow
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: Root.Theme.notifPadding; rightMargin: Root.Theme.notifPadding }
                            spacing: 10

                            Image {
                                visible: model.isImage && model.imagePath !== ""
                                source: model.imagePath !== "" ? "file://" + model.imagePath : ""
                                sourceSize.width: Root.Theme.clipThumbSize; sourceSize.height: Root.Theme.clipThumbSize
                                Layout.preferredWidth: Root.Theme.clipThumbSize; Layout.preferredHeight: Root.Theme.clipThumbSize
                                fillMode: Image.PreserveAspectCrop; smooth: true
                            }
                            Rectangle {
                                visible: model.isImage && model.imagePath === ""
                                Layout.preferredWidth: Root.Theme.clipThumbSize; Layout.preferredHeight: Root.Theme.clipThumbSize
                                color: Root.Theme.textDimmed; opacity: 0.2; radius: 4
                                Text { anchors.centerIn: parent; text: "IMG"; color: Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: 10 } }
                            }
                            Text {
                                visible: !model.isImage
                                text: { let t = (model.clipText || "").replace(/\s+/g, " "); return t.length > 100 ? t.substring(0, 100) + "…" : t; }
                                color: Root.Theme.textPrimary
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.notifBodySize }
                                Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
                            }
                            Text {
                                visible: model.isImage; text: model.mime || "image"
                                color: Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: 11 }
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: clipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { copyProc.clipId = model.clipId; copyProc.running = true; root.itemSelected(); }
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
    }
}
