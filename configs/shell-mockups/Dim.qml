import QtQuick

// The dimming behind the ring, in two layers. A veil darkens everything
// behind, so the ring stays readable over a light window. Over it lies a
// screen of coarse dither dots in the background colour, so what is behind
// shows faintly in the gaps between the dots.
//
// It does not fade: both layers dither in from a sparse scatter of dots,
// and out the same way.
Item {
    id: dim

    // 0 = nothing, 1 = fully dimmed.
    property real level: 0
    // How dark the veil is, from 0 to 1.
    property real veil: 0.8
    // How much of the screen the dots cover when fully dimmed.
    property real cover: 0.75
    // Size of one dot, in pixels. Twice the size used everywhere else.
    property real dotSize: 4

    anchors.fill: parent
    visible: level > 0

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.slab.r, Theme.slab.g, Theme.slab.b, dim.veil)
        // Drawn through the dither only while it is changing.
        layer.enabled: dim.level < 1
        layer.effect: DitherFade {
            amount: dim.level
            dotSize: dim.dotSize
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.slab
        layer.enabled: true
        layer.effect: DitherFade {
            amount: dim.level * dim.cover
            dotSize: dim.dotSize
        }
    }
}
