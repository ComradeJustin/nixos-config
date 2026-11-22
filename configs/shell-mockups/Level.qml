import QtQuick

// A level drawn as a framed progress bar: an outline with a solid fill
// inside it. Used for volume, brightness, battery and signal.
//
// The outline is the font's three empty progress-bar characters: a left
// end, a middle and a right end. The fill is drawn inside it, so it can
// stop at any pixel and the outline stays one colour.
Item {
    id: root

    // How full the bar is, from 0 to 1.
    property real level: 0
    // Width of the bar in character cells. Two at least.
    property int cells: 10
    property color fillColor: Theme.accent
    property color frameColor: Theme.line

    // Where the inside of the outline is, measured on the font's
    // characters at 11 px: the fill starts 4 px in from the left, stops
    // 2 px short of the right, and covers rows 3 to 10 of the 14.
    readonly property int fillX: 4 * Theme.scale
    readonly property int fillY: 3 * Theme.scale
    readonly property int fillHeight: 8 * Theme.scale
    readonly property int fillRoom: width - 6 * Theme.scale

    width: cells * Theme.cellWidth
    height: Theme.cellHeight

    Label {
        text: "\uee00" + "\uee01".repeat(root.cells - 2) + "\uee02"
        color: root.frameColor
    }

    Rectangle {
        x: root.fillX
        y: root.fillY
        width: Math.round(Math.max(0, Math.min(1, root.level)) * root.fillRoom)
        height: root.fillHeight
        color: root.fillColor
    }
}
