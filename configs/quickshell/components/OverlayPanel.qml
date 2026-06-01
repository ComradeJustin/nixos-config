import Quickshell
import Quickshell.Wayland
import QtQuick
import ".." as Root

// Fullscreen modal overlay base — scrim + centered content + scale/fade reveal.
//
// Consolidates the layer-shell boilerplate, the show → animate → hide lifecycle,
// an optional dimming scrim with click-to-dismiss, and ESC dismissal that the
// fullscreen modals (power menu, spotlight, settings, monitor dialog) all
// re-declared by hand. Consumers set `namespace` and drop a centered card into
// the default content slot.
//
// Keyboard: content lives inside a FocusScope that takes focus while open, so a
// consumer can mark a child `focus: true` (e.g. a search field, or a key-nav
// Item) and it receives key events; ESC bubbles up here as a dismissal fallback.
//
// Usage:
//   OverlayPanel {
//       id: panel
//       namespace: "quickshell-foo"
//       onAboutToOpen: refresh()
//       Rectangle { anchors.centerIn: parent; /* your card */ }
//   }
//   panel.open() / panel.close() / panel.toggle()
PanelWindow {
    id: root

    // ── Public config ──
    property string namespace: "quickshell-overlay"
    property bool showScrim: true
    property real scrimOpacity: 0.45
    property color scrimColor: "black"
    property bool dismissOnScrimClick: true
    property bool dismissOnEscape: true

    // ── State / API ──
    property bool isOpen: false
    default property alias content: _content.data

    // Fired before the panel becomes visible — use it to refresh content.
    // For "finished opening/closing" hooks, bind to onIsOpenChanged.
    signal aboutToOpen()

    function open() {
        if (isOpen)
            return;
        aboutToOpen();
        visible = true;
        isOpen = true;
    }
    function close() {
        if (!isOpen)
            return;
        isOpen = false;
        // `visible` is flipped false once the fade-out completes (below),
        // so the panel keeps painting during its exit animation.
    }
    function toggle() {
        if (isOpen)
            close();
        else
            open();
    }

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: root.namespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // ── Scrim (dimmer + click-to-dismiss) ──
    Rectangle {
        anchors.fill: parent
        visible: root.showScrim
        color: root.scrimColor
        opacity: root.isOpen ? root.scrimOpacity : 0
        Behavior on opacity {
            NumberAnimation {
                duration: root.isOpen ? Root.Theme.anim.enterDuration : Root.Theme.anim.exitDuration
                easing.type: Easing.OutCubic
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.dismissOnScrimClick
            onClicked: root.close()
        }
    }

    // ── Focus + content (scale + fade reveal around screen centre) ──
    FocusScope {
        anchors.fill: parent
        focus: root.isOpen
        Keys.onEscapePressed: {
            if (root.dismissOnEscape)
                root.close();
        }

        Item {
            id: _contentWrap
            anchors.fill: parent
            opacity: root.isOpen ? 1 : 0
            scale: root.isOpen ? 1 : 0.92

            Behavior on opacity {
                NumberAnimation {
                    duration: root.isOpen ? Root.Theme.anim.enterDuration : Root.Theme.anim.exitDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.isOpen ? Root.Theme.anim.bounceDuration : Root.Theme.anim.exitDuration
                    easing.type: root.isOpen ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: 0.4
                }
            }

            // Stop painting only after the exit fade finishes.
            onOpacityChanged: {
                if (!root.isOpen && opacity <= 0.01)
                    root.visible = false;
            }

            Item {
                id: _content
                anchors.fill: parent
            }
        }
    }
}
