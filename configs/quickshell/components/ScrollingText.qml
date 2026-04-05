import QtQuick
import ".." as Root

// Scrolling text that auto-scrolls when content exceeds fixedWidth.
// Falls back to static elided text when content fits.
// Smooth: eases in/out at edges, fades for seamless loop reset.
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
    property int pauseDuration: 2000

    readonly property bool needsScroll: innerText.contentWidth > fixedWidth
    readonly property real contentWidth: innerText.contentWidth

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

        Item { width: 50; height: 1 }

        Text {
            text: root.text
            color: root.textColor
            font: root.textFont
        }
    }

    SequentialAnimation {
        id: scrollAnim
        running: false

        // Pause at start position
        PauseAnimation { duration: root.pauseDuration }

        // Ease out of rest, cruise, ease into stop
        NumberAnimation {
            id: scrollMove
            target: scrollRow
            property: "x"
            from: 0
            duration: 1000 // set dynamically
            easing.type: Easing.InOutSine
        }

        // Pause at end before fading reset
        PauseAnimation { duration: 800 }

        // Fade out, reset, fade in for seamless loop
        NumberAnimation {
            target: scrollRow; property: "opacity"
            to: 0; duration: 250; easing.type: Easing.InCubic
        }

        ScriptAction { script: scrollRow.x = 0 }

        NumberAnimation {
            target: scrollRow; property: "opacity"
            to: 1; duration: 250; easing.type: Easing.OutCubic
        }

        // Loop — defer restart so animation fully completes first
        ScriptAction { script: loopTimer.start() }
    }

    Timer {
        id: loopTimer
        interval: 1
        onTriggered: {
            if (root.needsScroll && root.scrollEnabled)
                scrollAnim.start();
        }
    }

    property real _lastWidth: 0

    function restartScroll() {
        scrollAnim.stop();
        scrollRow.x = 0;
        scrollRow.opacity = 1;

        let w = innerText.contentWidth + 50;
        if (root.needsScroll && root.scrollEnabled) {
            _lastWidth = w;
            scrollMove.to = -w;
            scrollMove.duration = w / root.scrollSpeed * 1000;
            scrollAnim.start();
        } else {
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
