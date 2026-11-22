import QtQuick

// A level drawn as a framed progress bar: an outline with a solid fill
// inside it, one cell per segment. Used for volume, brightness, battery and
// signal.
//
// It is made of the font's six progress-bar characters: a left end, a
// middle and a right end, each in an empty and a filled version.
Row {
    id: root

    // How full the bar is, from 0 to 1.
    property real level: 0
    // Width of the bar in character cells.
    property int cells: 10
    property color fillColor: Theme.accent
    property color emptyColor: Theme.line

    readonly property int filledCells: Math.round(Math.max(0, Math.min(1, level)) * cells)

    // The filled or the empty part of the bar, as text. The first and last
    // cells of the whole bar are the end pieces.
    function part(filled: bool): string {
        const leftEnd = filled ? "\uee03" : "\uee00";
        const middle = filled ? "\uee04" : "\uee01";
        const rightEnd = filled ? "\uee05" : "\uee02";
        const first = filled ? 0 : root.filledCells;
        const last = filled ? root.filledCells : root.cells;
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
        text: root.part(true)
        color: root.fillColor
    }

    Label {
        text: root.part(false)
        color: root.emptyColor
    }
}
