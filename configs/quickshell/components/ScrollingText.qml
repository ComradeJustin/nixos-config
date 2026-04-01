import QtQuick
import ".." as Root

// Scrolling text that auto-scrolls when content exceeds fixedWidth.
// Falls back to static elided text when content fits.
Item {
    id: root

    property string text: ""
    property int fixedWidth: 200
    property real scrollSpeed: 30
    property color textColor: Root.Theme.textDimmed
    property font textFont: Qt.font({
        family: Root.Theme.fontFamily,
        pixelSize: Root.Theme.fontSize,
        bold: Root.Theme.fontBold
    })
    property bool scrollEnabled: true

    readonly property bool needsScroll: innerText.contentWidth > fixedWidth

    width: fixedWidth
    height: Root.Theme.barHeight
    clip: true

    // Static text — when content fits
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        text: root.text
        color: root.textColor
        font: root.textFont
        elide: Text.ElideRight
        visible: !root.needsScroll
    }

    // Scrolling — Row with duplicated text
    Row {
        id: scrollRow
        anchors.verticalCenter: parent.verticalCenter
        visible: root.needsScroll

        Text {
            id: innerText
            text: root.text
            color: root.textColor
            font: root.textFont
        }

        Item { width: 40; height: 1 }

        Text {
            text: root.text
            color: root.textColor
            font: root.textFont
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

    property real _lastWidth: 0

    function restartScroll() {
        let w = innerText.contentWidth + 40;
        if (root.needsScroll && root.scrollEnabled) {
            if (scrollAnim.running && Math.abs(_lastWidth - w) < 1) return;
            scrollAnim.stop();
            if (_lastWidth > 0 && Math.abs(_lastWidth - w) < 50) {
                scrollRow.x = scrollRow.x * (w / _lastWidth);
                scrollRow.x = Math.max(-w, Math.min(0, scrollRow.x));
            } else {
                scrollRow.x = 0;
            }
            _lastWidth = w;
            scrollAnim.to = -w;
            scrollAnim.duration = w / root.scrollSpeed * 1000;
            scrollAnim.start();
        } else {
            scrollAnim.stop();
            scrollRow.x = 0;
            _lastWidth = 0;
        }
    }

    onTextChanged: restartScroll()
    onScrollEnabledChanged: restartScroll()

    Connections {
        target: innerText
        function onContentWidthChanged() { root.restartScroll(); }
    }
}
