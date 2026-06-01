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
    property int stagger: 60        // ms between successive items
    property int baseDelay: 0       // ms before the whole cascade starts
    property bool shown: true       // bind to the panel's open state
    property real slideFrom: 14     // px below the resting position to start at

    default property alias content: _c.data
    implicitHeight: _c.implicitHeight   // width is set by the caller

    property bool _armed: false     // gates the Behaviors (off = snap instantly)
    property bool _revealed: false

    function _play() {
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
        opacity: root._revealed ? 1 : 0
        y: root._revealed ? 0 : root.slideFrom
        Behavior on opacity {
            enabled: root._armed
            NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: root._armed
            NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic }
        }
    }
}
