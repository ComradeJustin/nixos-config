import QtQuick

// Text in Departure Mono, drawn without smoothing so every pixel is sharp.
// There is one weight; emphasis comes from colour, reverse video and size.
Text {
    // 1 is the font's native 11 px. 2 and 4 double and quadruple it; only
    // whole multiples stay sharp.
    property int scaleFactor: 1
    // How much of the text is printed, from 0 to 1. Text is typed in and
    // erased one character at a time; it never fades.
    property real typed: 1

    readonly property int typedCharacters: Math.round(Math.max(0, Math.min(1, typed)) * text.length)
    readonly property bool fullyTyped: typedCharacters === text.length

    color: Theme.inkSoft
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize * scaleFactor
    font.hintingPreference: Font.PreferNoHinting
    font.kerning: false
    renderType: Text.NativeRendering
    antialiasing: false
    // Every character is one cell wide, so cutting the width at a whole
    // number of cells shows exactly that many characters.
    width: fullyTyped ? implicitWidth : typedCharacters * Theme.cellWidth * scaleFactor
    clip: !fullyTyped
}
