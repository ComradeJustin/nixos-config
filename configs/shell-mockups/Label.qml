import QtQuick

// Text set in Recursive. One family covers every voice in the shell:
//   weight   300 (light) to 1000 (black); animate it to show focus
//   mono     true for numbers and engraved-style labels
//   casual   0 (strict) to 1 (hand-drawn)
//   caps     upper case with wide tracking, for instrument labels
Text {
    property real weight: 500
    property bool mono: false
    property real casual: 0
    property bool caps: false

    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: 12
    font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
    font.letterSpacing: caps ? 1.4 : 0
    font.variableAxes: ({
            "wght": weight,
            "MONO": mono ? 1 : 0,
            "CASL": casual
        })
}
