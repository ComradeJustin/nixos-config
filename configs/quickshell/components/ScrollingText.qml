import QtQuick
import ".." as Root

// Scrolling text that auto-scrolls when content exceeds fixedWidth.
// Falls back to static elided text when content fits.
// Improvements: pause at start/end, fade edges when scrolling
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
    property int pauseDuration: 1500  // Pause at start/end before scrolling

    readonly property bool needsScroll: innerText.contentWidth > fixedWidth
    readonly property real contentWidth: innerText.contentWidth

    width: fixedWidth
    height: Root.Theme.barHeight
    clip: true

    // Fade edges when scrolling — uses layer + OpacityMask approach via gradient overlay
    // The gradient color matches whatever is behind (bar bg or group bg)
    property color fadeColor: Root.Theme.barBackground

    Rectangle {
        id: fadeLeft
        z: 2
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 12
        visible: root.needsScroll && scrollRow.x < -2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.fadeColor }
            GradientStop { position: 1.0; color: Qt.rgba(root.fadeColor.r, root.fadeColor.g, root.fadeColor.b, 0) }
        }
    }

    Rectangle {
        id: fadeRight
        z: 2
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 12
        visible: root.needsScroll
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(root.fadeColor.r, root.fadeColor.g, root.fadeColor.b, 0) }
            GradientStop { position: 1.0; color: root.fadeColor }
        }
    }

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

    SequentialAnimation {
        id: scrollAnim
        running: false

        // Pause at start
        PauseAnimation { duration: root.pauseDuration }

        // Scroll through
        NumberAnimation {
            id: scrollMove
            target: scrollRow
            property: "x"
            from: 0
            duration: 1000 // set dynamically
            easing.type: Easing.Linear
        }

        // Pause at end (brief)
        PauseAnimation { duration: 500 }

        // Loop
        ScriptAction { script: restartScroll() }
    }

    property real _lastWidth: 0

    function restartScroll() {
        let w = innerText.contentWidth + 40;
        if (root.needsScroll && root.scrollEnabled) {
            scrollAnim.stop();
            scrollRow.x = 0;
            _lastWidth = w;
            scrollMove.to = -w;
            scrollMove.duration = w / root.scrollSpeed * 1000;
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
