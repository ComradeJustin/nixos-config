import QtQuick
import ".." as Root

// Reusable slider/progress bar component with brutalist styling
Item {
    id: slider

    property real value: 0          // Current value (0-100 or custom range)
    property real minValue: 0       // Minimum value
    property real maxValue: 100     // Maximum value
    property bool interactive: true // Whether dragging is enabled
    property bool showHandle: true  // Show the drag handle
    property int trackHeight: 3     // Height of the track
    property int handleSize: 12     // Size of the handle (square)
    property color accentColor: Root.Theme.textAccent // Accent color for fill and handle

    // Signals
    signal valueUpdated(real newValue)
    signal dragStarted()
    signal dragEnded()

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

    // Background track
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        height: slider.trackHeight
        radius: height / 2  // Fully rounded track
        color: Root.Theme.textDimmed
        opacity: 0.3
    }

    // Fill track
    Rectangle {
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        height: slider.trackHeight
        radius: height / 2  // Fully rounded track
        color: slider.accentColor
        width: parent.width * slider.ratio

        Behavior on width {
            enabled: !slider.dragging
            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
        }
    }

    // Handle
    Rectangle {
        visible: slider.showHandle
        width: slider.handleSize
        height: slider.handleSize
        radius: Root.Theme.radiusSmall  // Slightly rounded handle
        color: slider.accentColor
        y: (parent.height - height) / 2
        x: (parent.width - width) * slider.ratio

        Behavior on x {
            enabled: !slider.dragging
            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
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
            }
        }

        onReleased: {
            if (slider.dragging) {
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
