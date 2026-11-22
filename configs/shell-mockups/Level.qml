import QtQuick

// A level drawn as a framed progress bar: an outline with a solid fill
// inside it, one cell per segment. Used for volume, brightness, battery and
// signal.
//
// It is made of the font's six progress-bar characters: a left end, a
// middle and a right end, each in an empty and a filled version. The font
// has no half-filled piece, so half a cell is shown as a filled piece in a
// muted colour: the bar moves in half cells.
Row {
    id: root

    // How full the bar is, from 0 to 1.
    property real level: 0
    // Width of the bar in character cells.
    property int cells: 10
    property color fillColor: Theme.accent
    property color emptyColor: Theme.line
    // Half way between the fill and the background.
    readonly property color halfColor: Qt.rgba((fillColor.r + Theme.slab.r) / 2, (fillColor.g + Theme.slab.g) / 2, (fillColor.b + Theme.slab.b) / 2, 1)

    readonly property int filledHalves: Math.round(Math.max(0, Math.min(1, level)) * cells * 2)
    readonly property int fullCells: Math.floor(filledHalves / 2)
    // The cell after the full ones is the half-filled one, if there is one.
    readonly property int halfCells: filledHalves % 2

    // The cells from `first` up to but not including `last`, as text, all
    // filled or all empty. The first and last cells of the whole bar are
    // the end pieces.
    function part(first: int, last: int, filled: bool): string {
        const leftEnd = filled ? "\uee03" : "\uee00";
        const middle = filled ? "\uee04" : "\uee01";
        const rightEnd = filled ? "\uee05" : "\uee02";
        let text = "";
        for (let cell = first; cell < last; cell++) {
            if (cell === 0)
                text += leftEnd;
            else if (cell === root.cells - 1)
                text += rightEnd;
            else
                text += middle;
        }
        return text;
    }

    Label {
        text: root.part(0, root.fullCells, true)
        color: root.fillColor
    }

    Label {
        text: root.part(root.fullCells, root.fullCells + root.halfCells, true)
        color: root.halfColor
    }

    Label {
        text: root.part(root.fullCells + root.halfCells, root.cells, false)
        color: root.emptyColor
    }
}
