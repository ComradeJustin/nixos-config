import QtQuick

// A segmented level meter, like the LED ladders on audio equipment.
// Used wherever the shell shows an amount: battery, volume, signal.
Row {
    id: root

    // How full the meter is, from 0 to 1.
    property real level: 0
    property int segments: 5
    property int segmentWidth: 3
    property int segmentHeight: 8
    property color litColor: Theme.accent
    property color unlitColor: Theme.stroke

    spacing: 2

    Repeater {
        model: root.segments

        Rectangle {
            required property int index

            width: root.segmentWidth
            height: root.segmentHeight
            radius: 1
            color: index < Math.round(root.level * root.segments) ? root.litColor : root.unlitColor
        }
    }
}
