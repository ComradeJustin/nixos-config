import QtQuick

// Text set in Recursive. One family covers every voice in the shell:
//   weight   300 (light) to 1000 (black)
//   mono     true for numbers and labels
//   caps     upper case with wide tracking, for the small labels
Text {
    property real weight: 500
    property bool mono: true
    property bool caps: false

    color: Theme.inkSoft
    font.family: Theme.fontFamily
    font.pixelSize: 12
    font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
    font.letterSpacing: caps ? 1.2 : 0
    font.variableAxes: ({
            "wght": weight,
            "MONO": mono ? 1 : 0,
            "CASL": 0
        })
}
