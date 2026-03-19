import QtQuick
import Niri 0.1
import "../.." as Root

Item {
    id: root

    // Theme is now a singleton - access via Root.Theme.propertyName

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

    implicitWidth: visible ? (hasIcon ? Root.Theme.iconSize + 6 : 0) + fixedTextWidth : 0
    implicitHeight: Root.Theme.barHeight

    Image {
        id: winIcon
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        source: root.hasIcon ? "file://" + root.windowIcon : ""
        sourceSize.width: Root.Theme.iconSize
        sourceSize.height: Root.Theme.iconSize
        width: Root.Theme.iconSize
        height: Root.Theme.iconSize
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
        height: Root.Theme.barHeight
        y: 0
        clip: true

        // Static text — same centering as TimeModule etc.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            text: root.windowTitle
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: Root.Theme.fontBold }
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
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: Root.Theme.fontBold }
            }

            Item { width: 40; height: 1 }

            Text {
                text: root.windowTitle
                color: Root.Theme.textDimmed
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

        property real lastWidth: 0

        function restartScroll() {
            let w = innerText.contentWidth + 40;
            if (root.needsScroll) {
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
                scrollAnim.to = -w;
                scrollAnim.duration = w / root.scrollSpeed * 1000;
                scrollAnim.start();
            } else {
                scrollAnim.stop(); scrollRow.x = 0; lastWidth = 0;
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
