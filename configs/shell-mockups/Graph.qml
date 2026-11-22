import QtQuick

// A small history graph drawn in braille characters. Each cell holds two
// columns of four dots, so the graph is two samples wide per cell and four
// steps tall. Used for CPU load and network traffic.
Label {
    id: graph

    // Samples from 0 to 1, oldest first. Missing ones count as 0.
    property var samples: []
    // Width of the graph in character cells.
    property int cells: 10

    // A braille character's code is 0x2800 plus one bit per raised dot.
    // These are the bits of the dots in a cell's left and right column,
    // from the bottom dot up.
    readonly property var leftDots: [0x40, 0x04, 0x02, 0x01]
    readonly property var rightDots: [0x80, 0x20, 0x10, 0x08]

    // The dots of one column: one to four of them, filled from the bottom.
    // The bottom dot always shows, so an idle graph is a flat line.
    function columnBits(sampleIndex: int, dots: var): int {
        const sample = sampleIndex < graph.samples.length ? graph.samples[sampleIndex] : 0;
        const height = 1 + Math.round(Math.max(0, Math.min(1, sample)) * 3);
        let bits = 0;
        for (let dot = 0; dot < height; dot++)
            bits += dots[dot];
        return bits;
    }

    function graphText(): string {
        let text = "";
        for (let cell = 0; cell < graph.cells; cell++) {
            const bits = graph.columnBits(2 * cell, graph.leftDots) + graph.columnBits(2 * cell + 1, graph.rightDots);
            text += String.fromCharCode(0x2800 + bits);
        }
        return text;
    }

    text: graphText()
    color: Theme.accent
}
