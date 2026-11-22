import QtQuick

// The dimming behind the ring: a screen of coarse dither dots in the
// background colour, with the desktop showing through the gaps between
// them. It does not fade: it dithers in from a sparse scatter of dots to
// its full cover, and out the same way.
Rectangle {
    id: dim

    // 0 = nothing, 1 = fully dimmed.
    property real level: 0
    // How much of the screen the dots cover when fully dimmed.
    property real cover: 0.75
    // Size of one dot, in pixels. Twice the size used everywhere else.
    property real dotSize: 4

    anchors.fill: parent
    visible: level > 0
    color: Theme.slab
    layer.enabled: true
    layer.effect: DitherFade {
        amount: dim.level * dim.cover
        dotSize: dim.dotSize
    }
}
