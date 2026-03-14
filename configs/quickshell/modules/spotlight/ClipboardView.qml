import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.." as Root

// Clipboard history view for the Spotlight popup.
Item {
    id: root
    implicitWidth: parent ? parent.width : 420
    implicitHeight: clipInner.implicitHeight

    Root.Theme { id: theme }

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
                if (clipModel.count < theme.clipMaxItems) {
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
        thumbProc.command = ["bash", "-c", "f=/tmp/qs-clip-thumb-" + item.id + ".png; cliphist decode " + item.id + " > \"$f\" 2>/dev/null && echo \"$f\" || echo ''"];
        thumbProc.running = true;
    }
    Process {
        id: thumbProc; property int targetIndex: -1
        stdout: SplitParser {
            onRead: data => { let p = data.trim(); if (p.length > 0 && thumbProc.targetIndex >= 0 && thumbProc.targetIndex < clipModel.count) clipModel.setProperty(thumbProc.targetIndex, "imagePath", p); }
        }
        onExited: { root.thumbBusy = false; root.processThumbQueue(); }
    }
    Process { id: copyProc; property string clipId: ""; command: ["bash", "-c", "cliphist decode " + clipId + " | wl-copy"] }
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
                text: theme.iconTrash
                color: clipModel.count > 0 ? theme.textDimmed : "transparent"
                font { family: theme.fontFamily; pixelSize: theme.iconSize }
                Layout.rightMargin: theme.notifPadding
                verticalAlignment: Text.AlignVCenter
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { clearProc.running = true; clipModel.clear(); } }
            }
        }

        Rectangle {
            width: parent.width - theme.notifPadding * 2; height: 1
            color: theme.textDimmed; opacity: 0.3
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            visible: clipModel.count === 0
            text: "No clipboard history"
            color: theme.textDimmed
            font { family: theme.fontFamily; pixelSize: theme.notifBodySize }
            width: parent.width; height: 60
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }

        Flickable {
            visible: clipModel.count > 0
            width: parent.width
            height: Math.min(clipCol.implicitHeight, theme.clipMaxHeight - 80)
            contentHeight: clipCol.implicitHeight
            clip: true; boundsBehavior: Flickable.StopAtBounds

            Column {
                id: clipCol; width: parent.width; spacing: 0

                Repeater {
                    model: clipModel
                    Rectangle {
                        width: clipCol.width
                        height: Math.max(clipRow.implicitHeight + 12, 36)
                        color: clipMouse.containsMouse ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.06) : "transparent"

                        RowLayout {
                            id: clipRow
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: theme.notifPadding; rightMargin: theme.notifPadding }
                            spacing: 10

                            Image {
                                visible: model.isImage && model.imagePath !== ""
                                source: model.imagePath !== "" ? "file://" + model.imagePath : ""
                                sourceSize.width: theme.clipThumbSize; sourceSize.height: theme.clipThumbSize
                                Layout.preferredWidth: theme.clipThumbSize; Layout.preferredHeight: theme.clipThumbSize
                                fillMode: Image.PreserveAspectCrop; smooth: true
                            }
                            Rectangle {
                                visible: model.isImage && model.imagePath === ""
                                Layout.preferredWidth: theme.clipThumbSize; Layout.preferredHeight: theme.clipThumbSize
                                color: theme.textDimmed; opacity: 0.2; radius: 4
                                Text { anchors.centerIn: parent; text: "IMG"; color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 10 } }
                            }
                            Text {
                                visible: !model.isImage
                                text: { let t = (model.clipText || "").replace(/\s+/g, " "); return t.length > 100 ? t.substring(0, 100) + "…" : t; }
                                color: theme.textPrimary
                                font { family: theme.fontFamily; pixelSize: theme.notifBodySize }
                                Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
                            }
                            Text {
                                visible: model.isImage; text: model.mime || "image"
                                color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 11 }
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: clipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { copyProc.clipId = model.clipId; copyProc.running = true; root.itemSelected(); }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width - theme.notifPadding * 2; height: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: theme.textDimmed; opacity: 0.1
                        }
                    }
                }
            }
        }
    }
}
