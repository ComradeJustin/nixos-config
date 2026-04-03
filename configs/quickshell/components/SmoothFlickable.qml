import QtQuick

// Flickable with momentum scrolling for trackpad/mouse wheel
// Drop-in replacement: use exactly like Flickable
Flickable {
    id: flick

    property real scrollMultiplier: 0.35
    property real momentumDecay: 0.85
    property real velocityThreshold: 0.2

    // Internal momentum state
    property real _velocity: 0
    property real _lastTime: 0

    boundsBehavior: Flickable.DragAndOvershootBounds

    WheelHandler {
        id: wheelHandler
        orientation: Qt.Vertical
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: function(event) {
            let now = Date.now();
            let dt = now - flick._lastTime;
            flick._lastTime = now;

            // Convert wheel delta to pixels
            let delta = -event.angleDelta.y / 120 * 40 * flick.scrollMultiplier;

            // Accumulate velocity if scrolling in same direction within 150ms
            if (dt < 150 && delta * flick._velocity > 0) {
                flick._velocity = flick._velocity * 0.6 + delta * 0.8;
            } else {
                flick._velocity = delta;
            }

            // Apply immediate scroll
            flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + delta));

            // Start momentum
            momentumTimer.restart();
            event.accepted = true;
        }
    }

    Timer {
        id: momentumTimer
        interval: 16  // ~60fps
        repeat: true
        onTriggered: {
            flick._velocity *= flick.momentumDecay;

            if (Math.abs(flick._velocity) < flick.velocityThreshold) {
                flick._velocity = 0;
                momentumTimer.stop();
                return;
            }

            let newY = flick.contentY + flick._velocity;
            // Clamp with soft bounce at edges
            if (newY < 0) {
                newY = 0;
                flick._velocity = 0;
                momentumTimer.stop();
            } else if (newY > flick.contentHeight - flick.height) {
                newY = Math.max(0, flick.contentHeight - flick.height);
                flick._velocity = 0;
                momentumTimer.stop();
            }

            flick.contentY = newY;
        }
    }
}
