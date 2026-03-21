pragma Singleton
import QtQuick
import Quickshell

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
    readonly property color textAccent:    base0D    // Blue - primary accent
    readonly property color textKeyword:   base0E    // base0E: Keywords, Purple
    readonly property color textDeprecated: base0F   // base0F: Deprecated, Brown

    // ── Multi-accent system (states) ──
    readonly property color accentPrimary:   base0D    // Blue - main interactions
    readonly property color accentSecondary: base0E    // Purple - secondary elements
    readonly property color accentSuccess:   base0B    // Green - positive states
    readonly property color accentWarning:   base0A    // Yellow - warnings
    readonly property color accentDanger:    base08    // Red - errors/destructive
    readonly property color accentInfo:      base0C    // Cyan - informational
    readonly property color accentWarm:      base09    // Orange - warm highlights

    // ── Content Domain Colors (each info type has its own identity) ──
    readonly property color domainNotifications: base0A  // Yellow - alerts/attention
    readonly property color domainMedia:         base0E  // Purple - music/video/entertainment
    readonly property color domainNetwork:       base0D  // Blue - wifi/bluetooth/connections
    readonly property color domainSystem:        base09  // Orange - CPU/RAM/hardware
    readonly property color domainTime:          base0C  // Cyan - clock/calendar/dates
    readonly property color domainWeather:       base0B  // Green - environmental info
    readonly property color domainPower:         base0B  // Green - battery (changes by state)
    readonly property color domainStorage:       base0F  // Brown - clipboard/files/data
    readonly property color domainApps:          base0D  // Blue - launcher/applications
    readonly property color domainSettings:      base0E  // Purple - configuration/gear

    // OSD
    readonly property color osdBackground: base01    // base01: Lighter Background
    readonly property color osdAccent:     domainMedia    // Purple accent for OSD (audio domain)
    readonly property color osdBarBg:      base02    // base02: Selection Background
    readonly property color osdVolumeAccent:     domainMedia    // Purple for volume (audio)
    readonly property color osdBrightnessAccent: domainSystem   // Orange for brightness (hardware)

    // Workspace
    readonly property color wsFocused:     accentPrimary  // Blue for focused workspace
    readonly property color wsActive:      base04    // base04: Dark Foreground (status bars)
    readonly property color wsDimmed:      base03    // base03: inactive workspace dots
    readonly property color wsPillBg:      base01    // base01: Lighter Background

    // ── Grid System ──
    readonly property int unit: 8  // Base unit for all spacing (8px grid)

    readonly property string fontFamily: "JetBrains Mono Nerd Font"
    readonly property string fontMono:   "JetBrains Mono Nerd Font"
    readonly property string fontIcons:  "JetBrains Mono Nerd Font"
    readonly property int    fontSize:       11   // Body text (slightly smaller for density)
    readonly property int    fontSizeSmall:  9    // Labels, captions
    readonly property int    fontSizeLarge:  13   // Headers
    readonly property int    iconSize:       16   // 2 units - grid aligned
    readonly property bool   fontBold:       false


    readonly property int   borderWidth:      1
    readonly property int   borderWidthThick: 2
    readonly property color borderColor:      base03    // Visible but not harsh
    readonly property color borderActive:     accentPrimary  // Blue for active
    readonly property color borderFocus:      accentSecondary // Purple for focus states

    // ── Cozy Radius Values (control center only, bar stays sharp) ──
    readonly property int radiusSmall:  4     // Subtle rounding for cards
    readonly property int radiusMedium: 8     // Cards, containers
    readonly property int radiusLarge:  12    // Larger elements, panels

    // ── Cozy Spacing (improved readability) ──
    readonly property int ccItemPadding: 12   // More breathing room
    readonly property int ccItemSpacing: 6    // Between items

    // ── Bar Geometry (grid-aligned) ──
    readonly property int barHeight:  32   // 4 units
    readonly property int barPadding: 8    // 1 unit
    readonly property int barSpacing: 16   // 2 units

    // ── OSD Geometry (grid-aligned) ──
    readonly property int osdWidth:    256  // 32 units
    readonly property int osdHeight:   48   // 6 units - thinner
    readonly property int osdIconSize: 20   // Slightly smaller
    readonly property int osdFontSize: 11
    readonly property int osdRadius:   0    // Brutalist: no rounded corners
    readonly property int osdTimeout:  1500
    readonly property int osdFadeMs:   200

    // ── Notifications (grid-aligned) ──
    readonly property int    notifWidth:       360  // 45 units
    readonly property int    notifMaxVisible:  5
    readonly property int    notifTimeout:     5000
    readonly property int    notifRadius:      6    // Cozy: subtle rounding
    readonly property int    notifSpacing:     8    // 1 unit
    readonly property int    notifPadding:     14   // Cozy: more breathing room
    readonly property int    notifMarginTop:   8    // 1 unit
    readonly property int    notifMarginRight: 8    // 1 unit
    readonly property int    notifTitleSize:   12
    readonly property int    notifBodySize:    11
    readonly property int    notifIconSize:    32   // 4 units
    readonly property color  notifBackground:  base01
    readonly property color  notifTitle:       base06
    readonly property color  notifBody:        base04
    readonly property color  notifAccent:      domainNotifications  // Yellow - notification identity
    readonly property color  notifAppName:     domainNotifications  // Yellow for app names
    readonly property color  notifBorder:      domainNotifications  // Yellow default border
    readonly property color  notifUrgentBorder: accentDanger        // Red for urgent
    readonly property color  notifLowBorder:   base03               // Dim for low priority
    readonly property color  selectionBg:      base02
    readonly property int    notifHistWidth:    384  // 48 units
    readonly property int    notifHistMaxHeight: 512 // 64 units

    // ── Bar Module Accents (using domain colors) ──
    readonly property color  barCpuAccent:     domainSystem     // Orange for CPU
    readonly property color  barRamAccent:     domainSystem     // Orange for RAM (same domain)
    readonly property color  barBatteryFull:   domainPower      // Green when full
    readonly property color  barBatteryLow:    accentDanger     // Red when low
    readonly property color  barBatteryCharge: accentWarm       // Orange when charging
    readonly property color  barNetworkAccent: domainNetwork    // Blue for network
    readonly property color  barTimeAccent:    domainTime       // Cyan for time/date
    readonly property color  barMediaAccent:   domainMedia      // Purple for media

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
    readonly property color  clipAccent:     domainStorage  // Brown for clipboard

    // ── App Launcher (grid-aligned) ──
    readonly property int    launchWidth:      504  // 63 units
    readonly property int    launchMaxHeight:  464  // 58 units
    readonly property int    launchIconSize:   32   // 4 units
    readonly property int    launchItemHeight: 40   // 5 units
    readonly property string iconSearch:       "󰍉"
    readonly property string iconLaunch:       "󰍃"
    readonly property color  scrimColor:       Qt.rgba(0, 0, 0, 0.35)
    readonly property color  launchAccent:     domainApps     // Blue for launcher
    readonly property color  launchSelected:   domainApps     // Blue for selected item

    // ── Wifi popup (grid-aligned) ──
    readonly property int    wifiWidth:        296  // 37 units
    readonly property int    wifiMaxHeight:    384  // 48 units
    readonly property int    wifiItemHeight:   40   // 5 units
    readonly property string iconWifiLock:     "󰤪"
    readonly property color  wifiAccent:       domainNetwork  // Blue for wifi popup

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
    readonly property int    ccPadding:       18   // Cozy: more breathing room
    readonly property int    ccSectionRadius: 6    // Cozy: subtle rounding
    readonly property color  ccSectionBg:     base01
    readonly property color  ccCardBg:        Qt.rgba(base01.r, base01.g, base01.b, 0.6)  // Subtle card bg
    readonly property color  ccIconBg:        Qt.rgba(base02.r, base02.g, base02.b, 0.5)  // Muted icon placeholder
    readonly property int    ccArtSize:       80   // 10 units

    // Control Center accent colors (using domain colors)
    readonly property color  ccSliderVolume:  domainMedia      // Purple for volume (audio domain)
    readonly property color  ccSliderBright:  domainSystem     // Orange for brightness (hardware)
    readonly property color  ccToggleOn:      accentSuccess    // Green for enabled toggles
    readonly property color  ccToggleOff:     base03           // Dim for disabled
    readonly property color  ccMediaAccent:   domainMedia      // Purple for media controls
    readonly property color  ccWifiAccent:    domainNetwork    // Blue for wifi
    readonly property color  ccWifiConnected: accentSuccess    // Green for connected state
    readonly property color  ccBtAccent:      domainNetwork    // Blue for bluetooth
    readonly property color  ccBtConnected:   accentSuccess    // Green for connected state
    readonly property color  ccNotifAccent:   domainNotifications // Yellow for notifications tab
    readonly property color  ccSettingsAccent: domainSettings  // Purple for settings

    // ── Notification Item Colors (for distinguishing in control center) ──
    readonly property color  notifItemBg:     Qt.rgba(base01.r, base01.g, base01.b, 0.4)  // Subtle bg
    readonly property color  notifSubItemBg:  Qt.rgba(base01.r, base01.g, base01.b, 0.2)  // Even more subtle for sub-items
    readonly property string iconSkipBack:    "󰒮"
    readonly property string iconSkipFwd:     "󰒭"
    readonly property string iconPlay:        "󰐊"
    readonly property string iconPause:       "󰏤"
    readonly property string iconCC:          "󱊖"

    // ── Cava / Media popup (grid-aligned) ──
    readonly property int    cavaWidth:     320  // 40 units
    readonly property int    cavaHeight:    180  // 22.5 units - compact
    readonly property int    cavaBars:      24
    readonly property int    cavaRadius:    0    // Sharp edges for bar popup
    readonly property color  cavaBackground: barBackground
    readonly property color  cavaBarColor:  domainMedia  // Purple for audio visualizer
    readonly property int    cavaArtSize:   48   // Compact art size
    readonly property string iconPrev:      "󰒮"
    readonly property string iconNext:      "󰒭"

    // Power menu
    readonly property string iconLock:      "󰌾"
    readonly property string iconLogout:    "󰍃"
    readonly property string iconSuspend:   "󰤄"
    readonly property string iconReboot:    "󰜉"
    readonly property string iconShutdown:  "󰐥"
    readonly property color  powerAccent:   accentDanger     // Red for power actions
    readonly property color  powerSuspend:  accentWarning    // Yellow for suspend
    readonly property color  powerLock:     domainSettings   // Purple for lock

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
    readonly property color  weatherAccent:      domainWeather  // Green for weather

    // Lock screen
    readonly property string iconUser:           "󰀄"
    readonly property string iconMusic:          "󰎆"
    readonly property string lockBackground:     configBase + "/assets/wallpapers/cloud.jpg"

    // ── Background Widgets ──
    readonly property color  widgetBackground:   Qt.rgba(base00.r, base00.g, base00.b, 0.75)
    readonly property color  widgetText:         base06
    readonly property color  widgetTextDimmed:   base04
    readonly property int    widgetRadius:       radiusMedium
    readonly property int    widgetPadding:      16
    readonly property int    widgetShadowRadius: 24
    readonly property color  widgetShadowColor:  Qt.rgba(0, 0, 0, 0.3)

    // Widget-specific accents (using domain colors)
    readonly property color  widgetWeatherAccent:  domainWeather   // Green for weather
    readonly property color  widgetClockAccent:    domainTime      // Cyan for clock
    readonly property color  widgetCalendarAccent: domainTime      // Cyan for calendar (time domain)
    readonly property color  widgetSystemAccent:   domainSystem    // Orange for system stats
    readonly property color  widgetMediaAccent:    domainMedia     // Purple for now playing
    readonly property color  widgetQuoteAccent:    base0C          // Cyan for quotes (neutral info)

    // Widget Edit Mode
    readonly property string iconEdit:           "󰏫"
    readonly property string iconSave:           "󰆓"
    readonly property string iconCancel:         "󰅖"
    readonly property string iconDrag:           "󰘕"
    readonly property string iconWidgets:        "󰕰"
    readonly property color  editModeBorder:     accentPrimary
    readonly property color  snapIndicatorBg:    Qt.rgba(accentPrimary.r, accentPrimary.g, accentPrimary.b, 0.15)
    readonly property color  snapIndicatorActive: Qt.rgba(accentPrimary.r, accentPrimary.g, accentPrimary.b, 0.4)
}
