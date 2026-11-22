import QtQuick

// A small history graph drawn in braille characters. Each cell holds two
// columns of four dots, so the graph is two samples wide per cell and four
// steps tall. Used for CPU load, memory and network traffic.
//
// A taller graph is several of these, one above the other, each given the
// same samples and its own band of the scale (`low` to `high`): with three
// rows the top one draws 2/3 to 1, the middle one 1/3 to 2/3, and the
// bottom one 0 to 1/3.
Label {
    id: graph

    // Samples from 0 to 1, oldest first. Missing ones count as 0.
    property var samples: []
    // Width of the graph in character cells.
    property int cells: 10
    // The band of the scale this row draws.
    property real low: 0
    property real high: 1

    // A braille character's code is 0x2800 plus one bit per raised dot.
    // These are the bits of the dots in a cell's left and right column,
    // from the bottom dot up.
    readonly property var leftDots: [0x40, 0x04, 0x02, 0x01]
    readonly property var rightDots: [0x80, 0x20, 0x10, 0x08]

    // The dots of one column: up to four of them, filled from the bottom,
    // for as far as the sample reaches into this row's band. On the row
    // that starts at nothing the bottom dot always shows, so an idle graph
    // is a flat line.
    function columnBits(sampleIndex: int, dots: var): int {
        const sample = sampleIndex < graph.samples.length ? graph.samples[sampleIndex] : 0;
        const reach = Math.max(0, Math.min(1, (sample - graph.low) / (graph.high - graph.low)));
        const height = Math.max(graph.low === 0 ? 1 : 0, Math.round(reach * 4));
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
