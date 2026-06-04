pragma Singleton
import QtQuick
import Quickshell
import "." as Root

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
    // Translucent surface for frosted-glass UI chrome (when the compositor
    // blurs the layer behind it); reads as a dim panel without blur.
    readonly property color glassBackground: Qt.rgba(base00.r, base00.g, base00.b, 0.6)
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
    readonly property color accentPrimary:   base0F
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

    // ══════════════════════════════════════════════════════════════════
    // ── UI scale ──
    // Global UI-size multiplier (a user preference, independent of the
    // compositor's per-output scale). Every size / spacing / radius / font
    // token below is `scaled(base)` = round(base × uiScaleRatio), so changing
    // Config.appearance.uiScale live re-flows the whole shell. 1.0 = native.
    // ══════════════════════════════════════════════════════════════════
    readonly property real uiScaleRatio: {
        const s = Root.Config.appearance.uiScale;
        return (typeof s === "number" && s > 0) ? s : 1.0;
    }
    function scaled(px) {
        return Math.round(px * uiScaleRatio);
    }

    // ── Grid System ──
    readonly property int unit: scaled(8)

    // ── Spacing scale (px @ uiScaleRatio = 1; built on the 8pt unit) ──
    // Prefer these over literal margins / spacing / padding.
    readonly property int spacingXS:  scaled(4)
    readonly property int spacingS:   scaled(8)
    readonly property int spacingM:   scaled(12)
    readonly property int spacingL:   scaled(16)
    readonly property int spacingXL:  scaled(24)
    readonly property int spacing2XL: scaled(32)
    readonly property int spacing3XL: scaled(48)

    // ── Typography ──
    readonly property string fontFamily:  "Hanken Grotesk"   // UI / body text
    readonly property string fontMono:    "Maple Mono NF"    // data / tabular (bar)
    readonly property string fontIcons:   "Maple Mono NF"    // Nerd Font glyphs
    readonly property string fontDisplay: "Fraunces"         // large display moments
    // Type scale (px @ uiScaleRatio = 1) — prefer these over literal pixelSize.
    readonly property int    fontSizeXXS:  scaled(9)
    readonly property int    fontSizeXS:   scaled(10)
    readonly property int    fontSizeS:    scaled(11)
    readonly property int    fontSizeM:    scaled(12)
    readonly property int    fontSizeL:    scaled(13)
    readonly property int    fontSizeXL:   scaled(14)
    readonly property int    fontSize2XL:  scaled(16)
    readonly property int    fontSize3XL:  scaled(18)
    readonly property int    fontSize4XL:  scaled(22)
    readonly property int    fontSize5XL:  scaled(28)
    readonly property int    iconSize:     scaled(16)
    readonly property bool   fontBold:     false
    // Legacy aliases — keep existing call sites + the font objects below working
    readonly property int    fontSize:      fontSizeS    // 11
    readonly property int    fontSizeSmall: fontSizeXXS  // 9
    readonly property int    fontSizeLarge: fontSizeL    // 13
    // Display sizes for hero text (lock clock, modal titles). Wrapped in
    // scaled() so they honour uiScale — literal 72/48 px did not.
    readonly property int    fontSizeDisplay: scaled(48)
    readonly property int    fontSizeHero:    scaled(72)

    // ── Weight scale ── Hanken Grotesk & Fraunces are variable fonts, so
    // prefer these over `bold: true` for finer hierarchy on labels/headers.
    readonly property int weightRegular:  Font.Normal
    readonly property int weightMedium:   Font.Medium
    readonly property int weightSemiBold: Font.DemiBold
    readonly property int weightBold:     Font.Bold

    // ── Tracking (letter-spacing, px) ── prefer over ad-hoc literals.
    // All-caps eyebrow labels need positive tracking to breathe.
    readonly property real trackingCaps: 1.5
    readonly property real trackingWide: 1.0

    // ── Line height (multiplier) ── for wrapping body / quote text;
    // Qt's default (~1.2) reads cramped for multi-line copy.
    readonly property real lineHeightBody:  1.4
    readonly property real lineHeightQuote: 1.6

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

    // ── Borders ── (kept at native px for crisp 1px lines regardless of scale)
    readonly property int   borderWidth:      1
    readonly property int   borderWidthThick: 2
    readonly property color borderColor:      base03
    readonly property color borderActive:     accentPrimary
    readonly property color borderFocus:      accentSecondary

    // ── Radius ──
    readonly property int radiusSmall:  scaled(4)
    readonly property int radiusMedium: scaled(8)
    readonly property int radiusLarge:  scaled(12)

    // ── Spacing ──
    readonly property int ccItemPadding: scaled(12)
    readonly property int ccItemSpacing: scaled(6)

    // ── Bar geometry ──
    readonly property int barHeight:  scaled(32)
    readonly property int barPadding: scaled(14)
    readonly property int barSpacing: scaled(8)

    // ── OSD geometry ──
    readonly property int    osdWidth:    scaled(256)
    readonly property int    osdHeight:   scaled(48)
    readonly property int    osdIconSize: scaled(20)
    readonly property int    osdFontSize: scaled(11)
    readonly property int    osdRadius:   scaled(16)
    readonly property int    osdTimeout:  1500
    readonly property int    osdFadeMs:   200
    readonly property color  osdBackground: base01
    readonly property color  osdAccent:     domainMedia
    readonly property color  osdBarBg:      base02

    // ── Notifications ──
    readonly property int    notifWidth:       scaled(360)
    readonly property int    notifMaxVisible:  5
    readonly property int    notifTimeout:     5000
    readonly property int    notifRadius:      scaled(6)
    readonly property int    notifSpacing:     scaled(8)
    readonly property int    notifPadding:     scaled(14)
    readonly property int    notifMarginTop:   scaled(8)
    readonly property int    notifMarginRight: scaled(8)
    readonly property int    notifTitleSize:   scaled(12)
    readonly property int    notifBodySize:    scaled(11)
    readonly property int    notifIconSize:    scaled(32)
    readonly property color  notifBackground:  base01
    readonly property color  notifTitle:       base06
    readonly property color  notifBody:        base04
    readonly property color  notifAccent:      domainNotifications
    readonly property color  notifAppName:     domainNotifications
    readonly property color  notifBorder:      domainNotifications
    readonly property color  notifUrgentBorder: accentDanger
    readonly property color  notifLowBorder:   base03
    readonly property color  selectionBg:      base02
    readonly property int    notifHistWidth:    scaled(384)
    readonly property int    notifHistMaxHeight: scaled(512)
    readonly property color  notifItemBg:     Qt.rgba(base01.r, base01.g, base01.b, 0.4)
    readonly property color  notifSubItemBg:  Qt.rgba(base01.r, base01.g, base01.b, 0.2)

    // ── Control Center ──
    readonly property int    ccWidth:         scaled(384)
    readonly property int    ccPadding:       scaled(12)
    readonly property int    ccSectionRadius: scaled(8)
    readonly property color  ccSectionBg:     base01
    readonly property color  ccCardBg:        Qt.rgba(base01.r, base01.g, base01.b, 0.6)
    readonly property color  ccIconBg:        Qt.rgba(base02.r, base02.g, base02.b, 0.5)
    readonly property int    ccArtSize:       scaled(80)

    // ── Clipboard ──
    readonly property int    clipWidth:      scaled(416)
    readonly property int    clipMaxHeight:  scaled(464)
    readonly property int    clipMaxItems:   30
    readonly property int    clipThumbSize:  scaled(48)

    // ── App launcher ──
    readonly property int    launchWidth:      scaled(504)
    readonly property int    launchMaxHeight:  scaled(464)
    readonly property int    launchIconSize:   scaled(32)
    readonly property int    launchItemHeight: scaled(40)
    readonly property color  scrimColor:       Qt.rgba(0, 0, 0, 0.35)

    // ── Wifi popup ──
    readonly property int    wifiWidth:        scaled(296)
    readonly property int    wifiMaxHeight:    scaled(384)
    readonly property int    wifiItemHeight:   scaled(40)

    // ── Wallpaper selector ──
    readonly property int    wpWidth:          scaled(560)
    readonly property int    wpMaxHeight:      scaled(480)
    readonly property int    wpThumbWidth:     scaled(160)
    readonly property int    wpThumbHeight:    scaled(96)
    readonly property int    wpSpacing:        scaled(8)
    readonly property string wpDirectory:      configBase + "/assets/wallpapers"

    // ── Cava / Media popup ──
    readonly property int    cavaWidth:     scaled(320)
    readonly property int    cavaHeight:    scaled(180)
    readonly property int    cavaBars:      24
    readonly property int    cavaRadius:    0
    readonly property color  cavaBackground: barBackground
    readonly property color  cavaBarColor:  domainMedia
    readonly property int    cavaArtSize:   scaled(48)

    // ── Background widgets ──
    readonly property color  widgetBackground:   Qt.rgba(base00.r, base00.g, base00.b, 0.5)
    readonly property color  widgetBackgroundSolid: Qt.rgba(base00.r, base00.g, base00.b, 0.92)
    readonly property color  widgetText:         base07
    readonly property color  widgetTextDimmed:   base04
    readonly property int    widgetRadius:       radiusMedium
    readonly property int    widgetPadding:      scaled(16)
    readonly property int    widgetShadowRadius: scaled(24)
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
