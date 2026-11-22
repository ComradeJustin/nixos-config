import QtQuick

// A terminal-style panel: a border of box-drawing characters with rounded
// corners, a title in small capitals set into the top edge and an optional
// line of hints set into the bottom edge. Sizes are in character cells. It
// casts a halftone shadow to the right and below.
//
// It appears and disappears the same way everything in the shell does: a
// dithered front wipes across it from the left, shadow included, and wipes
// back to take it away.
Item {
    id: box

    // Outer width in cells. `rows` counts the content rows, not the border.
    property int columns: 40
    property int rows: 1
    property string title: ""
    property string footer: ""
    property color titleColor: Theme.ink
    // How much of the panel is showing, from 0 to 1.
    property real shown: 1
    default property alias content: inner.data

    // The inside width in cells: the border and one space of padding on each side are taken off.
    readonly property int contentColumns: columns - 4
    readonly property int panelWidth: columns * Theme.cellWidth
    readonly property int panelHeight: (rows + 2) * Theme.cellHeight

    // The panel sits at the top left; the extra is room for the shadow.
    implicitWidth: panelWidth + Theme.shadowOffset
    implicitHeight: panelHeight + Theme.shadowOffset

    // Drawn through the dither only while it is changing.
    layer.enabled: shown < 1
    layer.effect: DitherFade {
        amount: box.shown
        spread: Theme.wipeFront
    }

    // An edge with a gap left for a word set into it, e.g. "╭─        ─────╮".
    function edge(left: string, right: string, word: string): string {
        if (word === "")
            return left + "─".repeat(box.columns - 2) + right;
        return left + "─" + " ".repeat(word.length + 2) + "─".repeat(box.columns - word.length - 5) + right;
    }

    // The shadow: the panel's shape again, offset, with every other dot left out.
    Rectangle {
        x: Theme.shadowOffset
        y: Theme.shadowOffset
        width: box.panelWidth
        height: box.panelHeight
        color: Theme.shadow
        layer.enabled: true
        layer.effect: DitherFade {
            amount: 0.5
        }
    }

    Rectangle {
        width: box.panelWidth
        height: box.panelHeight
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
        color: box.titleColor
        smallCaps: true
    }

    // Left and right edges: one "│" per row.
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
