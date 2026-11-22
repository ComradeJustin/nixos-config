import QtQuick

// A terminal-style panel: a border of box-drawing characters with rounded
// corners, a title set into the top edge and an optional line of hints set
// into the bottom edge. Sizes are in character cells.
//
// It is printed one line at a time and erased the same way in reverse.
// `reveal` runs from 0 (nothing) to 1 (everything): first the top edge, then
// each row with the bottom edge moving down under it.
Item {
    id: box

    // Outer width in cells. `rows` counts the content rows, not the border.
    property int columns: 40
    property int rows: 1
    property string title: ""
    property string footer: ""
    // How much of the panel has been printed, from 0 to 1.
    property real reveal: 1
    default property alias content: inner.data

    // The inside width in cells: the border and one space of padding on each side are taken off.
    readonly property int contentColumns: columns - 4
    // Every line of the panel, counting the two edges.
    readonly property int lineCount: rows + 2
    // Whole lines only, so the panel never shows part of one.
    readonly property int shownLines: Math.round(Math.max(0, Math.min(1, reveal)) * lineCount)
    // The bottom edge is the second line to appear; rows fill in above it after that.
    readonly property int shownRows: Math.max(0, shownLines - 2)
    readonly property bool fullyShown: shownLines === lineCount

    implicitWidth: columns * Theme.cellWidth
    implicitHeight: lineCount * Theme.cellHeight
    width: implicitWidth
    height: shownLines * Theme.cellHeight

    // An edge with a gap left for a word set into it, e.g. "╭─        ─────╮".
    function edge(left: string, right: string, word: string): string {
        if (word === "")
            return left + "─".repeat(box.columns - 2) + right;
        return left + "─" + " ".repeat(word.length + 2) + "─".repeat(box.columns - word.length - 5) + right;
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.slab
    }

    // Top edge, with the title in its gap. The first line to be printed.
    Label {
        visible: box.shownLines >= 1
        text: box.edge("╭", "╮", box.title)
        color: Theme.line
    }

    Label {
        x: 3 * Theme.cellWidth
        visible: box.shownLines >= 1
        text: box.title
        color: Theme.ink
    }

    // Left and right edges: one "│" per printed row.
    Label {
        y: Theme.cellHeight
        visible: box.shownRows > 0
        text: Array(box.shownRows).fill("│").join("\n")
        color: Theme.line
    }

    Label {
        x: (box.columns - 1) * Theme.cellWidth
        y: Theme.cellHeight
        visible: box.shownRows > 0
        text: Array(box.shownRows).fill("│").join("\n")
        color: Theme.line
    }

    // Bottom edge, under the last printed row. The hints appear once the panel is complete.
    Label {
        y: (box.shownRows + 1) * Theme.cellHeight
        visible: box.shownLines >= 2
        text: box.edge("╰", "╯", box.fullyShown ? box.footer : "")
        color: Theme.line
    }

    Label {
        x: 3 * Theme.cellWidth
        y: (box.shownRows + 1) * Theme.cellHeight
        visible: box.fullyShown
        text: box.footer
        color: Theme.inkDim
    }

    // The content, cut off at the last printed row.
    Item {
        id: inner

        x: 2 * Theme.cellWidth
        y: Theme.cellHeight
        width: box.contentColumns * Theme.cellWidth
        height: box.shownRows * Theme.cellHeight
        clip: true
    }
}
