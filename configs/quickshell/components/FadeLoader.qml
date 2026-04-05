import QtQuick
import ".." as Root

// Loader that fades in/out and auto-deactivates when invisible.
// More efficient than keeping hidden components alive.
//
// Usage:
//   FadeLoader {
//       shown: someCondition
//       sourceComponent: HeavyWidget { ... }
//   }
Loader {
    id: root
    property bool shown: true

    opacity: shown ? 1 : 0
    visible: opacity > 0
    active: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic }
    }
}
