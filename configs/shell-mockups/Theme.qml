pragma Singleton
import QtQuick
import Quickshell

// Colours, fonts and sizes shared by every mock layout. The palette comes
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
    // Opaque on purpose: text behind a panel must never show through it.
    readonly property color surface: base00
    readonly property color raised: base01
    readonly property color stroke: base02
    readonly property color text: base05
    readonly property color textStrong: base07
    readonly property color textDim: base04
    readonly property color textFaint: base03
    readonly property color accent: base0F
    readonly property color accentSoft: Qt.rgba(base0F.r, base0F.g, base0F.b, 0.16)
    readonly property color accentStrong: Qt.rgba(base0F.r, base0F.g, base0F.b, 0.3)

    readonly property string fontUi: "Hanken Grotesk"
    readonly property string fontMono: "Maple Mono NF"
    readonly property string fontDisplay: "Fraunces"

    readonly property int radiusPanel: 12
    readonly property int radiusControl: 8
}
