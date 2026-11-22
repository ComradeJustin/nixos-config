import QtQuick

// Text set in Recursive, the only visual material in the shell.
//   weight   300 (light) to 1000 (black); this is how emphasis is shown
//   mono     true for numbers, so digits keep their width as they change
Text {
    property real weight: 450
    property bool mono: false

    color: Theme.inkSoft
    font.family: Theme.fontFamily
    font.pixelSize: 13
    font.variableAxes: ({
            "wght": weight,
            "MONO": mono ? 1 : 0,
            "CASL": 0
        })
}
