pragma Singleton
import QtQuick
import Quickshell

// Palette and type for the v2 overlay. Same Stylix/base16 colors as the
// current desktop so this launcher sits on the existing wallpaper/bar.
QtObject {
    readonly property string homeDir: Quickshell.env("HOME") || "/home/justin"
    readonly property string configBase: homeDir + "/nixos-config"
    readonly property string wallpaperDir: configBase + "/assets/wallpapers"

    readonly property color base00: Quickshell.env("BASE00") || "#1d2021"
    readonly property color base01: Quickshell.env("BASE01") || "#3c3836"
    readonly property color base02: Quickshell.env("BASE02") || "#504945"
    readonly property color base03: Quickshell.env("BASE03") || "#665c54"
    readonly property color base04: Quickshell.env("BASE04") || "#bdae93"
    readonly property color base05: Quickshell.env("BASE05") || "#d5c4a1"
    readonly property color base06: Quickshell.env("BASE06") || "#ebdbb2"
    readonly property color base07: Quickshell.env("BASE07") || "#fbf1c7"
    readonly property color base08: Quickshell.env("BASE08") || "#fb4934"
    readonly property color base09: Quickshell.env("BASE09") || "#fe8019"
    readonly property color base0A: Quickshell.env("BASE0A") || "#fabd2f"
    readonly property color base0B: Quickshell.env("BASE0B") || "#b8bb26"
    readonly property color base0C: Quickshell.env("BASE0C") || "#8ec07c"
    readonly property color base0D: Quickshell.env("BASE0D") || "#83a598"
    readonly property color base0E: Quickshell.env("BASE0E") || "#d3869b"
    readonly property color base0F: Quickshell.env("BASE0F") || "#d65d0e"

    readonly property color bg: base00
    readonly property color glass: Qt.rgba(base00.r, base00.g, base00.b, 0.78)
    readonly property color text: base05
    readonly property color textDim: base04
    readonly property color textMute: base03
    readonly property color accent: base0D
    readonly property color danger: base08
    readonly property color warning: base0A
    readonly property color warm: base09
    readonly property color keyword: base0E
    readonly property color success: base0B
    readonly property color border: base03
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.45)
    readonly property color tileBg: Qt.rgba(base01.r, base01.g, base01.b, 0.9)
    readonly property color tileHover: Qt.rgba(base05.r, base05.g, base05.b, 0.08)
    readonly property color tileActive: Qt.rgba(base0D.r, base0D.g, base0D.b, 0.16)

    readonly property string fontUi: "Hanken Grotesk"
    readonly property string fontMono: "Maple Mono NF"
    readonly property string fontIcon: "Maple Mono NF"

    readonly property int radius: 12
    readonly property int radiusSmall: 8
    readonly property int cardWidth: 520
    readonly property int cardPad: 20
    readonly property int footerHeight: 40
    readonly property int tileMinHeight: 40
    readonly property int launchRow: 44
    readonly property int launchIcon: 32

    readonly property int animFast: 80
    readonly property int animIn: 80
    readonly property int animOut: 60
}
