pragma Singleton
import QtQuick
import Quickshell

// Colours, type and motion shared by the whole mockup. The palette comes
// from the BASE00–BASE0F environment variables (modules/desktop/theme.nix).
//
// The look borrows from departuremono.com: flat slabs, thin rules, tiny
// labels over larger values, and one inverted block to mark what is selected.
Singleton {
    readonly property color base00: Quickshell.env("BASE00") || "#241d1a"
    readonly property color base03: Quickshell.env("BASE03") || "#594740"
    readonly property color base04: Quickshell.env("BASE04") || "#a78e84"
    readonly property color base05: Quickshell.env("BASE05") || "#b8a59d"
    readonly property color base07: Quickshell.env("BASE07") || "#dcd2ce"
    readonly property color base0F: Quickshell.env("BASE0F") || "#f1ae97"

    // What each colour is for.
    readonly property color slab: base00
    readonly property color rule: base03
    readonly property color ink: base07
    readonly property color inkSoft: base05
    readonly property color inkDim: base04
    // The inverted block that marks focus or selection, and the text on it.
    readonly property color accent: base0F
    readonly property color onAccent: base00

    // Recursive is one variable font (see Label.qml). It is not installed
    // system-wide yet, so it is loaded from the link next to this file.
    readonly property string fontFamily: recursive.status === FontLoader.Ready ? recursive.name : "Recursive"

    // Motion. Springs, so repeated key presses carry momentum, tuned to
    // settle fast (measured): turning the ring about 130 ms with a slight
    // overshoot, opening a station about 145 ms, bar drop-downs about 115 ms.
    // Nothing runs while idle.
    readonly property real turnSpring: 8
    readonly property real turnDamping: 0.5
    readonly property real openSpring: 10
    readonly property real openDamping: 0.6
    readonly property real dropSpring: 14
    readonly property real dropDamping: 0.7

    // A colour partway between two others. amount 0 gives `from`, 1 gives `to`.
    function mix(from: color, to: color, amount: real): color {
        return Qt.rgba(from.r + (to.r - from.r) * amount, from.g + (to.g - from.g) * amount, from.b + (to.b - from.b) * amount, 1);
    }

    FontLoader {
        id: recursive

        source: Qt.resolvedUrl("recursive-font/share/fonts/truetype/Recursive_VF_1.085.ttf")
    }
}
