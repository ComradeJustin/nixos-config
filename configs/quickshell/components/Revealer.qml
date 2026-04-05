import QtQuick
import ".." as Root

// GTK-style reveal animation: smoothly shows/hides content by animating
// the clip dimensions. Use `reveal: true/false` to toggle.
//
// Usage:
//   Revealer {
//       reveal: showDetails
//       Column { Text { text: "Details here" } }
//   }
Item {
    id: revealer

    property bool reveal: false
    property bool vertical: true   // true = height reveal, false = width reveal
    property int duration: Root.Theme.anim.moveDuration
    property int easing: Root.Theme.anim.moveEasing

    default property alias content: container.data

    clip: true

    // In vertical mode, width follows parent; height animates
    // In horizontal mode, height follows parent; width animates
    implicitWidth: vertical ? container.implicitWidth : (reveal ? container.implicitWidth : 0)
    implicitHeight: vertical ? (reveal ? container.implicitHeight : 0) : container.implicitHeight

    Behavior on implicitWidth {
        enabled: !vertical
        NumberAnimation { duration: revealer.duration; easing.type: revealer.easing }
    }

    Behavior on implicitHeight {
        enabled: vertical
        NumberAnimation { duration: revealer.duration; easing.type: revealer.easing }
    }

    // Content is positioned at top-left; clipping handles the reveal
    Item {
        id: container
        width: vertical ? revealer.width : implicitWidth
        height: vertical ? implicitHeight : revealer.height
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height

        // Fade content with the reveal
        opacity: revealer.reveal ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: revealer.duration * 0.6; easing.type: Easing.OutCubic }
        }
    }
}
