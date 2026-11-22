import QtQuick

// A part of the bar that answers to the mouse: it can be clicked, and the
// wheel can be turned over it. The pointer becomes a hand over it.
Row {
    id: segment

    signal tapped
    // 1 for a turn of the wheel upwards, -1 for one downwards.
    signal wheelTurned(int step)

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: segment.tapped()
    }

    WheelHandler {
        onWheel: event => segment.wheelTurned(event.angleDelta.y > 0 ? 1 : -1)
    }
}
