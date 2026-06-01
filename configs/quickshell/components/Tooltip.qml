import QtQuick
import ".." as Root

// Tooltip that appears with a subtle slide-up + fade animation
Item {
    id: tooltip
    visible: false
    z: 999

    property string text: ""
    property Item target: null
    property int delay: 500
    property int showDuration: 3000

    width: label.implicitWidth + 12
    height: label.implicitHeight + 8

    Timer {
        id: showTimer
        interval: tooltip.delay
        onTriggered: {
            if (tooltip.text.length > 0) {
                tooltip.visible = true;
                hideTimer.start();
            }
        }
    }

    Timer {
        id: hideTimer
        interval: tooltip.showDuration
        onTriggered: tooltip.visible = false
    }

    function show() {
        showTimer.start();
    }

    function hide() {
        showTimer.stop();
        hideTimer.stop();
        tooltip.visible = false;
    }

    Rectangle {
        anchors.fill: parent
        radius: Root.Theme.radiusSmall
        color: Root.Theme.layer2
        border.width: 1
        border.color: Root.Theme.borderColor

        Text {
            id: label
            anchors.centerIn: parent
            text: tooltip.text
            color: Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
        }
    }

    // Slide up + fade in/out
    opacity: visible ? 1 : 0
    transform: Translate {
        id: tipSlide
        y: tooltip.visible ? 0 : 4
        Behavior on y { NumberAnimation { duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic } }
    }

    Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic } }
}
