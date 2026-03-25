pragma Singleton
import QtQuick
import Quickshell

// ── Configuration Singleton ──
// User-configurable settings for QuickShell.
// Edit these properties to customize behavior without modifying module code.
// Future: Load from JSON file for persistence.
QtObject {
    // ══════════════════════════════════════════════════════════════════
    // ── Wallpaper Widget Settings ──
    // ══════════════════════════════════════════════════════════════════

    // Widget visibility toggles
    property bool showClockWidget: true
    property bool showWeatherWidget: true
    property bool showSystemWidget: true
    property bool showQuoteWidget: false
    property bool showNowPlayingWidget: true
    property bool showCalendarWidget: true
    property bool showStockWidget: true

    // Widget positions: "top-left", "top-center", "top-right",
    //                   "center-left", "center", "center-right",
    //                   "bottom-left", "bottom-center", "bottom-right"
    property string clockWidgetPosition: "bottom-right"
    property string weatherWidgetPosition: "top-right"
    property string systemWidgetPosition: "top-left"
    property string quoteWidgetPosition: "bottom-center"
    property string nowPlayingWidgetPosition: "bottom-left"
    property string calendarWidgetPosition: "center-left"
    property string stockWidgetPosition: "center-right"

    // Widget margins from screen edge
    property int widgetMarginX: 40
    property int widgetMarginY: 40

    // ══════════════════════════════════════════════════════════════════
    // ── Bar Module Settings ──
    // ══════════════════════════════════════════════════════════════════

    // Enable/disable specific bar modules
    property bool enableWorkspaceModule: true
    property bool enableTimeModule: true
    property bool enableWeatherModule: true
    property bool enableWindowModule: true
    property bool enableMediaModule: true
    property bool enableResourceModule: true
    property bool enableAudioModule: true
    property bool enableNetworkModule: true
    property bool enableBluetoothModule: true
    property bool enableBatteryModule: true

    // ══════════════════════════════════════════════════════════════════
    // ── Feature Flags ──
    // ══════════════════════════════════════════════════════════════════

    // Enable wallpaper widgets overlay system
    property bool enableWallpaperWidgets: true

    // Auto-hide widgets when windows are present on workspace
    property bool autoHideWidgets: true

    // Auto-hide bar in fullscreen mode
    property bool autoHideBarInFullscreen: true

    // Show media popup on hover/click
    property bool enableMediaPopup: true

    // Enable clipboard history in Spotlight
    property bool enableClipboardHistory: true

    // Enable wallpaper selector in Spotlight
    property bool enableWallpaperSelector: true

    // ══════════════════════════════════════════════════════════════════
    // ── Behavior Settings ──
    // ══════════════════════════════════════════════════════════════════

    // Weather update interval in milliseconds (default: 15 minutes)
    property int weatherUpdateInterval: 900000

    // System stats polling interval in milliseconds (default: 3 seconds)
    property int systemStatsInterval: 3000

    // Notification popup timeout in milliseconds
    property int notificationTimeout: 5000

    // Maximum clipboard history items
    property int maxClipboardItems: 30

    // ══════════════════════════════════════════════════════════════════
    // ── Clock Widget Settings ──
    // ══════════════════════════════════════════════════════════════════

    // Time format: "HH:mm" for 24-hour, "hh:mm AP" for 12-hour
    property string clockTimeFormat: "HH:mm"

    // Date format: "dddd, MMMM d" for "Monday, January 1"
    property string clockDateFormat: "dddd, MMMM d"

    // Show date under time
    property bool clockShowDate: true

    // Show seconds in time
    property bool clockShowSeconds: false

    // Clock font size (pixels)
    property int clockFontSize: 48

    // ══════════════════════════════════════════════════════════════════
    // ── Weather Widget Settings ──
    // ══════════════════════════════════════════════════════════════════

    property bool weatherUseMetric: true
    property int weatherFontSize: 32

    // ══════════════════════════════════════════════════════════════════
    // ── System Widget Settings ──
    // ══════════════════════════════════════════════════════════════════

    property bool systemShowCpu: true
    property bool systemShowRam: true
    property int systemFontSize: 24

    // ══════════════════════════════════════════════════════════════════
    // ── Quote Widget Settings ──
    // ══════════════════════════════════════════════════════════════════

    property int quoteMaxWidth: 400
    property int quoteFontSize: 16
    property int quoteRefreshInterval: 3600000  // 1 hour in ms

    // ══════════════════════════════════════════════════════════════════
    // ── Now Playing Widget Settings ──
    // ══════════════════════════════════════════════════════════════════

    property bool nowPlayingShowArt: true
    property int nowPlayingArtSize: 80
    property int nowPlayingFontSize: 14

    // ══════════════════════════════════════════════════════════════════
    // ── Calendar Widget Settings ──
    // ══════════════════════════════════════════════════════════════════

    property bool calendarShowWeekNumbers: false
    property int calendarCellSize: 28

    // ══════════════════════════════════════════════════════════════════
    // ── Stock Widget Settings ──
    // ══════════════════════════════════════════════════════════════════

    // Comma-separated stock symbols to track
    property var stockSymbols: ["SPY", "QQQ", "AAPL"]

    // Font size for stock ticker text
    property int stockFontSize: 14

    // Refresh interval in milliseconds (default: 5 minutes)
    property int stockRefreshInterval: 300000
}
