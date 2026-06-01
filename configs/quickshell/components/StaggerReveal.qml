import QtQuick
import ".." as Root

// Staggered entry animation (noctalia-style). Wraps a single child; on `shown`
// becoming true the child fades + slides up into place, offset by
// `baseDelay + staggerIndex * stagger` ms, producing a cascade across a Repeater.
//
// Items only ever animate IN — on (re)open they snap to the hidden state
// instantly (no animation), then reveal, so there's never a startup "animation
// storm" or an animate-out flicker (the #3 guard, via the `_armed` gate).
//
// Motion is fade + vertical slide only (no scale): a card never overshoots its
// own slot, so it can't briefly overlap its neighbours inside a tight Column —
// which is what made an earlier scale/OutBack version read as "buggy". Layout is
// untouched (the slot reserves full height up front; only opacity/y animate).
//
// Usage (inside a Repeater delegate):
//   StaggerReveal { width: col.width; staggerIndex: index; shown: panel.showing
//       Loader { width: parent.width; sourceComponent: ... } }
Item {
    id: root

    property int staggerIndex: 0    // this item's position in the cascade
    property int stagger: 80        // ms between successive items
    property int baseDelay: 0       // ms before the whole cascade starts
    property bool shown: true       // bind to the panel's open state
    // Master on/off, bound to the global config flag. When false the content is
    // shown instantly with no fade/slide (per-instance override still possible).
    property bool animationsEnabled: Root.Config.appearance.revealAnimations
    property real slideFrom: 28     // px below the resting position to start at
    // Fade and slide are deliberately decoupled. The opacity uses a gentle
    // ease-in-out so the card doesn't pop in — a decelerating "Out" curve front-
    // loads the fade (most of it happens in the first ~80ms) which reads as
    // sudden. The slide is a longer, softly decelerating drift so the motion is
    // clearly perceptible but never abrupt.
    property int fadeDuration: 400
    property int slideDuration: 470

    default property alias content: _c.data
    implicitHeight: _c.implicitHeight   // width is set by the caller in a Column;
    implicitWidth: _c.implicitWidth     // implicitWidth lets it sit in a Row/Grid

    property bool _armed: false     // gates the Behaviors (off = snap instantly)
    property bool _revealed: false

    function _play() {
        if (!animationsEnabled) {   // toggle off → reveal instantly, no animation
            _armed = false;
            _revealed = true;
            return;
        }
        _armed = false;             // snap to hidden with no animation
        _revealed = false;
        _delay.restart();
    }
    onShownChanged: if (shown) _play();
    Component.onCompleted: if (shown) _play();

    Timer {
        id: _delay
        interval: Math.max(0, root.baseDelay + root.staggerIndex * root.stagger)
        onTriggered: { root._armed = true; root._revealed = true; }
    }

    Item {
        id: _c
        width: root.width
        implicitHeight: childrenRect.height
        implicitWidth: childrenRect.width
        opacity: root._revealed ? 1 : 0
        y: root._revealed ? 0 : root.slideFrom
        Behavior on opacity {
            enabled: root._armed
            NumberAnimation { duration: root.fadeDuration; easing.type: Easing.InOutQuad }
        }
        Behavior on y {
            enabled: root._armed
            NumberAnimation { duration: root.slideDuration; easing.type: Easing.OutCubic }
        }
    }
}
