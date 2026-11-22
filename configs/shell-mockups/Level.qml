import QtQuick

// A level drawn the terminal way: full blocks for the filled part, light
// shade for the rest. Used for volume, brightness, battery and signal.
Row {
    id: root

    // How full the bar is, from 0 to 1.
    property real level: 0
    // Width of the bar in character cells.
    property int cells: 10
    property color fillColor: Theme.accent
    property color emptyColor: Theme.line

    readonly property int filledCells: Math.round(Math.max(0, Math.min(1, level)) * cells)

    Label {
        text: "█".repeat(root.filledCells)
        color: root.fillColor
    }

    Label {
        text: "░".repeat(root.cells - root.filledCells)
        color: root.emptyColor
    }
}
