import QtQuick

// Fades a whole item in and out as a 1-bit dither: the item thins out into
// a regular scatter of dots and then to nothing. No pixel is ever half
// transparent. Use it as an item's `layer.effect`.
//
// The pattern is worked out per pixel on the graphics card (see
// shaders/dither-fade.frag), so it applies to anything: text, a panel, a
// plain colour.
ShaderEffect {
    // The item being faded. Set for us when used as a layer effect.
    property var source
    // 0 = gone, 1 = fully shown.
    property real amount: 1
    // Size of one dither dot, in pixels.
    property real dotSize: Theme.dotSize
    // Width of the dithered front as a share of the item's width. The front
    // runs left to right; the default is so wide that the whole item fades at once.
    property real spread: 1000
    readonly property vector2d size: Qt.vector2d(width, height)

    fragmentShader: Qt.resolvedUrl("shaders/dither-fade.frag.qsb")
}
