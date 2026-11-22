import QtQuick

// A segment of the bar that is only there while something is going on,
// such as a rebuild or a recording. It is wiped in when that starts and
// wiped away when it stops.
Row {
    id: passing

    property bool active: false
    property real shown: active ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    visible: shown > 0
    layer.enabled: shown < 1
    layer.effect: DitherFade {
        amount: passing.shown
        spread: Theme.wipeFront
    }
}
