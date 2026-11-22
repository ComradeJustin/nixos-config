import QtQuick

// A level drawn the terminal way: full blocks for the filled part, light
// shade for the rest. The last filled cell is one of the font's eighth-wide
// blocks, so the bar moves in eighths of a cell rather than whole cells.
// Used for volume, brightness, battery and signal.
Row {
    id: root

    // How full the bar is, from 0 to 1.
    property real level: 0
    // Width of the bar in character cells.
    property int cells: 10
    property color fillColor: Theme.accent
    property color emptyColor: Theme.line

    // Blocks one eighth to seven eighths of a cell wide, narrowest first.
    readonly property string partBlocks: "▏▎▍▌▋▊▉"
    readonly property int filledEighths: Math.round(Math.max(0, Math.min(1, level)) * cells * 8)
    readonly property int fullCells: Math.floor(filledEighths / 8)
    readonly property int extraEighths: filledEighths % 8
    readonly property int usedCells: fullCells + (extraEighths > 0 ? 1 : 0)

    Label {
        text: "█".repeat(root.fullCells) + (root.extraEighths > 0 ? root.partBlocks[root.extraEighths - 1] : "")
        color: root.fillColor
    }

    Label {
        text: "░".repeat(root.cells - root.usedCells)
        color: root.emptyColor
    }
}
