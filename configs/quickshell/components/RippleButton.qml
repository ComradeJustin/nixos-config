import QtQuick
import ".." as Root

// Material Design ripple effect button.
// Provides visual feedback on click with an expanding circular ripple.
//
// Usage:
//   RippleButton {
//       width: 100; height: 40
//       contentItem: Text { text: "Click me"; anchors.centerIn: parent }
//       onClicked: doSomething()
//   }
Rectangle {
    id: rippleBtn

    property alias contentItem: contentContainer.data
    property color rippleColor: Root.Theme.accentPrimary
    property color hoverColor: Root.Theme.layer1Hover
    property bool toggle: false
    property bool toggled: false
    property real rippleOpacity: 0.2

    signal clicked()
    signal rightClicked()

    radius: Root.Theme.radiusSmall
    color: mouseArea.containsMouse ? hoverColor : "transparent"
    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

    // Ripple container (clipped to button bounds)
    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: ripple
            property real centerX: 0
            property real centerY: 0
            property real maxRadius: 0

            x: centerX - width / 2
            y: centerY - height / 2
            width: 0; height: width
            radius: width / 2
            color: rippleBtn.rippleColor
            opacity: 0

            ParallelAnimation {
                id: rippleAnim
                NumberAnimation {
                    target: ripple; property: "width"
                    from: 0; to: ripple.maxRadius * 2
                    duration: 400; easing.type: Easing.OutCubic
                }
                SequentialAnimation {
                    NumberAnimation {
                        target: ripple; property: "opacity"
                        from: rippleBtn.rippleOpacity; to: rippleBtn.rippleOpacity
                        duration: 200
                    }
                    NumberAnimation {
                        target: ripple; property: "opacity"
                        to: 0; duration: 200; easing.type: Easing.InCubic
                    }
                }
            }
        }
    }

    // Content layer (above ripple)
    Item {
        id: contentContainer
        anchors.fill: parent
        z: 1
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: function(mouse) {
            // Calculate ripple radius from click point to farthest corner
            let dx1 = mouse.x, dx2 = rippleBtn.width - mouse.x;
            let dy1 = mouse.y, dy2 = rippleBtn.height - mouse.y;
            ripple.maxRadius = Math.sqrt(Math.max(
                dx1*dx1 + dy1*dy1, dx1*dx1 + dy2*dy2,
                dx2*dx2 + dy1*dy1, dx2*dx2 + dy2*dy2
            ));
            ripple.centerX = mouse.x;
            ripple.centerY = mouse.y;
            ripple.width = 0;
            ripple.opacity = 0;
            rippleAnim.restart();

            if (mouse.button === Qt.RightButton) {
                rippleBtn.rightClicked();
            } else {
                if (rippleBtn.toggle) rippleBtn.toggled = !rippleBtn.toggled;
                rippleBtn.clicked();
            }
        }
    }
}
