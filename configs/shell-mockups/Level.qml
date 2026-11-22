import QtQuick

// A level drawn as a framed progress bar: an outline with a solid fill
// inside it. Used for volume, brightness, battery and signal.
//
// It is made of Pixel Code's six progress-bar characters: a left end, a
// middle and a right end, each in an empty and a filled version. Those are
// 6 px wide where a cell is 7 px, so the bar is as many of them as fit in
// `cells` cells, with the few pixels left over at the right.
Item {
    id: root

    // How full the bar is, from 0 to 1.
    property real level: 0
    // Width of the bar in character cells.
    property int cells: 10
    property color fillColor: Theme.accent
    property color emptyColor: Theme.line

    readonly property int segments: Math.floor(cells * Theme.cellWidth / Theme.levelSegmentWidth)
    readonly property int filledSegments: Math.round(Math.max(0, Math.min(1, level)) * segments)

    // The filled or the empty part of the bar, as text. The first and last
    // segments of the whole bar are the end pieces.
    function part(filled: bool): string {
        const leftEnd = filled ? "\uee03" : "\uee00";
        const middle = filled ? "\uee04" : "\uee01";
        const rightEnd = filled ? "\uee05" : "\uee02";
        const first = filled ? 0 : root.filledSegments;
        const last = filled ? root.filledSegments : root.segments;
        let text = "";
        for (let segment = first; segment < last; segment++) {
            if (segment === 0)
                text += leftEnd;
            else if (segment === root.segments - 1)
                text += rightEnd;
            else
                text += middle;
        }
        return text;
    }

    width: cells * Theme.cellWidth
    height: Theme.cellHeight

    Row {
        // Centred in the row of text beside it.
        y: (Theme.cellHeight - Theme.levelSegmentHeight) / 2

        Label {
            text: root.part(true)
            color: root.fillColor
            font.family: Theme.levelFontFamily
            font.pixelSize: Theme.levelFontSize
        }

        Label {
            text: root.part(false)
            color: root.emptyColor
            font.family: Theme.levelFontFamily
            font.pixelSize: Theme.levelFontSize
        }
    }
}
