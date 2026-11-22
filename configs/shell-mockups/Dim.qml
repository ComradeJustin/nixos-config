import QtQuick

// The dimming behind the ring. It does not fade: it dithers in, from a
// sparse scatter of dark pixels to a dense one to solid, and out the same
// way. Drawn at half size and scaled up without smoothing, so each dither
// dot is two pixels square, like the halftone the font's own site uses.
Canvas {
    id: dim

    // 0 = nothing, 1 = fully dimmed.
    property real level: 0
    // How dark fully dimmed is.
    property real strength: 0.9

    // Qt's ordered-dither fills, sparsest first, then solid.
    readonly property var densities: [Qt.Dense7Pattern, Qt.Dense6Pattern, Qt.Dense5Pattern, Qt.Dense4Pattern, Qt.Dense3Pattern, Qt.Dense2Pattern, Qt.Dense1Pattern, Qt.SolidPattern]
    // Which of them is showing: 0 for none, then 1 to 8.
    readonly property int step: Math.round(Math.max(0, Math.min(1, level)) * densities.length)

    width: Math.ceil(parent.width / 2)
    height: Math.ceil(parent.height / 2)
    scale: 2
    transformOrigin: Item.TopLeft
    smooth: false
    visible: step > 0

    onStepChanged: requestPaint()

    onPaint: {
        const context = getContext("2d");
        context.clearRect(0, 0, width, height);
        if (dim.step === 0)
            return;
        const dark = Qt.rgba(Theme.slab.r, Theme.slab.g, Theme.slab.b, dim.strength);
        context.fillStyle = context.createPattern(dark, dim.densities[dim.step - 1]);
        context.fillRect(0, 0, width, height);
    }
}
