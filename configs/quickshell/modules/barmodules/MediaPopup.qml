import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.." as Root

// Media popup panel with visualizer and controls
PanelWindow {
    id: popup

    property var playerService: null
    property bool showCava: false
    property bool barHidden: false

    // Computed property for animation state
    readonly property bool cavaWanted: showCava && !barHidden

    onCavaWantedChanged: {
        if (cavaWanted) visible = true;
    }

    visible: false

    anchors { top: true }
    implicitWidth: Root.Theme.cavaWidth
    margins.top: Root.Theme.barHeight
    implicitHeight: Root.Theme.cavaHeight + 6

    WlrLayershell.namespace: "quickshell-cava"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: cavaRect
            width: parent.width
            height: Root.Theme.cavaHeight
            radius: 0
            color: Root.Theme.cavaBackground
            border.width: Root.Theme.borderWidth
            border.color: Root.Theme.borderColor

            y: popup.cavaWanted ? 6 : -(Root.Theme.cavaHeight + 6)

            Behavior on y {
                NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
            }

            onYChanged: {
                if (!popup.cavaWanted && y <= -(Root.Theme.cavaHeight + 5))
                    popup.visible = false;
            }

            // Block all clicks from falling through to compositor
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            // Cava bars as full background (from playerService)
            Row {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 1
                opacity: 0.2

                Repeater {
                    model: Root.Theme.cavaBars
                    Rectangle {
                        width: Math.max(1, (Root.Theme.cavaWidth - Root.Theme.cavaBars) / Root.Theme.cavaBars)
                        height: {
                            let vals = popup.playerService ? popup.playerService.cavaBars : [];
                            if (!vals || index >= vals.length) return 2;
                            return Math.max(2, vals[index] * parent.height);
                        }
                        radius: 0
                        anchors.bottom: parent.bottom
                        color: Root.Theme.cavaBarColor  // Consistent color, no peak variation
                        Behavior on height { NumberAnimation { duration: 50 } }
                    }
                }
            }

            // Content
            Column {
                id: mediaContent
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 4

                Row {
                    width: parent.width; spacing: 10

                    Rectangle {
                        width: Root.Theme.cavaArtSize; height: Root.Theme.cavaArtSize
                        radius: Root.Theme.radiusSmall; clip: true
                        color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.2)
                        border.width: Root.Theme.borderWidth
                        border.color: Root.Theme.borderColor

                        Image {
                            id: artImg; anchors.fill: parent
                            source: popup.playerService ? popup.playerService.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop; smooth: true; asynchronous: true
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent; text: Root.Theme.iconMediaPlay; color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: 24 }
                            visible: artImg.status !== Image.Ready
                        }
                    }

                    Column {
                        width: parent.width - Root.Theme.cavaArtSize - 10
                        anchors.verticalCenter: parent.verticalCenter; spacing: 2

                        Text {
                            text: popup.playerService ? popup.playerService.trackTitle : ""
                            color: Root.Theme.textPrimary
                            font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true }
                            width: parent.width; elide: Text.ElideRight
                        }
                        Text {
                            text: popup.playerService ? popup.playerService.trackArtist : ""
                            color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: 11 }
                            width: parent.width; elide: Text.ElideRight
                            visible: popup.playerService ? popup.playerService.trackArtist.length > 0 : false
                        }
                    }
                }

                // Seekable progress bar
                Item {
                    id: seekBar
                    width: parent.width; height: 16
                    property real pos: popup.playerService ? popup.playerService.position : 0
                    property real len: popup.playerService ? popup.playerService.length : 0
                    property real ratio: len > 0 ? pos / len : 0
                    property bool dragging: false
                    property real dragRatio: 0

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        height: 3; radius: height / 2; color: Root.Theme.textDimmed; opacity: 0.3
                    }
                    Rectangle {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        height: 3; radius: height / 2; color: Root.Theme.textAccent
                        width: parent.width * (seekBar.dragging ? seekBar.dragRatio : seekBar.ratio)
                    }
                    Rectangle {
                        width: 10; height: 10; radius: Root.Theme.radiusSmall; color: Root.Theme.textAccent
                        y: (parent.height - 10) / 2
                        x: (parent.width - 10) * (seekBar.dragging ? seekBar.dragRatio : seekBar.ratio)
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onPressed: function(mouse) {
                            seekBar.dragging = true;
                            seekBar.dragRatio = Math.max(0, Math.min(1, mouse.x / seekBar.width));
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed)
                                seekBar.dragRatio = Math.max(0, Math.min(1, mouse.x / seekBar.width));
                        }
                        onReleased: {
                            if (popup.playerService && seekBar.len > 0)
                                popup.playerService.seek(seekBar.dragRatio * seekBar.len);
                            seekBar.dragging = false;
                        }
                    }
                }

                // Time labels
                Item {
                    width: parent.width; height: 12
                    Text {
                        anchors.left: parent.left
                        text: popup.playerService ? popup.playerService.formatTime(seekBar.dragging ? seekBar.dragRatio * seekBar.len : seekBar.pos) : "0:00"
                        color: Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: 10 }
                    }
                    Text {
                        anchors.right: parent.right
                        text: popup.playerService ? popup.playerService.formatTime(seekBar.len) : "0:00"
                        color: Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: 10 }
                    }
                }

                // Controls
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 16; height: 32

                    Rectangle {
                        width: 28; height: 28
                        radius: Root.Theme.radiusSmall
                        color: prevMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: Root.Theme.iconPrev
                            color: prevMouse.containsMouse ? Root.Theme.textAccent : Root.Theme.textPrimary
                            font { family: Root.Theme.fontFamily; pixelSize: 16 }
                        }
                        MouseArea { id: prevMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (popup.playerService) popup.playerService.previous(); } }
                    }

                    Rectangle {
                        width: 32; height: 32; radius: Root.Theme.radiusSmall
                        color: playMouse.containsMouse ? Qt.lighter(Root.Theme.textAccent, 1.1) : Root.Theme.textAccent
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: (popup.playerService && popup.playerService.isPlaying) ? Root.Theme.iconMediaPause : Root.Theme.iconMediaPlay
                            color: Root.Theme.barBackground
                            font { family: Root.Theme.fontFamily; pixelSize: 16 }
                        }
                        MouseArea { id: playMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (popup.playerService) popup.playerService.togglePlaying(); } }
                    }

                    Rectangle {
                        width: 28; height: 28
                        radius: Root.Theme.radiusSmall
                        color: nextMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: Root.Theme.iconNext
                            color: nextMouse.containsMouse ? Root.Theme.textAccent : Root.Theme.textPrimary
                            font { family: Root.Theme.fontFamily; pixelSize: 16 }
                        }
                        MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (popup.playerService) popup.playerService.next(); } }
                    }
                }
            }
        }
    }
}
