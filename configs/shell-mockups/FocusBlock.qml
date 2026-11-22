import QtQuick

// The reverse-video block behind whatever has focus: a workspace, a ring
// name, the selected line of a panel. Its left edge is hard; its right edge
// trails off through the font's shade characters.
Item {
    id: block

    // Width of the solid part, in cells.
    property int solidCells: 1
    // The shade characters that follow it, densest first.
    property string tail: "▓▒░"
    // 2 for a block behind double-size text.
    property int scaleFactor: 1
    property color color: Theme.accent

    readonly property int solidWidth: solidCells * Theme.cellWidth * scaleFactor

    width: solidWidth + tail.length * Theme.cellWidth * scaleFactor
    height: Theme.cellHeight * scaleFactor

    Rectangle {
        width: block.solidWidth
        height: block.height
        color: block.color
    }

    Label {
        x: block.solidWidth
        text: block.tail
        scaleFactor: block.scaleFactor
        color: block.color
    }
}
