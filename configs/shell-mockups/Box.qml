import QtQuick

// A terminal-style panel: a border of box-drawing characters with rounded
// corners, a title set into the top edge and an optional line of hints set
// into the bottom edge. Sizes are in character cells.
Item {
    id: box

    // Outer size in cells. `rows` counts the content rows, not the border.
    property int columns: 40
    property int rows: 1
    property string title: ""
    property string footer: ""
    default property alias content: inner.data

    // The inside width in cells: the border and one space of padding on each side are taken off.
    readonly property int contentColumns: columns - 4

    implicitWidth: columns * Theme.cellWidth
    implicitHeight: (rows + 2) * Theme.cellHeight

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

    // Left and right edges: one "│" per content row.
    Label {
        y: Theme.cellHeight
        text: Array(box.rows).fill("│").join("\n")
        color: Theme.line
    }

    Label {
        x: (box.columns - 1) * Theme.cellWidth
        y: Theme.cellHeight
        text: Array(box.rows).fill("│").join("\n")
        color: Theme.line
    }

    // Bottom edge, with the hints in its gap.
    Label {
        y: (box.rows + 1) * Theme.cellHeight
        text: box.edge("╰", "╯", box.footer)
        color: Theme.line
    }

    Label {
        x: 3 * Theme.cellWidth
        y: (box.rows + 1) * Theme.cellHeight
        text: box.footer
        color: Theme.inkDim
    }

    Item {
        id: inner

        x: 2 * Theme.cellWidth
        y: Theme.cellHeight
        width: box.contentColumns * Theme.cellWidth
        height: box.rows * Theme.cellHeight
    }
}
