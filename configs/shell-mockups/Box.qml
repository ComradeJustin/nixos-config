import QtQuick

// A terminal-style panel: a border of box-drawing characters with rounded
// corners, a title set into the top edge and an optional line of hints set
// into the bottom edge. Sizes are in character cells.
//
// It opens by printing its rows one at a time: `reveal` runs from 0 to 1 and
// the bottom edge moves down a row at a time as it does.
Item {
    id: box

    // Outer width in cells. `rows` counts the content rows, not the border.
    property int columns: 40
    property int rows: 1
    property string title: ""
    property string footer: ""
    // How much of the panel has been printed: 0 = just its two edges, 1 = all rows.
    property real reveal: 1
    default property alias content: inner.data

    // The inside width in cells: the border and one space of padding on each side are taken off.
    readonly property int contentColumns: columns - 4
    // Whole rows only, so the panel never shows part of a line.
    readonly property int shownRows: Math.round(Math.max(0, Math.min(1, reveal)) * rows)
    readonly property bool fullyShown: shownRows === rows

    implicitWidth: columns * Theme.cellWidth
    implicitHeight: (rows + 2) * Theme.cellHeight
    width: implicitWidth
    height: (shownRows + 2) * Theme.cellHeight

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

    // Top edge, with the title in its gap.
    Label {
        text: box.edge("╭", "╮", box.title)
        color: Theme.line
    }

    Label {
        x: 3 * Theme.cellWidth
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
