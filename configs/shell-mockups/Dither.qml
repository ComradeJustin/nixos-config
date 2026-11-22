import QtQuick

// A fine checkerboard, the screen version of a printed halftone. The
// reference uses it for barcodes and caption markers; here it fills the
// empty part of level bars and marks the edge of a notification.
Canvas {
    id: root

    property color color: Theme.rule
    // Size of one square of the pattern, in pixels.
    property int cell: 2

    onColorChanged: requestPaint()

    onPaint: {
        const context = getContext("2d");
        context.clearRect(0, 0, width, height);
        context.fillStyle = root.color;
        for (let row = 0; row * root.cell < height; row++) {
            for (let column = row % 2; column * root.cell < width; column += 2)
                context.fillRect(column * root.cell, row * root.cell, root.cell, root.cell);
        }
    }
}
