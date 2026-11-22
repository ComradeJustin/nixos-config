import QtQuick

// A part of the bar that answers to the mouse: it can be clicked with
// either button, and the wheel can be turned over it. The pointer becomes a
// hand over it.
Row {
    id: segment

    signal tapped
    signal rightTapped
    // 1 for a turn of the wheel upwards, -1 for one downwards.
    signal wheelTurned(int step)

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: segment.tapped()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: segment.rightTapped()
    }

    WheelHandler {
        onWheel: event => segment.wheelTurned(event.angleDelta.y > 0 ? 1 : -1)
    }
}
