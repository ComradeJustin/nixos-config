import QtQuick

// Workspace indicator: one dot per workspace, with the focused one stretched
// into a pill. Sample data only: five workspaces, the second focused, the
// last two empty.
Grid {
    id: root

    // Stack the dots top to bottom (for a side rail) instead of left to right.
    property bool vertical: false
    property int dotSize: 6

    readonly property var sampleWorkspaces: [
        {
            focused: false,
            occupied: true
        },
        {
            focused: true,
            occupied: true
        },
        {
            focused: false,
            occupied: true
        },
        {
            focused: false,
            occupied: false
        },
        {
            focused: false,
            occupied: false
        }
    ]

    rows: vertical ? sampleWorkspaces.length : 1
    columns: vertical ? 1 : sampleWorkspaces.length
    spacing: dotSize
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    Repeater {
        model: root.sampleWorkspaces

        Rectangle {
            required property var modelData

            readonly property int longSide: modelData.focused ? root.dotSize * 3 : root.dotSize

            width: root.vertical ? root.dotSize : longSide
            height: root.vertical ? longSide : root.dotSize
            radius: root.dotSize / 2
            color: modelData.focused ? Theme.accent : (modelData.occupied ? Theme.textDim : Theme.textFaint)
        }
    }
}
