import QtQuick

// Flickable with momentum scrolling for trackpad/mouse wheel
// Drop-in replacement: use exactly like Flickable
// Improvements: edge damping, configurable device sensitivity
Flickable {
    id: flick

    property real mouseMultiplier: 0.35      // Mouse wheel sensitivity
    property real touchpadMultiplier: 0.35    // Touchpad sensitivity
    property real momentumDecay: 0.85         // Momentum friction (0-1, higher = less friction)
    property real velocityThreshold: 0.2      // Velocity below which to stop
    property real edgeDamping: 0.3            // How much to slow down at edges (0-1)

    // Internal momentum state
    property real _velocity: 0
    property real _lastTime: 0

    interactive: false  // Disable left-click drag scrolling; wheel/touchpad handled by WheelHandler

    // Smooth scrollbar
    Rectangle {
        id: scrollBar
        parent: flick
        anchors.right: parent.right
        anchors.rightMargin: 2
        y: flick.height > 0 && flick.contentHeight > flick.height
           ? (flick.contentY / flick.contentHeight) * flick.height + 2
           : 0
        width: 3
        height: flick.height > 0 && flick.contentHeight > flick.height
            ? Math.max(20, (flick.height / flick.contentHeight) * flick.height - 4)
            : 0
        radius: 1.5
        color: Qt.rgba(1, 1, 1, 0.15)
        opacity: flick._velocity !== 0 || scrollBarFade.running ? 1 : 0
        visible: flick.contentHeight > flick.height
        z: 999

        Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 16 } }

        Timer {
            id: scrollBarFade
            interval: 800
            onTriggered: scrollBar.opacity = 0
        }
    }

    WheelHandler {
        id: wheelHandler
        orientation: Qt.Vertical
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: function(event) {
            let now = Date.now();
            let dt = now - flick._lastTime;
            flick._lastTime = now;

            // Convert wheel delta to pixels
            let delta = -event.angleDelta.y / 120 * 40 * flick.mouseMultiplier;

            // Accumulate velocity if scrolling in same direction within 150ms
            if (dt < 150 && delta * flick._velocity > 0) {
                flick._velocity = flick._velocity * 0.6 + delta * 0.8;
            } else {
                flick._velocity = delta;
            }

            // Apply immediate scroll with edge damping
            let newY = flick.contentY + delta;
            let maxY = Math.max(0, flick.contentHeight - flick.height);

            // Dampen at edges for rubber-band feel
            if (newY < 0) {
                newY = flick.contentY + delta * flick.edgeDamping;
                flick._velocity *= 0.5;
            } else if (newY > maxY) {
                newY = flick.contentY + delta * flick.edgeDamping;
                flick._velocity *= 0.5;
            }

            flick.contentY = Math.max(0, Math.min(maxY, newY));

            // Start momentum and show scrollbar
            momentumTimer.restart();
            scrollBarFade.restart();
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
            let maxY = Math.max(0, flick.contentHeight - flick.height);

            // Clamp with soft bounce at edges
            if (newY < 0) {
                newY = 0;
                flick._velocity = 0;
                momentumTimer.stop();
            } else if (newY > maxY) {
                newY = maxY;
                flick._velocity = 0;
                momentumTimer.stop();
            }

            flick.contentY = newY;
        }
    }
}
