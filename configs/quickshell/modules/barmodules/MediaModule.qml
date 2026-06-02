import QtQuick
import QtQuick.Effects
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

Item {
    id: root

    property int fixedTextWidth: 200
    property var playerService: Core.ServiceManager.player

    property bool isPlaying: playerService ? playerService.isPlaying : false
    property string mediaText: playerService ? playerService.displayText : ""
    property bool hasMedia: mediaText.length > 0

    // When playback ends and the module collapses away, close the controls
    // popup too — otherwise it lingers with no module to anchor to.
    onHasMediaChanged: {
        if (!hasMedia) {
            let bp = Core.ServiceManager.barPopup;
            if (bp) bp.dismissFor(root);
        }
    }

    // Left: icon glyph bearing provides ~3px visual padding
    // Right: add 3px to match so text doesn't sit flush against group edge
    implicitWidth: hasMedia ? playIcon.width + 6 + Math.min(scrollText.contentWidth, fixedTextWidth) + 3 : 0
    implicitHeight: Root.Theme.barHeight
    opacity: hasMedia ? 1 : 0
    // No clip: the hover highlight paints into the section pill's padding
    // (±6px), which a clip would cut off. Content stays in-bounds in steady
    // state; only the width-grow tween briefly extends past the edge.
    clip: false

    Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic } }
    Behavior on implicitWidth { NumberAnimation { duration: Root.Theme.anim.resizeDuration; easing.type: Easing.InOutCubic } }

    // Hover background — sized to the section pill (which adds 6px horizontal /
    // 4px vertical padding around the module), so the highlight fills the
    // visible island instead of sitting inset inside it.
    Rectangle {
        id: hoverBg
        x: -6
        width: parent.width + 12
        y: 4
        height: parent.height - 8
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

    // Leading control: a play glyph when paused, a mini cava equalizer while
    // playing (the visualizer lives in the icon slot, so it stays centered with
    // the text). Click toggles playback either way.
    Item {
        id: playIcon
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: Root.Theme.iconSize
        height: Root.Theme.iconSize

        scale: 1.0
        SequentialAnimation {
            id: playBounce
            running: false
            NumberAnimation { target: playIcon; property: "scale"; to: 0.85; duration: 60; easing.type: Easing.InQuad }
            NumberAnimation { target: playIcon; property: "scale"; to: 1.0; duration: Root.Theme.anim.microDuration; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
        }

        Text {
            anchors.centerIn: parent
            visible: !root.isPlaying
            text: Root.Icons.mediaPlay
            color: Root.Theme.domainMedia
            font { family: Root.Theme.fontMono; pixelSize: Root.Theme.iconSize }
        }

        Row {
            anchors.fill: parent
            spacing: 1
            visible: root.isPlaying
            Repeater {
                model: 5
                Rectangle {
                    width: Math.max(1, (parent.width - 4) / 5)
                    // Grow symmetrically from the vertical centre so the bars sit
                    // on the same line as the glyph/text, not the icon's bottom.
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 1
                    color: Root.Theme.domainMedia
                    height: {
                        let vals = root.playerService ? root.playerService.cavaBars : [];
                        if (!vals || vals.length === 0) return 2;
                        let i = Math.floor(index * vals.length / 5);
                        return Math.max(2, (vals[i] || 0) * parent.height);
                    }
                    Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }
            }
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
        fixedWidth: Math.min(scrollText.contentWidth, root.fixedTextWidth)
        text: root.mediaText
        textColor: mediaHover.containsMouse ? Root.Theme.domainMedia : Root.Theme.textPrimary
        textFont: Qt.font({ family: Root.Theme.fontMono, pixelSize: Root.Theme.fontSize, bold: true })
        scrollEnabled: root.isPlaying

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: {
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
            width: parent.width; spacing: Root.Theme.spacingS

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
                    Components.Skeleton {
                        anchors.fill: parent
                        radius: parent.radius
                        visible: (root.playerService && root.playerService.trackArtUrl.length > 0) && artImg.status !== Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent; text: Root.Icons.mediaPlay
                        color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSize3XL }
                        visible: !root.playerService || root.playerService.trackArtUrl.length === 0
                    }
                }
            }

            Column {
                width: parent.width - 56
                anchors.verticalCenter: parent.verticalCenter; spacing: 2

                Text {
                    text: root.playerService ? root.playerService.trackTitle : ""
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeL; bold: true }
                    width: parent.width; elide: Text.ElideRight
                }
                Text {
                    text: root.playerService ? root.playerService.trackArtist : ""
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeS }
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
            property bool settling: false
            property real seekTarget: -1
            // What the fill/handle actually show: the dragged position while
            // scrubbing AND until the real (1s-polled) position catches up — so
            // it never glides backwards to the stale position then forwards.
            readonly property real displayRatio: (dragging || settling) ? dragRatio : ratio
            onPosChanged: if (settling && (seekTarget < 0 || Math.abs(pos - seekTarget) < 1.5)) { settling = false; seekSettleTimer.stop(); }
            Timer { id: seekSettleTimer; interval: 1500; onTriggered: seekBar.settling = false }

            Rectangle {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: 3; radius: height / 2; color: Root.Theme.textDimmed; opacity: 0.3
            }
            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                height: 3; radius: height / 2
                width: parent.width * seekBar.displayRatio
                // Position only polls once a second; interpolate so the fill
                // advances smoothly instead of jumping in 1s steps (off while
                // scrubbing so the thumb tracks the finger instantly).
                Behavior on width { enabled: !seekBar.dragging; NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Root.Theme.domainMedia }
                    GradientStop { position: 1.0; color: Qt.lighter(Root.Theme.domainMedia, 1.3) }
                }
            }
            Rectangle {
                width: 10; height: 10; radius: 5; color: Root.Theme.domainMedia
                y: (parent.height - 10) / 2
                x: (parent.width - 10) * seekBar.displayRatio
                Behavior on x { enabled: !seekBar.dragging; NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
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
                    seekBar.dragging = false;
                    if (root.playerService && seekBar.len > 0) {
                        seekBar.seekTarget = seekBar.dragRatio * seekBar.len;
                        root.playerService.seek(seekBar.seekTarget);
                        seekBar.settling = true;
                        seekSettleTimer.restart();
                    }
                }
            }
        }

        // Time labels
        Item {
            width: parent.width; height: 12
            Text {
                anchors.left: parent.left
                text: root.playerService ? root.playerService.formatTime(seekBar.displayRatio * seekBar.len) : "0:00"
                color: Root.Theme.textDimmed; font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeXS }
            }
            Text {
                anchors.right: parent.right
                text: root.playerService ? root.playerService.formatTime(seekBar.len) : "0:00"
                color: Root.Theme.textDimmed; font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeXS }
            }
        }

        // Transport controls
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: Root.Theme.spacingM; height: 32

            Rectangle {
                width: 28; height: 28; radius: Root.Theme.radiusSmall
                color: prevMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1) : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: Root.Icons.prev; color: prevMouse.containsMouse ? Root.Theme.domainMedia : Root.Theme.textPrimary; font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSize2XL } }
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
                Text { anchors.centerIn: parent; text: root.isPlaying ? Root.Icons.mediaPause : Root.Icons.mediaPlay; color: Root.Theme.barBackground; font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSize2XL } }
                MouseArea { id: popupPlayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { popupPlayBounce.start(); if (root.playerService) root.playerService.togglePlaying(); } }
            }

            Rectangle {
                width: 28; height: 28; radius: Root.Theme.radiusSmall
                color: nextMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1) : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: Root.Icons.next; color: nextMouse.containsMouse ? Root.Theme.domainMedia : Root.Theme.textPrimary; font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSize2XL } }
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
                    spacing: Root.Theme.spacingXS

                    property string _prevLyric: ""

                    Text {
                        id: currentLyricText
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.playerService ? root.playerService.currentLyric : ""
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeM; bold: true }
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
                        font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeXS }
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
                        ParallelAnimation {
                            NumberAnimation {
                                target: lyricsSlider; property: "opacity"
                                from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: lyricsSlider; property: "y"
                                from: 14; to: 6; duration: Root.Theme.anim.exitDuration; easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }

    }
}
