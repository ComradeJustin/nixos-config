import QtQuick

// ── Base16 Theme ──
// Swap any base00–base0F value to re-theme the entire bar.
// Default: Gruvbox Dark Hard
// See: https://github.com/chriskempson/base16/blob/main/styling.md
QtObject {
    // ── Base16 palette ──
    readonly property color base00: "#1d2021"  // Default Background
    readonly property color base01: "#3c3836"  // Lighter Background (status bars)
    readonly property color base02: "#504945"  // Selection Background
    readonly property color base03: "#665c54"  // Comments, Invisibles, Line Highlighting
    readonly property color base04: "#bdae93"  // Dark Foreground (status bars)
    readonly property color base05: "#d5c4a1"  // Default Foreground
    readonly property color base06: "#ebdbb2"  // Light Foreground
    readonly property color base07: "#fbf1c7"  // Light Background
    readonly property color base08: "#fb4934"  // Red
    readonly property color base09: "#fe8019"  // Orange
    readonly property color base0A: "#fabd2f"  // Yellow
    readonly property color base0B: "#b8bb26"  // Green
    readonly property color base0C: "#8ec07c"  // Cyan
    readonly property color base0D: "#83a598"  // Blue
    readonly property color base0E: "#d3869b"  // Purple
    readonly property color base0F: "#d65d0e"  // Brown

    // ── Semantic aliases (edit these to remap base16 roles) ──
    readonly property color barBackground: base00
    readonly property color textPrimary:   base05
    readonly property color textDimmed:    base03
    readonly property color textCritical:  base08
    readonly property color textCharging:  base0B
    readonly property color textWarning:   base0A
    readonly property color textAccent:    base0D
    readonly property color textInfo:      base0C

    // OSD
    readonly property color osdBackground: base01
    readonly property color osdAccent:     base0D
    readonly property color osdBarBg:      base02

    // Workspace
    readonly property color wsFocused:     base05
    readonly property color wsActive:      base04
    readonly property color wsDimmed:      base03
    readonly property color wsPillBg:      base01

    // Font
    readonly property string fontFamily: "CommitMono Nerd Font Mono"
    readonly property int    fontSize:   15
    readonly property int    iconSize:   17
    readonly property bool   fontBold:   false

    // Bar geometry
    readonly property int barHeight:  32
    readonly property int barPadding: 12
    readonly property int barSpacing: 16

    // OSD geometry
    readonly property int osdWidth:   260
    readonly property int osdHeight:  60
    readonly property int osdIconSize: 28
    readonly property int osdFontSize: 14
    readonly property int osdRadius:  16
    readonly property int osdTimeout: 1500
    readonly property int osdFadeMs: 300

    // Notifications
    readonly property int    notifWidth:       360
    readonly property int    notifMaxVisible:  5
    readonly property int    notifTimeout:     5000
    readonly property int    notifRadius:      12
    readonly property int    notifSpacing:     8
    readonly property int    notifPadding:     14
    readonly property int    notifMarginTop:   8
    readonly property int    notifMarginRight: 12
    readonly property int    notifTitleSize:   13
    readonly property int    notifBodySize:    12
    readonly property int    notifIconSize:    36
    readonly property color  notifBackground:  base01
    readonly property color  notifTitle:       base06
    readonly property color  notifBody:        base04
    readonly property color  notifAppName:     base03
    readonly property color  notifUrgentBorder: base08
    readonly property int    notifHistWidth:    380
    readonly property int    notifHistMaxHeight: 500

    // Icons
    readonly property string iconCpu:       "󰻠"
    readonly property string iconRam:       ""
    readonly property string iconVolHigh:   "󰕾"
    readonly property string iconVolMid:    "󰖀"
    readonly property string iconVolLow:    "󰕿"
    readonly property string iconVolMute:   "󰖁"
    readonly property string iconBriHigh:   "󰃠"
    readonly property string iconBriMid:    "󰃝"
    readonly property string iconBriLow:    "󰃞"
    readonly property string iconBriOff:    "󰃜"
    readonly property string iconWifiHi:    "󰤨"
    readonly property string iconWifiMid:   "󰤥"
    readonly property string iconWifiLow:   "󰤢"
    readonly property string iconWifiMin:   "󰤟"
    readonly property string iconWifiOff:   "󰤭"
    readonly property string iconEth:       "󰈀"
    readonly property string iconBatChg:    "󰂄"
    readonly property string iconBat100:    "󰁹"
    readonly property string iconBat80:     "󰂀"
    readonly property string iconBat60:     "󰁾"
    readonly property string iconBat40:     "󰁼"
    readonly property string iconBat20:     "󰂃"
    readonly property string iconBatNone:   "󰂑"
    readonly property string iconPlug:      "󰚥"
    readonly property string iconCal:       "󰃶"
    readonly property string iconClock:     "󰥔"
    readonly property string iconHeadphone: "󰋋"
    readonly property string iconSpeaker:   "󰓃"
    readonly property string iconMediaPlay: "󰐊"
    readonly property string iconMediaPause:"󰏤"
    readonly property string iconNixos:     "󱄅"
    readonly property string iconBell:      "󰂚"
    readonly property string iconBellBadge: "󰂞"
    readonly property string iconTrash:     "󰆴"
    readonly property string iconDnd:       "󰂛"
    readonly property string iconDndOff:    "󰂚"
    readonly property string iconClipboard: "󰅍"

    // Clipboard
    readonly property int    clipWidth:      420
    readonly property int    clipMaxHeight:  460
    readonly property int    clipMaxItems:   30
    readonly property int    clipThumbSize:  48

    // App Launcher
    readonly property int    launchWidth:      500
    readonly property int    launchMaxHeight:  460
    readonly property int    launchIconSize:   36
    readonly property int    launchItemHeight: 44
    readonly property string iconSearch:       "󰍉"
    readonly property string iconLaunch:       "󰍃"
    readonly property color  scrimColor:       Qt.rgba(0, 0, 0, 0.35)

    // Cava visualizer
    readonly property int    cavaWidth:     200
    readonly property int    cavaHeight:    120
    readonly property int    cavaBars:      24
    readonly property int    cavaRadius:    12
    readonly property color  cavaBackground: barBackground
    readonly property color  cavaBarColor:  base0D
    readonly property color  cavaBarPeak:   base0E
}
