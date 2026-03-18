import QtQuick
import Quickshell

// ── New Utilitarianism Theme ──
// Design philosophy: Form follows function - every element serves a purpose
// Colors from Stylix environment variables (BASE00-BASE0F)
// Grid system: 8px base unit for consistent spacing
// See: https://github.com/chriskempson/base16/blob/main/styling.md
QtObject {
    // ── Paths (derived from environment) ──
    readonly property string homeDir: Quickshell.env("HOME") || "/home/justin"
    readonly property string configBase: homeDir + "/nixos-config"

    // ── Base16 palette (from Stylix environment variables) ──
    // Fallbacks are Gruvbox Dark Hard if env vars not set
    readonly property color base00: Quickshell.env("BASE00") || "#1d2021"  // Default Background
    readonly property color base01: Quickshell.env("BASE01") || "#3c3836"  // Lighter Background
    readonly property color base02: Quickshell.env("BASE02") || "#504945"  // Selection Background
    readonly property color base03: Quickshell.env("BASE03") || "#665c54"  // Comments, Invisibles
    readonly property color base04: Quickshell.env("BASE04") || "#bdae93"  // Dark Foreground
    readonly property color base05: Quickshell.env("BASE05") || "#d5c4a1"  // Default Foreground
    readonly property color base06: Quickshell.env("BASE06") || "#ebdbb2"  // Light Foreground
    readonly property color base07: Quickshell.env("BASE07") || "#fbf1c7"  // Light Background
    readonly property color base08: Quickshell.env("BASE08") || "#fb4934"  // Red
    readonly property color base09: Quickshell.env("BASE09") || "#fe8019"  // Orange
    readonly property color base0A: Quickshell.env("BASE0A") || "#fabd2f"  // Yellow
    readonly property color base0B: Quickshell.env("BASE0B") || "#b8bb26"  // Green
    readonly property color base0C: Quickshell.env("BASE0C") || "#8ec07c"  // Cyan
    readonly property color base0D: Quickshell.env("BASE0D") || "#83a598"  // Blue
    readonly property color base0E: Quickshell.env("BASE0E") || "#d3869b"  // Purple
    readonly property color base0F: Quickshell.env("BASE0F") || "#d65d0e"  // Brown

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

    // ── Grid System ──
    readonly property int unit: 8  // Base unit for all spacing (8px grid)

    // ── Typography ──
    // Inter for UI, JetBrains Mono for data/code
    readonly property string fontFamily: "Inter"
    readonly property string fontMono:   "JetBrains Mono"
    readonly property string fontIcons:  "JetBrains Mono Nerd Font"
    readonly property int    fontSize:       12   // Body text
    readonly property int    fontSizeSmall:  10   // Labels, captions
    readonly property int    fontSizeLarge:  14   // Headers
    readonly property int    iconSize:       16   // 2 units - grid aligned
    readonly property bool   fontBold:       false

    // ── Bar Geometry (grid-aligned) ──
    readonly property int barHeight:  32   // 4 units
    readonly property int barPadding: 8    // 1 unit
    readonly property int barSpacing: 16   // 2 units

    // ── OSD Geometry (grid-aligned) ──
    readonly property int osdWidth:    256  // 32 units
    readonly property int osdHeight:   56   // 7 units
    readonly property int osdIconSize: 24   // 3 units
    readonly property int osdFontSize: 12
    readonly property int osdRadius:   8    // 1 unit - industrial sharp corners
    readonly property int osdTimeout:  1500
    readonly property int osdFadeMs:   200

    // ── Notifications (grid-aligned) ──
    readonly property int    notifWidth:       360  // 45 units
    readonly property int    notifMaxVisible:  5
    readonly property int    notifTimeout:     5000
    readonly property int    notifRadius:      8    // 1 unit - industrial
    readonly property int    notifSpacing:     8    // 1 unit
    readonly property int    notifPadding:     16   // 2 units
    readonly property int    notifMarginTop:   8    // 1 unit
    readonly property int    notifMarginRight: 8    // 1 unit
    readonly property int    notifTitleSize:   12
    readonly property int    notifBodySize:    11
    readonly property int    notifIconSize:    32   // 4 units
    readonly property color  notifBackground:  base01
    readonly property color  notifTitle:       base06
    readonly property color  notifBody:        base04
    readonly property color  notifAppName:     base03
    readonly property color  notifUrgentBorder: base08
    readonly property color  selectionBg:      base02
    readonly property int    notifHistWidth:    384  // 48 units
    readonly property int    notifHistMaxHeight: 512 // 64 units

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

    // Bluetooth
    readonly property string iconBtOn:        "󰂯"
    readonly property string iconBtOff:       "󰂲"
    readonly property string iconBtConnected: "󰂱"

    // ── Clipboard (grid-aligned) ──
    readonly property int    clipWidth:      416  // 52 units
    readonly property int    clipMaxHeight:  464  // 58 units
    readonly property int    clipMaxItems:   30
    readonly property int    clipThumbSize:  48   // 6 units

    // ── App Launcher (grid-aligned) ──
    readonly property int    launchWidth:      504  // 63 units
    readonly property int    launchMaxHeight:  464  // 58 units
    readonly property int    launchIconSize:   32   // 4 units
    readonly property int    launchItemHeight: 40   // 5 units
    readonly property string iconSearch:       "󰍉"
    readonly property string iconLaunch:       "󰍃"
    readonly property color  scrimColor:       Qt.rgba(0, 0, 0, 0.35)

    // ── Wifi popup (grid-aligned) ──
    readonly property int    wifiWidth:        296  // 37 units
    readonly property int    wifiMaxHeight:    384  // 48 units
    readonly property int    wifiItemHeight:   40   // 5 units
    readonly property string iconWifiLock:     "󰤪"

    // ── Wallpaper selector (grid-aligned) ──
    readonly property int    wpWidth:          560  // 70 units
    readonly property int    wpMaxHeight:      480  // 60 units
    readonly property int    wpThumbWidth:     160  // 20 units
    readonly property int    wpThumbHeight:    96   // 12 units
    readonly property int    wpSpacing:        8    // 1 unit
    readonly property string wpDirectory:      configBase + "/assets/wallpapers"
    readonly property string iconWallpaper:    "󰸉"

    // ── Control Center (grid-aligned) ──
    readonly property int    ccWidth:         384  // 48 units
    readonly property int    ccPadding:       16   // 2 units
    readonly property int    ccSectionRadius: 8    // 1 unit - industrial
    readonly property color  ccSectionBg:     base01
    readonly property int    ccArtSize:       80   // 10 units
    readonly property string iconSkipBack:    "󰒮"
    readonly property string iconSkipFwd:     "󰒭"
    readonly property string iconPlay:        "󰐊"
    readonly property string iconPause:       "󰏤"
    readonly property string iconCC:          "󱊖"

    // ── Cava / Media popup (grid-aligned) ──
    readonly property int    cavaWidth:     320  // 40 units
    readonly property int    cavaHeight:    240  // 30 units
    readonly property int    cavaBars:      24
    readonly property int    cavaRadius:    8    // 1 unit - industrial
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
    readonly property string lockBackground:     configBase + "/assets/wallpapers/cloud.jpg"
}
