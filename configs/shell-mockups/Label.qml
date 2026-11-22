import QtQuick

// Text in Departure Mono, drawn without smoothing so every pixel is sharp.
// There is one weight; emphasis comes from colour, reverse video and size.
Text {
    // 1 is the font's native 11 px. 2 and 4 double and quadruple it; only
    // whole multiples stay sharp.
    property int scaleFactor: 1

    color: Theme.inkSoft
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize * scaleFactor
    font.hintingPreference: Font.PreferNoHinting
    font.kerning: false
    renderType: Text.NativeRendering
    antialiasing: false
}
