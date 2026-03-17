import QtQuick
import "../.." as Root

Item {
    id: root

    Root.Theme { id: theme }

    property int fixedTextWidth: 200
    property real scrollSpeed: 30
    property var playerService: null

    signal cavaToggled()

    property bool isPlaying: playerService ? playerService.isPlaying : false
    property string mediaText: playerService ? playerService.displayText : ""

    visible: mediaText.length > 0
    property bool needsScroll: innerText.contentWidth > fixedTextWidth

    implicitWidth: visible ? playIcon.width + 6 + fixedTextWidth : 0
    implicitHeight: theme.barHeight

    Text {
        id: playIcon
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: root.isPlaying ? theme.iconMediaPlay : theme.iconMediaPause
        color: theme.textAccent
        font { family: theme.fontFamily; pixelSize: theme.iconSize }

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: { if (root.playerService) root.playerService.togglePlaying(); }
        }
    }

    Item {
        id: textContainer
        anchors { left: playIcon.right; leftMargin: 6 }
        width: root.fixedTextWidth; height: theme.barHeight; y: 0; clip: true

        Text {
            anchors.verticalCenter: parent.verticalCenter; width: parent.width
            text: root.mediaText; color: theme.textDimmed
            font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            elide: Text.ElideRight; visible: !root.needsScroll
        }

        Row {
            id: scrollRow; anchors.verticalCenter: parent.verticalCenter; visible: root.needsScroll
            Text {
                id: innerText; text: root.mediaText; color: theme.textDimmed
                font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            }
            Item { width: 40; height: 1 }
            Text { text: root.mediaText; color: theme.textDimmed; font: innerText.font }
        }

        NumberAnimation {
            id: scrollAnim; target: scrollRow; property: "x"; from: 0
            loops: Animation.Infinite; running: false
        }

        property real lastWidth: 0

        function restartScroll() {
            let w = innerText.contentWidth + 40;
            if (root.needsScroll && root.isPlaying) {
                if (scrollAnim.running && Math.abs(lastWidth - w) < 1) {
                    // Width unchanged, keep scrolling
                    return;
                }
                scrollAnim.stop();
                // Preserve relative position if width similar
                if (lastWidth > 0 && Math.abs(lastWidth - w) < 50) {
                    scrollRow.x = scrollRow.x * (w / lastWidth);
                    scrollRow.x = Math.max(-w, Math.min(0, scrollRow.x));
                } else {
                    scrollRow.x = 0;
                }
                lastWidth = w;
                scrollAnim.to = -w; scrollAnim.duration = w / root.scrollSpeed * 1000;
                scrollAnim.start();
            } else {
                scrollAnim.stop(); scrollRow.x = 0; lastWidth = 0;
            }
        }

        Connections { target: root; function onMediaTextChanged() { textContainer.restartScroll(); } function onIsPlayingChanged() { textContainer.restartScroll(); } }
        Connections { target: innerText; function onContentWidthChanged() { textContainer.restartScroll(); } }

        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cavaToggled() }
    }
}
