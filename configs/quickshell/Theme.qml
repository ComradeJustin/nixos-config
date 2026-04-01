pragma Singleton
import QtQuick
import Quickshell

QtObject {
    // ── Paths ──
    readonly property string homeDir: Quickshell.env("HOME") || "/home/justin"
    readonly property string configBase: homeDir + "/nixos-config"

    // ── Base16 palette (from Stylix environment variables) ──
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

    // ── Semantic aliases ──
    readonly property color barBackground: base00
    readonly property color textPrimary:   base05
    readonly property color textDimmed:    base04
    readonly property color textSubtle:    base03
    readonly property color textCritical:  base08
    readonly property color textOrange:    base09
    readonly property color textWarning:   base0A
    readonly property color textCharging:  base0B
    readonly property color textInfo:      base0C
    readonly property color textAccent:    base0D
    readonly property color textKeyword:   base0E
    readonly property color textDeprecated: base0F

    // ── Multi-accent system ──
    readonly property color accentPrimary:   base0D
    readonly property color accentSecondary: base0E
    readonly property color accentSuccess:   base0B
    readonly property color accentWarning:   base0A
    readonly property color accentDanger:    base08
    readonly property color accentInfo:      base0C
    readonly property color accentWarm:      base09

    // ── Content domain colors ──
    readonly property color domainNotifications: base0A
    readonly property color domainMedia:         base0E
    readonly property color domainNetwork:       base0D
    readonly property color domainSystem:        base09
    readonly property color domainTime:          base0C
    readonly property color domainWeather:       base0B
    readonly property color domainPower:         base0B
    readonly property color domainStorage:       base0F
    readonly property color domainApps:          base0D
    readonly property color domainSettings:      base0E

    // ── Workspace ──
    readonly property color wsFocused: accentPrimary
    readonly property color wsActive:  base04
    readonly property color wsDimmed:  base03
    readonly property color wsPillBg:  base01

    // ── Grid System ──
    readonly property int unit: 8

    // ── Typography ──
    readonly property string fontFamily: "JetBrains Mono Nerd Font"
    readonly property string fontMono:   "JetBrains Mono Nerd Font"
    readonly property string fontIcons:  "JetBrains Mono Nerd Font"
    readonly property int    fontSize:       11
    readonly property int    fontSizeSmall:  9
    readonly property int    fontSizeLarge:  13
    readonly property int    iconSize:       16
    readonly property bool   fontBold:       false

    // ── Font aliases (replace verbose font blocks everywhere) ──
    readonly property font fontBody: Qt.font({
        family: fontFamily, pixelSize: fontSize, bold: false
    })
    readonly property font fontBodyBold: Qt.font({
        family: fontFamily, pixelSize: fontSize, bold: true
    })
    readonly property font fontSmall: Qt.font({
        family: fontFamily, pixelSize: fontSizeSmall, bold: false
    })
    readonly property font fontLarge: Qt.font({
        family: fontFamily, pixelSize: fontSizeLarge, bold: true
    })
    readonly property font fontIcon: Qt.font({
        family: fontIcons, pixelSize: iconSize
    })

    // ── Borders ──
    readonly property int   borderWidth:      1
    readonly property int   borderWidthThick: 2
    readonly property color borderColor:      base03
    readonly property color borderActive:     accentPrimary
    readonly property color borderFocus:      accentSecondary

    // ── Radius ──
    readonly property int radiusSmall:  4
    readonly property int radiusMedium: 8
    readonly property int radiusLarge:  12

    // ── Spacing ──
    readonly property int ccItemPadding: 12
    readonly property int ccItemSpacing: 6

    // ── Bar geometry ──
    readonly property int barHeight:  32
    readonly property int barPadding: 8
    readonly property int barSpacing: 8

    // ── OSD geometry ──
    readonly property int    osdWidth:    256
    readonly property int    osdHeight:   48
    readonly property int    osdIconSize: 20
    readonly property int    osdFontSize: 11
    readonly property int    osdRadius:   0
    readonly property int    osdTimeout:  1500
    readonly property int    osdFadeMs:   200
    readonly property color  osdBackground: base01
    readonly property color  osdAccent:     domainMedia
    readonly property color  osdBarBg:      base02

    // ── Notifications ──
    readonly property int    notifWidth:       360
    readonly property int    notifMaxVisible:  5
    readonly property int    notifTimeout:     5000
    readonly property int    notifRadius:      6
    readonly property int    notifSpacing:     8
    readonly property int    notifPadding:     14
    readonly property int    notifMarginTop:   8
    readonly property int    notifMarginRight: 8
    readonly property int    notifTitleSize:   12
    readonly property int    notifBodySize:    11
    readonly property int    notifIconSize:    32
    readonly property color  notifBackground:  base01
    readonly property color  notifTitle:       base06
    readonly property color  notifBody:        base04
    readonly property color  notifAccent:      domainNotifications
    readonly property color  notifAppName:     domainNotifications
    readonly property color  notifBorder:      domainNotifications
    readonly property color  notifUrgentBorder: accentDanger
    readonly property color  notifLowBorder:   base03
    readonly property color  selectionBg:      base02
    readonly property int    notifHistWidth:    384
    readonly property int    notifHistMaxHeight: 512
    readonly property color  notifItemBg:     Qt.rgba(base01.r, base01.g, base01.b, 0.4)
    readonly property color  notifSubItemBg:  Qt.rgba(base01.r, base01.g, base01.b, 0.2)

    // ── Control Center ──
    readonly property int    ccWidth:         384
    readonly property int    ccPadding:       18
    readonly property int    ccSectionRadius: 6
    readonly property color  ccSectionBg:     base01
    readonly property color  ccCardBg:        Qt.rgba(base01.r, base01.g, base01.b, 0.6)
    readonly property color  ccIconBg:        Qt.rgba(base02.r, base02.g, base02.b, 0.5)
    readonly property int    ccArtSize:       80

    // ── Clipboard ──
    readonly property int    clipWidth:      416
    readonly property int    clipMaxHeight:  464
    readonly property int    clipMaxItems:   30
    readonly property int    clipThumbSize:  48

    // ── App launcher ──
    readonly property int    launchWidth:      504
    readonly property int    launchMaxHeight:  464
    readonly property int    launchIconSize:   32
    readonly property int    launchItemHeight: 40
    readonly property color  scrimColor:       Qt.rgba(0, 0, 0, 0.35)

    // ── Wifi popup ──
    readonly property int    wifiWidth:        296
    readonly property int    wifiMaxHeight:    384
    readonly property int    wifiItemHeight:   40

    // ── Wallpaper selector ──
    readonly property int    wpWidth:          560
    readonly property int    wpMaxHeight:      480
    readonly property int    wpThumbWidth:     160
    readonly property int    wpThumbHeight:    96
    readonly property int    wpSpacing:        8
    readonly property string wpDirectory:      configBase + "/assets/wallpapers"

    // ── Cava / Media popup ──
    readonly property int    cavaWidth:     320
    readonly property int    cavaHeight:    180
    readonly property int    cavaBars:      24
    readonly property int    cavaRadius:    0
    readonly property color  cavaBackground: barBackground
    readonly property color  cavaBarColor:  domainMedia
    readonly property int    cavaArtSize:   48

    // ── Background widgets ──
    readonly property color  widgetBackground:   Qt.rgba(base00.r, base00.g, base00.b, 0.75)
    readonly property color  widgetText:         base06
    readonly property color  widgetTextDimmed:   base04
    readonly property int    widgetRadius:       radiusMedium
    readonly property int    widgetPadding:      16
    readonly property int    widgetShadowRadius: 24
    readonly property color  widgetShadowColor:  Qt.rgba(0, 0, 0, 0.3)

    // Widget edit mode
    readonly property color  editModeBorder:     accentPrimary
    readonly property color  snapIndicatorBg:    Qt.rgba(accentPrimary.r, accentPrimary.g, accentPrimary.b, 0.15)
    readonly property color  snapIndicatorActive: Qt.rgba(accentPrimary.r, accentPrimary.g, accentPrimary.b, 0.4)

    // ── Icons ──
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
    readonly property string iconCaffeine:    "󰛊"
    readonly property string iconCaffeineOff: "󰛩"
    readonly property color  caffeineAccent:  base0A
    readonly property string iconBtOn:        "󰂯"
    readonly property string iconBtOff:       "󰂲"
    readonly property string iconBtConnected: "󰂱"
    readonly property string iconSearch:       "󰍉"
    readonly property string iconLaunch:       "󰍃"
    readonly property string iconWifiLock:     "󰤪"
    readonly property string iconWallpaper:    "󰸉"
    readonly property string iconSkipBack:    "󰒮"
    readonly property string iconSkipFwd:     "󰒭"
    readonly property string iconPlay:        "󰐊"
    readonly property string iconPause:       "󰏤"
    readonly property string iconPrev:      "󰒮"
    readonly property string iconNext:      "󰒭"
    readonly property string iconCC:          "󱊖"
    readonly property string iconLock:      "󰌾"
    readonly property string iconLogout:    "󰍃"
    readonly property string iconSuspend:   "󰤄"
    readonly property string iconReboot:    "󰜉"
    readonly property string iconShutdown:  "󰐥"
    readonly property string iconStockUp:        "󰜷"
    readonly property string iconStockDown:      "󰜮"
    readonly property string iconStock:          "󰄪"
    readonly property string iconWeatherSunny:   "󰖙"
    readonly property string iconWeatherCloudy:  "󰖐"
    readonly property string iconWeatherPartly:  "󰖕"
    readonly property string iconWeatherRain:    "󰖗"
    readonly property string iconWeatherSnow:    "󰖘"
    readonly property string iconWeatherStorm:   "󰖓"
    readonly property string iconWeatherFog:     "󰖑"
    readonly property string iconWeatherNight:   "󰖔"
    readonly property string iconWeatherDefault: "󰖐"
    readonly property string iconUser:           "󰀄"
    readonly property string iconMusic:          "󰎆"
    readonly property string lockBackground:     configBase + "/assets/wallpapers/cloud.jpg"
    readonly property string iconEdit:           "󰏫"
    readonly property string iconSave:           "󰆓"
    readonly property string iconCancel:         "󰅖"
    readonly property string iconDrag:           "󰘕"
    readonly property string iconWidgets:        "󰕰"

    // ── Domain color aliases (used by bar modules and widgets) ──
    // Components use domain* colors directly — these aliases kept for backward compat
    readonly property color powerAccent:   accentDanger
    readonly property color powerSuspend:  accentWarning
    readonly property color powerLock:     domainSettings
    readonly property color barBatteryCharge: accentWarm
    readonly property color barBatteryLow:    accentDanger
    readonly property color widgetStockAccent: base0B

    // ── Icon threshold helpers ──
    // Eliminates duplicated threshold logic in Osd, BatteryModule, AudioModule
    function volumeIcon(vol, muted) {
        if (vol < 0 || muted) return iconVolMute;
        if (vol > 60) return iconVolHigh;
        if (vol > 30) return iconVolMid;
        if (vol > 0) return iconVolLow;
        return iconVolMute;
    }

    function brightnessIcon(pct) {
        if (pct > 66) return iconBriHigh;
        if (pct > 33) return iconBriMid;
        if (pct > 0)  return iconBriLow;
        return iconBriOff;
    }

    function batteryIcon(pct, charging) {
        if (pct < 0) return iconBatNone;
        if (charging) return iconBatChg;
        if (pct > 80) return iconBat100;
        if (pct > 60) return iconBat80;
        if (pct > 40) return iconBat60;
        if (pct > 20) return iconBat40;
        return iconBat20;
    }

    function wifiIcon(service) {
        if (!service || !service.enabled) return iconWifiOff;
        if (!service.connected) return iconWifiMin;
        if (service.iface === "ethernet") return iconEth;
        if (service.signal > 75) return iconWifiHi;
        if (service.signal > 50) return iconWifiMid;
        if (service.signal > 25) return iconWifiLow;
        return iconWifiMin;
    }
}
