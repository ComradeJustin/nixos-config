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

    readonly property string lockBackground: configBase + "/assets/wallpapers/cloud.jpg"

    // ── Domain color aliases ──
    readonly property color caffeineAccent:    base0A
    readonly property color powerAccent:       accentDanger
    readonly property color powerSuspend:      accentWarning
    readonly property color powerLock:         domainSettings
    readonly property color barBatteryCharge:  accentWarm
    readonly property color barBatteryLow:     accentDanger
    readonly property color widgetStockAccent: base0B

    // ── Layered elevation colors (surface → overlay depth) ──
    readonly property color layer0: base00                                                  // Base surface
    readonly property color layer1: base01                                                  // Cards, panels
    readonly property color layer2: base02                                                  // Raised elements
    readonly property color layer3: base03                                                  // Floating, popovers
    readonly property color layer0Hover: Qt.rgba(base05.r, base05.g, base05.b, 0.06)       // Hover on base
    readonly property color layer1Hover: Qt.rgba(base05.r, base05.g, base05.b, 0.08)       // Hover on cards
    readonly property color layer2Hover: Qt.rgba(base05.r, base05.g, base05.b, 0.10)       // Hover on raised
    readonly property color layerActive: Qt.rgba(base05.r, base05.g, base05.b, 0.14)       // Active/pressed state
    readonly property color layerDisabled: Qt.rgba(base05.r, base05.g, base05.b, 0.04)     // Disabled state

    // ── Animation presets ──
    // Standard motion: most UI transitions
    readonly property int animFast:       150
    readonly property int animNormal:     250
    readonly property int animSlow:       400
    readonly property int animExpressive: 500

    // Named animation presets (duration + easing pairs)
    readonly property QtObject anim: QtObject {
        // Micro-interactions: hover, color shifts, opacity changes
        readonly property int microDuration: 120
        readonly property int microEasing: Easing.OutCubic

        // Element movement: slides, position changes
        readonly property int moveDuration: 250
        readonly property int moveEasing: Easing.OutCubic

        // Entrance animations: appear, scale in
        readonly property int enterDuration: 300
        readonly property int enterEasing: Easing.OutCubic

        // Exit animations: disappear, scale out
        readonly property int exitDuration: 200
        readonly property int exitEasing: Easing.InCubic

        // Expressive: bouncy, playful (for modals, popups)
        readonly property int bounceDuration: 350
        readonly property int bounceEasing: Easing.OutBack

        // Resize: layout changes, width/height transitions
        readonly property int resizeDuration: 200
        readonly property int resizeEasing: Easing.InOutCubic

        // Spring-like: for drag snap-back, elastic feel
        readonly property int springDuration: 400
        readonly property int springEasing: Easing.OutElastic

        // Slide panel: for CC, sidebars
        readonly property int slideDuration: 300
        readonly property int slideEasing: Easing.OutCubic

        // Scroll: smooth scroll transitions
        readonly property int scrollDuration: 200
        readonly property int scrollEasing: Easing.OutQuad
    }
}
