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
    // base00-07: background to foreground gradient (dark → light)
    // base08-0F: accent colors
    readonly property color barBackground: base00    // base00: Default Background
    readonly property color textPrimary:   base05    // base05: Default Foreground
    readonly property color textDimmed:    base04    // base04: Dark Foreground (status bars)
    readonly property color textSubtle:    base03    // base03: Comments, Invisibles
    readonly property color textCritical:  base08    // base08: Variables, Red
    readonly property color textOrange:    base09    // base09: Integers, Constants, Orange
    readonly property color textWarning:   base0A    // base0A: Classes, Yellow
    readonly property color textCharging:  base0B    // base0B: Strings, Green
    readonly property color textInfo:      base0C    // base0C: Support, Cyan
    readonly property color textAccent:    base0D    // base0D: Functions, Blue
    readonly property color textKeyword:   base0E    // base0E: Keywords, Purple
    readonly property color textDeprecated: base0F   // base0F: Deprecated, Brown

    // OSD
    readonly property color osdBackground: base01    // base01: Lighter Background
    readonly property color osdAccent:     base0D
    readonly property color osdBarBg:      base02    // base02: Selection Background

    // Workspace
    readonly property color wsFocused:     base05
    readonly property color wsActive:      base04    // base04: Dark Foreground (status bars)
    readonly property color wsDimmed:      base03    // base03: inactive workspace dots
    readonly property color wsPillBg:      base01    // base01: Lighter Background

    // Font
    readonly property string fontFamily: "monospace"
    readonly property int    fontSize:   13
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
    readonly property color  notifBackground:  base01  // base01: Lighter Background
    readonly property color  notifTitle:       base06  // base06: Light Foreground
    readonly property color  notifBody:        base04  // base04: Dark Foreground
    readonly property color  notifAppName:     base03  // base03: subtle/dim
    readonly property color  notifUrgentBorder: base08 // base08: Red
    readonly property color  selectionBg:      base02  // base02: Selection Background
    readonly property int    notifHistWidth:    380
    readonly property int    notifHistMaxHeight: 500

    // Icons
    readonly property string iconCpu:       "󰻠"
    readonly property string iconRam:       "󰍛"
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
    readonly property string iconNixos:     ""
    readonly property string iconPower:    "⏻"
    readonly property string iconGear:     "󰒓"
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

    // Wifi popup
    readonly property int    wifiWidth:        300
    readonly property int    wifiMaxHeight:    380
    readonly property int    wifiItemHeight:   36
    readonly property string iconWifiLock:     "󰤪"

    // Wallpaper selector
    readonly property int    wpWidth:          560
    readonly property int    wpMaxHeight:      480
    readonly property int    wpThumbWidth:     160
    readonly property int    wpThumbHeight:    100
    readonly property int    wpSpacing:        8
    readonly property string wpDirectory:      "~/nixos-config/assets/wallpapers"
    readonly property string iconWallpaper:    "󰸉"

    // Control Center
    readonly property int    ccWidth:         380
    readonly property int    ccPadding:       14
    readonly property int    ccSectionRadius: 12
    readonly property color  ccSectionBg:     base01  // base01: Lighter Background
    readonly property int    ccArtSize:       80
    readonly property string iconSkipBack:    "󰒮"
    readonly property string iconSkipFwd:     "󰒭"
    readonly property string iconPlay:        "󰐊"
    readonly property string iconPause:       "󰏤"
    readonly property string iconCC:          "󱊖"

    // Cava / Media popup
    readonly property int    cavaWidth:     320
    readonly property int    cavaHeight:    240
    readonly property int    cavaBars:      24
    readonly property int    cavaRadius:    12
    readonly property color  cavaBackground: barBackground
    readonly property color  cavaBarColor:  base0D  // base0D: Functions, Blue
    readonly property color  cavaBarPeak:   base0E  // base0E: Keywords, Purple
    readonly property int    cavaArtSize:   64
    readonly property string iconPrev:      "󰒮"
    readonly property string iconNext:      "󰒭"

    // Power menu
    readonly property string iconLock:      "󰌾"
    readonly property string iconLogout:    "󰍃"
    readonly property string iconSuspend:   "󰤄"
    readonly property string iconReboot:    "󰜉"
    readonly property string iconShutdown:  "󰐥"

    // Weather
    readonly property string iconWeatherSunny:   "󰖙"
    readonly property string iconWeatherCloudy:  "󰖐"
    readonly property string iconWeatherPartly:  "󰖕"
    readonly property string iconWeatherRain:    "󰖗"
    readonly property string iconWeatherSnow:    "󰖘"
    readonly property string iconWeatherStorm:   "󰖓"
    readonly property string iconWeatherFog:     "󰖑"
    readonly property string iconWeatherNight:   "󰖔"
    readonly property string iconWeatherDefault: "󰖐"

    // Lock screen
    readonly property string iconUser:           "󰀄"
    readonly property string iconMusic:          "󰎆"
    readonly property string lockBackground:     "/home/justin/nixos-config/assets/wallpapers/cloud.jpg"
}
