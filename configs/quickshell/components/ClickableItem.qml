import QtQuick
import ".." as Root

// Foundational interactive surface — the base for buttons, toggles, and list rows.
//
// Provides consistent, token-animated hover / press / selected feedback that
// COMPOSITES (a selected row still shows a hover overlay), "release-while-
// hovered" click semantics, and opt-in press-scale + Material ripple.
//
// Build specialised controls on top of this instead of hand-rolling a
// Rectangle + hoverEnabled MouseArea + containsMouse colour binding.
//
// Usage:
//   ClickableItem { onClicked: doThing(); Text { anchors.centerIn: parent; text: "Hi" } }
//   ClickableItem { ripple: true; pressScale: true; selected: active; onClicked: ... }
Rectangle {
    id: root

    // ── State ──
    property bool interactive: true
    property bool selected: false
    readonly property alias hovered: _mouse.containsMouse
    readonly property alias pressed: _mouse.pressed

    // ── Surface colours (token-driven; override per use) ──
    property color baseColor: "transparent"
    property color hoverColor: Root.Theme.layer1Hover
    property color pressedColor: Root.Theme.layerActive
    property color selectedColor: Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.12)

    // ── Feedback options ──
    property bool pressScale: false
    property real pressScaleAmount: 0.95
    property bool ripple: false
    property color rippleColor: Root.Theme.accentPrimary
    property real rippleOpacity: 0.18

    // ── Interaction config ──
    property int buttons: Qt.LeftButton | Qt.RightButton

    // ── Signals ──
    signal clicked()
    signal rightClicked()
    signal pressAndHold()

    // Children are placed above the ripple, below the (transparent) hit area.
    default property alias content: _content.data

    radius: Root.Theme.radiusSmall

    // Resting surface: selected tint vs base, animated.
    color: selected ? selectedColor : baseColor
    Behavior on color {
        ColorAnimation { duration: Root.Theme.anim.microDuration; easing.type: Root.Theme.anim.microEasing }
    }

    scale: (pressScale && _mouse.pressed) ? pressScaleAmount : 1.0
    Behavior on scale {
        NumberAnimation { duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic }
    }

    // ── Hover / press state overlay (composites over the resting surface) ──
    Rectangle {
        anchors.fill: parent
        z: 0
        radius: root.radius
        color: root.pressed ? root.pressedColor : root.hoverColor
        opacity: (root.interactive && (root.hovered || root.pressed)) ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Root.Theme.anim.microDuration; easing.type: Root.Theme.anim.microEasing }
        }
    }

    // ── Ripple layer (opt-in, behind content) ──
    Item {
        anchors.fill: parent
        z: 0
        clip: true
        visible: root.ripple

        Rectangle {
            id: _ripple
            property real cx: 0
            property real cy: 0
            property real maxR: 0
            x: cx - width / 2
            y: cy - height / 2
            width: 0
            height: width
            radius: width / 2
            color: root.rippleColor
            opacity: 0
            ParallelAnimation {
                id: _rippleAnim
                NumberAnimation {
                    target: _ripple; property: "width"
                    from: 0; to: _ripple.maxR * 2
                    duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic
                }
                SequentialAnimation {
                    NumberAnimation { target: _ripple; property: "opacity"; to: root.rippleOpacity; duration: Root.Theme.anim.exitDuration }
                    NumberAnimation { target: _ripple; property: "opacity"; to: 0; duration: Root.Theme.anim.exitDuration; easing.type: Easing.InCubic }
                }
            }
        }
    }

    // ── Content layer ──
    Item {
        id: _content
        anchors.fill: parent
        z: 1
    }

    // ── Hit area (top) ──
    MouseArea {
        id: _mouse
        anchors.fill: parent
        z: 2
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: root.buttons

        onPressed: function (mouse) {
            if (root.ripple && mouse.button === Qt.LeftButton) {
                const dx1 = mouse.x, dx2 = root.width - mouse.x;
                const dy1 = mouse.y, dy2 = root.height - mouse.y;
                _ripple.maxR = Math.sqrt(Math.max(
                    dx1 * dx1 + dy1 * dy1, dx1 * dx1 + dy2 * dy2,
                    dx2 * dx2 + dy1 * dy1, dx2 * dx2 + dy2 * dy2));
                _ripple.cx = mouse.x;
                _ripple.cy = mouse.y;
                _ripple.width = 0;
                _ripple.opacity = 0;
                _rippleAnim.restart();
            }
        }
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
        onPressAndHold: root.pressAndHold()
    }
}
