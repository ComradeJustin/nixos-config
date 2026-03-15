import QtQuick
import Niri 0.1
import "../.." as Root

Item {
    id: root

    Root.Theme { id: theme }

    property int fixedTextWidth: 180
    property real scrollSpeed: 30

    Niri {
        id: niri
        Component.onCompleted: connect()
        onErrorOccurred: function(error) {
            console.warn("WindowModule: niri error:", error);
        }
    }

    property string windowTitle: niri.focusedWindow?.title ?? ""
    property string windowIcon:  niri.focusedWindow?.iconPath ?? ""

    visible: windowTitle.length > 0

    property bool hasIcon: windowIcon.length > 0
    property bool needsScroll: innerText.contentWidth > fixedTextWidth

    implicitWidth: visible ? (hasIcon ? theme.iconSize + 6 : 0) + fixedTextWidth : 0
    implicitHeight: theme.barHeight

    Image {
        id: winIcon
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        source: root.hasIcon ? "file://" + root.windowIcon : ""
        sourceSize.width: theme.iconSize
        sourceSize.height: theme.iconSize
        width: theme.iconSize
        height: theme.iconSize
        visible: root.hasIcon
        smooth: true
    }

    // Clip container — same height as bar, clips overflow
    Item {
        id: textContainer
        anchors {
            left: root.hasIcon ? winIcon.right : parent.left
            leftMargin: root.hasIcon ? 6 : 0
        }
        width: root.fixedTextWidth
        height: theme.barHeight
        y: 0
        clip: true

        // Static text — same centering as TimeModule etc.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            text: root.windowTitle
            color: theme.textDimmed
            font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            elide: Text.ElideRight
            visible: !root.needsScroll
        }

        // Scrolling — Row centered vertically, animated horizontally
        Row {
            id: scrollRow
            anchors.verticalCenter: parent.verticalCenter
            visible: root.needsScroll

            Text {
                id: innerText
                text: root.windowTitle
                color: theme.textDimmed
                font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            }

            Item { width: 40; height: 1 }

            Text {
                text: root.windowTitle
                color: theme.textDimmed
                font: innerText.font
            }
        }

        NumberAnimation {
            id: scrollAnim
            target: scrollRow
            property: "x"
            from: 0
            loops: Animation.Infinite
            running: false
        }

        function restartScroll() {
            scrollAnim.stop();
            scrollRow.x = 0;
            if (root.needsScroll) {
                let w = innerText.contentWidth + 40;
                scrollAnim.to = -w;
                scrollAnim.duration = w / root.scrollSpeed * 1000;
                scrollAnim.start();
            }
        }

        Connections {
            target: root
            function onWindowTitleChanged() { textContainer.restartScroll(); }
        }
        Connections {
            target: innerText
            function onContentWidthChanged() { textContainer.restartScroll(); }
        }
    }
}
