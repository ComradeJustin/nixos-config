import QtQuick
import QtQuick.Effects
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

Item {
    id: root

    property int fixedTextWidth: 200
    property var playerService: Core.ServiceManager.player
    property bool cavaOpen: false
    signal cavaToggled()

    property bool isPlaying: playerService ? playerService.isPlaying : false
    property string mediaText: playerService ? playerService.displayText : ""
    property bool hasMedia: mediaText.length > 0

    // Left: icon glyph bearing provides ~3px visual padding
    // Right: add 3px to match so text doesn't sit flush against group edge
    implicitWidth: hasMedia ? playIcon.width + 6 + Math.min(scrollText.contentWidth, fixedTextWidth) + 3 : 0
    implicitHeight: Root.Theme.barHeight
    opacity: hasMedia ? 1 : 0
    clip: true

    Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic } }
    Behavior on implicitWidth { NumberAnimation { duration: Root.Theme.anim.resizeDuration; easing.type: Easing.InOutCubic } }

    // Hover background
    Rectangle {
        id: hoverBg
        anchors {
            fill: parent
            topMargin: 4
            bottomMargin: 4
        }
        radius: Root.Theme.radiusSmall
        color: mediaHover.containsMouse
            ? Root.Theme.layer1Hover
            : "transparent"
        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
    }

    MouseArea {
        id: mediaHover
        anchors.fill: parent; hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.NoButton
    }

    Text {
        id: playIcon
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: root.isPlaying ? Root.Icons.mediaPlay : Root.Icons.mediaPause
        color: Root.Theme.domainMedia
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }

        // Bounce animation on play/pause toggle
        scale: 1.0
        SequentialAnimation {
            id: playBounce
            running: false
            NumberAnimation { target: playIcon; property: "scale"; to: 0.85; duration: 60; easing.type: Easing.InQuad }
            NumberAnimation { target: playIcon; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
        }

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: {
                playBounce.restart();
                if (root.playerService) root.playerService.togglePlaying();
            }
        }
    }

    Components.ScrollingText {
        id: scrollText
        anchors { left: playIcon.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
        fixedWidth: root.fixedTextWidth
        text: root.mediaText
        textColor: mediaHover.containsMouse ? Root.Theme.domainMedia : Root.Theme.textPrimary
        textFont: Qt.font({ family: Root.Theme.fontFamily, pixelSize: Root.Theme.fontSize, bold: true })
        scrollEnabled: root.isPlaying

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.cavaOpen) root.cavaToggled();
                let bp = Core.ServiceManager.barPopup;
                if (bp) bp.toggle(root, mediaPopup);
            }
        }
    }

    // Tooltip on hover
    Connections {
        target: mediaHover
        function onContainsMouseChanged() {
            let bt = Core.ServiceManager.barTooltip;
            if (mediaHover.containsMouse) {
                if (bt) bt.show(root, "Now Playing");
            } else {
                if (bt) bt.hide();
            }
        }
    }

    // ── Click popup: track info, seek bar, transport, cava toggle ──
    property Components.HoverPopup mediaPopup: Components.HoverPopup {
        visible: false
        popupWidth: 280

        // Album art + track info
        Row {
            width: parent.width; spacing: 8

            Item {
                width: 48; height: 48

                // Ambient glow
                Image {
                    anchors.centerIn: parent
                    width: parent.width + 12; height: parent.height + 12
                    source: root.playerService ? root.playerService.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop; smooth: true; asynchronous: true
                    opacity: artImg.status === Image.Ready ? 0.3 : 0
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true; blurMax: 24; blur: 0.8
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Root.Theme.radiusSmall; clip: true
                    color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.2)
                    border.width: Root.Theme.borderWidth
                    border.color: Root.Theme.borderColor

                    Image {
                        id: artImg; anchors.fill: parent
                        source: root.playerService ? root.playerService.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop; smooth: true; asynchronous: true
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent; text: Root.Icons.mediaPlay
                        color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: 18 }
                        visible: artImg.status !== Image.Ready
                    }
                }
            }

            Column {
                width: parent.width - 56
                anchors.verticalCenter: parent.verticalCenter; spacing: 2

                Text {
                    text: root.playerService ? root.playerService.trackTitle : ""
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true }
                    width: parent.width; elide: Text.ElideRight
                }
                Text {
                    text: root.playerService ? root.playerService.trackArtist : ""
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: 11 }
                    width: parent.width; elide: Text.ElideRight
                    visible: root.playerService ? root.playerService.trackArtist.length > 0 : false
                }
            }
        }

        // Seek bar
        Item {
            id: seekBar
            width: parent.width; height: 16
            property real pos: root.playerService ? root.playerService.position : 0
            property real len: root.playerService ? root.playerService.length : 0
            property real ratio: len > 0 ? pos / len : 0
            property bool dragging: false
            property real dragRatio: 0

            Rectangle {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: 3; radius: height / 2; color: Root.Theme.textDimmed; opacity: 0.3
            }
            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                height: 3; radius: height / 2
                width: parent.width * (seekBar.dragging ? seekBar.dragRatio : seekBar.ratio)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Root.Theme.domainMedia }
                    GradientStop { position: 1.0; color: Qt.lighter(Root.Theme.domainMedia, 1.3) }
                }
            }
            Rectangle {
                width: 10; height: 10; radius: 5; color: Root.Theme.domainMedia
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
                    if (pressed) seekBar.dragRatio = Math.max(0, Math.min(1, mouse.x / seekBar.width));
                }
                onReleased: {
                    if (root.playerService && seekBar.len > 0)
                        root.playerService.seek(seekBar.dragRatio * seekBar.len);
                    seekBar.dragging = false;
                }
            }
        }

        // Time labels
        Item {
            width: parent.width; height: 12
            Text {
                anchors.left: parent.left
                text: root.playerService ? root.playerService.formatTime(seekBar.dragging ? seekBar.dragRatio * seekBar.len : seekBar.pos) : "0:00"
                color: Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: 10 }
            }
            Text {
                anchors.right: parent.right
                text: root.playerService ? root.playerService.formatTime(seekBar.len) : "0:00"
                color: Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: 10 }
            }
        }

        // Transport controls
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 12; height: 32

            Rectangle {
                width: 28; height: 28; radius: Root.Theme.radiusSmall
                color: prevMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1) : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: Root.Icons.prev; color: prevMouse.containsMouse ? Root.Theme.domainMedia : Root.Theme.textPrimary; font { family: Root.Theme.fontFamily; pixelSize: 16 } }
                MouseArea { id: prevMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.playerService) root.playerService.previous(); } }
            }

            Rectangle {
                id: popupPlayBtn
                width: 32; height: 32; radius: Root.Theme.radiusSmall
                color: popupPlayMouse.containsMouse ? Qt.lighter(Root.Theme.domainMedia, 1.1) : Root.Theme.domainMedia
                anchors.verticalCenter: parent.verticalCenter
                scale: 1.0
                SequentialAnimation {
                    id: popupPlayBounce
                    NumberAnimation { target: popupPlayBtn; property: "scale"; to: 0.85; duration: 60; easing.type: Easing.InQuad }
                    NumberAnimation { target: popupPlayBtn; property: "scale"; to: 1.0; duration: 80; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                }
                Text { anchors.centerIn: parent; text: root.isPlaying ? Root.Icons.mediaPause : Root.Icons.mediaPlay; color: Root.Theme.barBackground; font { family: Root.Theme.fontFamily; pixelSize: 16 } }
                MouseArea { id: popupPlayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { popupPlayBounce.start(); if (root.playerService) root.playerService.togglePlaying(); } }
            }

            Rectangle {
                width: 28; height: 28; radius: Root.Theme.radiusSmall
                color: nextMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1) : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: Root.Icons.next; color: nextMouse.containsMouse ? Root.Theme.domainMedia : Root.Theme.textPrimary; font { family: Root.Theme.fontFamily; pixelSize: 16 } }
                MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.playerService) root.playerService.next(); } }
            }
        }

        // Synced lyrics
        Column {
            width: parent.width
            visible: root.playerService && root.playerService.hasLyrics
            spacing: 0

            Rectangle {
                width: parent.width; height: 1
                color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.15)
            }

            Item {
                width: parent.width; height: 44
                clip: true

                Column {
                    id: lyricsSlider
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    y: 6
                    spacing: 4

                    property string _prevLyric: ""

                    Text {
                        id: currentLyricText
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.playerService ? root.playerService.currentLyric : ""
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: 12; bold: true }
                        horizontalAlignment: Text.AlignHCenter
                        width: lyricsSlider.width
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.playerService ? root.playerService.nextLyric : ""
                        color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: 10 }
                        horizontalAlignment: Text.AlignHCenter
                        width: lyricsSlider.width
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        opacity: text.length > 0 ? 0.5 : 0
                    }

                    Connections {
                        target: root.playerService
                        function onCurrentLyricChanged() {
                            let cur = root.playerService.currentLyric;
                            if (cur.length > 0 && cur !== lyricsSlider._prevLyric) {
                                lyricsSlider._prevLyric = cur;
                                lyricSlideAnim.restart();
                            }
                        }
                    }

                    SequentialAnimation {
                        id: lyricSlideAnim
                        NumberAnimation {
                            target: lyricsSlider; property: "opacity"
                            from: 1; to: 0; duration: 80; easing.type: Easing.InQuad
                        }
                        NumberAnimation {
                            target: lyricsSlider; property: "y"
                            from: 14; to: 6; duration: 0
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: lyricsSlider; property: "opacity"
                                from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: lyricsSlider; property: "y"
                                from: 14; to: 6; duration: 200; easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }

        // Cava visualizer toggle
        Rectangle {
            width: parent.width; height: 28; radius: Root.Theme.radiusSmall
            color: cavaMouse.containsMouse
                ? Qt.rgba(Root.Theme.domainMedia.r, Root.Theme.domainMedia.g, Root.Theme.domainMedia.b, 0.12)
                : Qt.rgba(Root.Theme.domainMedia.r, Root.Theme.domainMedia.g, Root.Theme.domainMedia.b, 0.05)
            border.width: 1
            border.color: Qt.rgba(Root.Theme.domainMedia.r, Root.Theme.domainMedia.g, Root.Theme.domainMedia.b, 0.2)

            Row {
                anchors.centerIn: parent; spacing: 6
                Text { text: Root.Icons.equalizer; color: Root.Theme.domainMedia; font { family: Root.Theme.fontFamily; pixelSize: 14 } }
                Text { text: "Visualizer"; color: Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: 11 } }
            }
            MouseArea {
                id: cavaMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.cavaToggled();
                    let bp = Core.ServiceManager.barPopup;
                    if (bp) bp.dismiss();
                }
            }
        }
    }
}
