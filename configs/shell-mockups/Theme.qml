pragma Singleton
import QtQuick
import Quickshell

// Colours, type and motion shared by the whole mockup. The palette comes
// from the BASE00–BASE0F environment variables (modules/desktop/theme.nix).
Singleton {
    readonly property color base00: Quickshell.env("BASE00") || "#241d1a"
    readonly property color base01: Quickshell.env("BASE01") || "#362b27"
    readonly property color base02: Quickshell.env("BASE02") || "#473933"
    readonly property color base03: Quickshell.env("BASE03") || "#594740"
    readonly property color base04: Quickshell.env("BASE04") || "#a78e84"
    readonly property color base05: Quickshell.env("BASE05") || "#b8a59d"
    readonly property color base07: Quickshell.env("BASE07") || "#dcd2ce"
    readonly property color base0F: Quickshell.env("BASE0F") || "#f1ae97"

    // What each colour is for.
    readonly property color surface: base00
    readonly property color raised: base01
    readonly property color stroke: base02
    readonly property color text: base05
    readonly property color textStrong: base07
    readonly property color textDim: base04
    readonly property color textFaint: base03
    readonly property color accent: base0F

    // Recursive is one variable font: weight, monospace and "casual" are
    // axes of the same family (see Label.qml). It is not installed
    // system-wide yet, so it is loaded from the link next to this file.
    readonly property string fontFamily: recursive.status === FontLoader.Ready ? recursive.name : "Recursive"

    // Motion. Everything moves on springs: they overshoot once and keep their
    // velocity when retargeted, so repeated key presses carry momentum.
    // Nothing runs while idle.
    readonly property real ringSpring: 3.0
    readonly property real ringDamping: 0.26
    readonly property real panelSpring: 3.6
    readonly property real panelDamping: 0.38

    FontLoader {
        id: recursive

        source: Qt.resolvedUrl("recursive-font/share/fonts/truetype/Recursive_VF_1.085.ttf")
    }
}
