import QtQuick

// Draws a picture in two colours, the way the rest of the shell is drawn:
// each dot is either dark or light, picked by comparing the picture's
// brightness there against an ordered dither pattern (see
// shaders/dither-image.frag). Use it as an Image's `layer.effect`.
ShaderEffect {
    // The picture. Set for us when used as a layer effect.
    property var source
    // Size of one dot, in pixels.
    property real dotSize: Theme.dotSize
    readonly property vector2d size: Qt.vector2d(width, height)
    property color dark: Theme.slab
    property color light: Theme.inkSoft

    fragmentShader: Qt.resolvedUrl("shaders/dither-image.frag.qsb")
}
