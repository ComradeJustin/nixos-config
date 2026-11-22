import QtQuick

// Text in Departure Mono, drawn without smoothing so every pixel is sharp.
// There is one weight; emphasis comes from colour, reverse video and size.
Text {
    // 1 is the font's native 11 px. 2 and 4 double and quadruple it; only
    // whole multiples stay sharp.
    property int scaleFactor: 1
    // Set in the font's small capitals. Used for keys and titles, so they
    // read as labels and not as values.
    property bool smallCaps: false

    color: Theme.inkSoft
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize * scaleFactor
    font.hintingPreference: Font.PreferNoHinting
    font.kerning: false
    font.features: smallCaps ? ({
            "smcp": 1
        }) : ({})
    renderType: Text.NativeRendering
    antialiasing: false
}
