import QtQuick

// The dithered leading edge of something being typed in or erased by
// widening or narrowing a window onto it (a panel, the bar's line): a band
// of shade characters, one row per line of text, covering what is behind it.
// Text that is typed character by character draws the same edge itself
// (Theme.typedText).
//
// The band covers the last few columns the typing has reached. At the start
// only its front shows, and at the end it slides off past the last column.
Rectangle {
    id: edge

    // How far the typing has got, in columns, counting on past the end
    // (Theme.typedReach), and how many columns there are.
    property int reached: 0
    property int columns: 0
    // How many lines of text the band covers.
    property int lines: 1

    readonly property int bandStart: reached - Theme.typeEdge.length
    readonly property int firstColumn: Math.max(0, bandStart)
    readonly property int lastColumn: Math.min(columns, reached)
    // The part of the edge that falls inside the columns.
    readonly property string shades: Theme.typeEdge.slice(firstColumn - bandStart, lastColumn - bandStart)

    x: firstColumn * Theme.cellWidth
    width: Math.max(0, lastColumn - firstColumn) * Theme.cellWidth
    height: lines * Theme.cellHeight
    visible: width > 0
    color: Theme.slab

    Label {
        text: Array(edge.lines).fill(edge.shades).join("\n")
        color: Theme.accent
    }
}
