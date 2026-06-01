import QtQuick
import QtQuick.Effects
import ".." as Root

// Interactive slider/progress bar with rounded styling and smooth drag
Item {
    id: slider

    property real value: 0          // Current value (0-100 or custom range)
    property real minValue: 0       // Minimum value
    property real maxValue: 100     // Maximum value
    property bool interactive: true // Whether dragging is enabled
    property bool showHandle: true  // Show the drag handle
    property int trackHeight: 4    // Height of the track
    property int handleSize: 14    // Size of the handle
    property color accentColor: Root.Theme.textAccent
    property bool liveUpdate: true
    property bool showTooltip: false // Show percentage tooltip while dragging

    // Signals
    signal valueUpdated(real newValue)
    signal dragStarted()
    signal dragEnded()

    Timer {
        id: liveThrottle
        interval: 50
        onTriggered: {
            if (slider.dragging) {
                slider.value = slider.dragValue;
                slider.valueUpdated(slider.dragValue);
            }
        }
    }

    // Internal state
    property bool dragging: false
    property real dragValue: value

    // Computed ratio
    readonly property real ratio: {
        let range = maxValue - minValue;
        if (range <= 0) return 0;
        let v = dragging ? dragValue : value;
        return Math.max(0, Math.min(1, (v - minValue) / range));
    }

    height: Math.max(trackHeight, handleSize)

    // Background track (rounded)
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        height: slider.trackHeight
        radius: height / 2
        color: Root.Theme.layer2
    }

    // Fill track with gradient
    Rectangle {
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        height: slider.trackHeight
        radius: height / 2
        width: parent.width * slider.ratio

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.darker(slider.accentColor, 1.15) }
            GradientStop { position: 0.5; color: slider.accentColor }
            GradientStop { position: 1.0; color: Qt.darker(slider.accentColor, 1.15) }
        }

        Behavior on width {
            enabled: !slider.dragging
            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
        }
    }

    // Handle (circular, with drag glow)
    Rectangle {
        id: handleRect
        visible: slider.showHandle
        width: slider.dragging ? slider.handleSize + 2 : slider.handleSize
        height: width
        radius: width / 2
        color: slider.accentColor
        y: (parent.height - height) / 2
        x: (parent.width - width) * slider.ratio

        Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        layer.enabled: slider.dragging
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: slider.accentColor
            shadowBlur: 0.8
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        Behavior on x {
            enabled: !slider.dragging
            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
        }
    }

    // Drag tooltip
    Rectangle {
        id: dragTooltip
        visible: slider.showTooltip && slider.dragging
        x: handleRect.x + handleRect.width / 2 - width / 2
        y: handleRect.y - height - 6
        width: tooltipLabel.implicitWidth + 10
        height: tooltipLabel.implicitHeight + 6
        radius: Root.Theme.radiusSmall
        color: Root.Theme.layer2
        border.width: 1
        border.color: Root.Theme.borderColor
        opacity: slider.dragging ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.microDuration } }

        Text {
            id: tooltipLabel
            anchors.centerIn: parent
            text: Math.round(slider.dragValue) + "%"
            color: Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
        }
    }

    // Interaction
    MouseArea {
        anchors.fill: parent
        enabled: slider.interactive
        cursorShape: slider.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPressed: function(mouse) {
            slider.dragging = true;
            slider.dragStarted();
            updateDragValue(mouse.x);
        }

        onPositionChanged: function(mouse) {
            if (pressed) {
                updateDragValue(mouse.x);
                if (slider.liveUpdate) liveThrottle.restart();
            }
        }

        onReleased: {
            if (slider.dragging) {
                liveThrottle.stop();
                slider.value = slider.dragValue;
                slider.valueUpdated(slider.dragValue);
                slider.dragging = false;
                slider.dragEnded();
            }
        }

        function updateDragValue(x) {
            let ratio = Math.max(0, Math.min(1, x / slider.width));
            slider.dragValue = slider.minValue + ratio * (slider.maxValue - slider.minValue);
        }
    }
}
