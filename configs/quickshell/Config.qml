pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: config

    // ── Bar settings ──
    readonly property QtObject bar: QtObject {
        property bool workspace: true
        property bool time: true
        property bool weather: true
        property bool window: true
        property bool media: true
        property bool resource: true
        property bool audio: true
        property bool network: true
        property bool bluetooth: true
        property bool battery: true

        property var layoutLeft: ["power", "workspace", "time", "weather", "window"]
        property var layoutCenter: ["media"]
        property var layoutRight: ["resource", "audio", "network", "bluetooth", "battery", "tray", "gear"]
    }

    // ── Widget settings ──
    readonly property QtObject widgets: QtObject {
        property bool clock: true
        property bool weather: true
        property bool system: false
        property bool quote: false
        property bool nowPlaying: true
        property bool calendar: true
        property bool stock: false

        property string clockPosition: "bottom-right"
        property string weatherPosition: "top-right"
        property string systemPosition: "top-left"
        property string quotePosition: "bottom-center"
        property string nowPlayingPosition: "bottom-left"
        property string calendarPosition: "center-left"
        property string stockPosition: "center-right"

        property int marginX: 40
        property int marginY: 40
    }

    // ── Feature flags ──
    readonly property QtObject features: QtObject {
        property bool wallpaperWidgets: true
        property bool autoHideWidgets: true
        property bool autoHideBarInFullscreen: true
        property bool mediaPopup: true
        property bool clipboardHistory: true
        property bool wallpaperSelector: true
    }

    // ── Behavior settings ──
    readonly property QtObject behavior: QtObject {
        property int weatherUpdateInterval: 900000
        property int systemStatsInterval: 3000
        property int notificationTimeout: 5000
        property int maxClipboardItems: 30
    }

    // ── Per-widget config ──
    readonly property QtObject clockConfig: QtObject {
        property string timeFormat: "HH:mm"
        property string dateFormat: "dddd, MMMM d"
        property bool showDate: true
        property bool showSeconds: false
        property int fontSize: 48
    }

    readonly property QtObject weatherConfig: QtObject {
        property bool useMetric: true
        property int fontSize: 32
    }

    readonly property QtObject systemConfig: QtObject {
        property bool showCpu: true
        property bool showRam: true
        property int fontSize: 24
    }

    readonly property QtObject quoteConfig: QtObject {
        property int maxWidth: 400
        property int fontSize: 16
        property int refreshInterval: 3600000
    }

    readonly property QtObject nowPlayingConfig: QtObject {
        property bool showArt: true
        property int artSize: 80
        property int fontSize: 14
    }

    readonly property QtObject calendarConfig: QtObject {
        property bool showWeekNumbers: false
        property int cellSize: 28
    }

    readonly property QtObject stockConfig: QtObject {
        property var symbols: ["SPY", "QQQ", "AAPL"]
        property int fontSize: 14
        property int refreshInterval: 300000
    }

    // ── Default layout order (mirrors Registry.barModules) ──
    readonly property var _defaultLayoutLeft: ["power", "workspace", "time", "weather", "window"]
    readonly property var _defaultLayoutCenter: ["media"]
    readonly property var _defaultLayoutRight: ["resource", "audio", "network", "bluetooth", "battery", "tray", "gear"]

    function _getDefaultOrder(section) {
        if (section === "left" || section === "layoutLeft") return _defaultLayoutLeft;
        if (section === "center" || section === "layoutCenter") return _defaultLayoutCenter;
        if (section === "right" || section === "layoutRight") return _defaultLayoutRight;
        return [];
    }

    // ── Helper functions for Settings panel ──
    function isBarModuleEnabled(key) {
        return bar.layoutLeft.indexOf(key) >= 0
            || bar.layoutCenter.indexOf(key) >= 0
            || bar.layoutRight.indexOf(key) >= 0;
    }

    function toggleBarModule(key, defaultSection) {
        let sections = ["layoutLeft", "layoutCenter", "layoutRight"];
        for (let s of sections) {
            let arr = bar[s];
            let idx = arr.indexOf(key);
            if (idx >= 0) {
                arr.splice(idx, 1);
                bar[s] = [...arr];
                save();
                return;
            }
        }
        // Re-enable: insert at correct position based on default order
        let target = "layout" + defaultSection.charAt(0).toUpperCase() + defaultSection.slice(1);
        let arr = bar[target];
        let defaultOrder = _getDefaultOrder(target);
        let defaultIdx = defaultOrder.indexOf(key);
        let insertIdx = arr.length;
        for (let i = 0; i < arr.length; i++) {
            let existingDefaultIdx = defaultOrder.indexOf(arr[i]);
            if (existingDefaultIdx > defaultIdx) {
                insertIdx = i;
                break;
            }
        }
        arr.splice(insertIdx, 0, key);
        bar[target] = [...arr];
        save();
    }

    function toggleWidget(configKey) {
        widgets[configKey] = !widgets[configKey];
        save();
    }

    function reorderBarModule(key, section, newIndex) {
        let prop = "layout" + section.charAt(0).toUpperCase() + section.slice(1);
        let arr = bar[prop].slice();
        let oldIndex = arr.indexOf(key);
        if (oldIndex >= 0) arr.splice(oldIndex, 1);
        arr.splice(Math.min(newIndex, arr.length), 0, key);
        bar[prop] = arr;
        save();
    }

    // ══════════════════════════════════════════════════════════════════
    // ── Backward-compatible flat aliases ──
    // (Consumers can migrate to nested form over time)
    // ══════════════════════════════════════════════════════════════════

    // Bar module toggles
    readonly property bool enableWorkspaceModule: bar.workspace
    readonly property bool enableTimeModule: bar.time
    readonly property bool enableWeatherModule: bar.weather
    readonly property bool enableWindowModule: bar.window
    readonly property bool enableMediaModule: bar.media
    readonly property bool enableResourceModule: bar.resource
    readonly property bool enableAudioModule: bar.audio
    readonly property bool enableNetworkModule: bar.network
    readonly property bool enableBluetoothModule: bar.bluetooth
    readonly property bool enableBatteryModule: bar.battery

    // Widget visibility
    readonly property bool showClockWidget: widgets.clock
    readonly property bool showWeatherWidget: widgets.weather
    readonly property bool showSystemWidget: widgets.system
    readonly property bool showQuoteWidget: widgets.quote
    readonly property bool showNowPlayingWidget: widgets.nowPlaying
    readonly property bool showCalendarWidget: widgets.calendar
    readonly property bool showStockWidget: widgets.stock

    // Widget positions
    readonly property string clockWidgetPosition: widgets.clockPosition
    readonly property string weatherWidgetPosition: widgets.weatherPosition
    readonly property string systemWidgetPosition: widgets.systemPosition
    readonly property string quoteWidgetPosition: widgets.quotePosition
    readonly property string nowPlayingWidgetPosition: widgets.nowPlayingPosition
    readonly property string calendarWidgetPosition: widgets.calendarPosition
    readonly property string stockWidgetPosition: widgets.stockPosition

    // Widget margins
    readonly property int widgetMarginX: widgets.marginX
    readonly property int widgetMarginY: widgets.marginY

    // Feature flags
    readonly property bool enableWallpaperWidgets: features.wallpaperWidgets
    readonly property bool autoHideWidgets: features.autoHideWidgets
    readonly property bool autoHideBarInFullscreen: features.autoHideBarInFullscreen
    readonly property bool enableMediaPopup: features.mediaPopup
    readonly property bool enableClipboardHistory: features.clipboardHistory
    readonly property bool enableWallpaperSelector: features.wallpaperSelector

    // Behavior
    readonly property int weatherUpdateInterval: behavior.weatherUpdateInterval
    readonly property int systemStatsInterval: behavior.systemStatsInterval
    readonly property int notificationTimeout: behavior.notificationTimeout
    readonly property int maxClipboardItems: behavior.maxClipboardItems

    // Clock widget
    readonly property string clockTimeFormat: clockConfig.timeFormat
    readonly property string clockDateFormat: clockConfig.dateFormat
    readonly property bool clockShowDate: clockConfig.showDate
    readonly property bool clockShowSeconds: clockConfig.showSeconds
    readonly property int clockFontSize: clockConfig.fontSize

    // Weather widget
    readonly property bool weatherUseMetric: weatherConfig.useMetric
    readonly property int weatherFontSize: weatherConfig.fontSize

    // System widget
    readonly property bool systemShowCpu: systemConfig.showCpu
    readonly property bool systemShowRam: systemConfig.showRam
    readonly property int systemFontSize: systemConfig.fontSize

    // Quote widget
    readonly property int quoteMaxWidth: quoteConfig.maxWidth
    readonly property int quoteFontSize: quoteConfig.fontSize
    readonly property int quoteRefreshInterval: quoteConfig.refreshInterval

    // Now Playing widget
    readonly property bool nowPlayingShowArt: nowPlayingConfig.showArt
    readonly property int nowPlayingArtSize: nowPlayingConfig.artSize
    readonly property int nowPlayingFontSize: nowPlayingConfig.fontSize

    // Calendar widget
    readonly property bool calendarShowWeekNumbers: calendarConfig.showWeekNumbers
    readonly property int calendarCellSize: calendarConfig.cellSize

    // Stock widget
    readonly property var stockSymbols: stockConfig.symbols
    readonly property int stockFontSize: stockConfig.fontSize
    readonly property int stockRefreshInterval: stockConfig.refreshInterval

    // ══════════════════════════════════════════════════════════════════
    // ── JSON persistence ──
    // ══════════════════════════════════════════════════════════════════

    readonly property string _configPath: Quickshell.env("HOME") + "/.config/quickshell/config.json"

    function load() {
        _loadProc.running = true;
    }

    function save() {
        let data = {
            bar: {
                workspace: bar.workspace, time: bar.time, weather: bar.weather,
                window: bar.window, media: bar.media, resource: bar.resource,
                audio: bar.audio, network: bar.network, bluetooth: bar.bluetooth,
                battery: bar.battery,
                layoutLeft: bar.layoutLeft, layoutCenter: bar.layoutCenter,
                layoutRight: bar.layoutRight
            },
            widgets: {
                clock: widgets.clock, weather: widgets.weather, system: widgets.system,
                quote: widgets.quote, nowPlaying: widgets.nowPlaying,
                calendar: widgets.calendar, stock: widgets.stock,
                clockPosition: widgets.clockPosition, weatherPosition: widgets.weatherPosition,
                systemPosition: widgets.systemPosition, quotePosition: widgets.quotePosition,
                nowPlayingPosition: widgets.nowPlayingPosition,
                calendarPosition: widgets.calendarPosition, stockPosition: widgets.stockPosition,
                marginX: widgets.marginX, marginY: widgets.marginY
            },
            features: {
                wallpaperWidgets: features.wallpaperWidgets,
                autoHideWidgets: features.autoHideWidgets,
                autoHideBarInFullscreen: features.autoHideBarInFullscreen,
                mediaPopup: features.mediaPopup,
                clipboardHistory: features.clipboardHistory,
                wallpaperSelector: features.wallpaperSelector
            },
            clock: { timeFormat: clockConfig.timeFormat, dateFormat: clockConfig.dateFormat,
                     showDate: clockConfig.showDate, showSeconds: clockConfig.showSeconds,
                     fontSize: clockConfig.fontSize },
            weather: { useMetric: weatherConfig.useMetric, fontSize: weatherConfig.fontSize },
            system: { showCpu: systemConfig.showCpu, showRam: systemConfig.showRam,
                      fontSize: systemConfig.fontSize },
            quote: { maxWidth: quoteConfig.maxWidth, fontSize: quoteConfig.fontSize,
                     refreshInterval: quoteConfig.refreshInterval },
            nowPlaying: { showArt: nowPlayingConfig.showArt, artSize: nowPlayingConfig.artSize,
                          fontSize: nowPlayingConfig.fontSize },
            calendar: { showWeekNumbers: calendarConfig.showWeekNumbers,
                        cellSize: calendarConfig.cellSize },
            stock: { symbols: stockConfig.symbols, fontSize: stockConfig.fontSize,
                     refreshInterval: stockConfig.refreshInterval }
        };
        let json = JSON.stringify(data, null, 2);
        _saveProc.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"",
            "--", _configPath, json];
        _saveProc.running = true;
    }

    function _applyJson(json) {
        try {
            let d = JSON.parse(json);

            // Bar
            if (d.bar) {
                let b = d.bar;
                if (b.workspace !== undefined) bar.workspace = b.workspace;
                if (b.time !== undefined) bar.time = b.time;
                if (b.weather !== undefined) bar.weather = b.weather;
                if (b.window !== undefined) bar.window = b.window;
                if (b.media !== undefined) bar.media = b.media;
                if (b.resource !== undefined) bar.resource = b.resource;
                if (b.audio !== undefined) bar.audio = b.audio;
                if (b.network !== undefined) bar.network = b.network;
                if (b.bluetooth !== undefined) bar.bluetooth = b.bluetooth;
                if (b.battery !== undefined) bar.battery = b.battery;
                if (b.layoutLeft !== undefined) bar.layoutLeft = b.layoutLeft;
                if (b.layoutCenter !== undefined) bar.layoutCenter = b.layoutCenter;
                if (b.layoutRight !== undefined) bar.layoutRight = b.layoutRight;
            }

            // Widgets
            if (d.widgets) {
                let w = d.widgets;
                if (w.clock !== undefined) widgets.clock = w.clock;
                if (w.weather !== undefined) widgets.weather = w.weather;
                if (w.system !== undefined) widgets.system = w.system;
                if (w.quote !== undefined) widgets.quote = w.quote;
                if (w.nowPlaying !== undefined) widgets.nowPlaying = w.nowPlaying;
                if (w.calendar !== undefined) widgets.calendar = w.calendar;
                if (w.stock !== undefined) widgets.stock = w.stock;
                if (w.clockPosition !== undefined) widgets.clockPosition = w.clockPosition;
                if (w.weatherPosition !== undefined) widgets.weatherPosition = w.weatherPosition;
                if (w.systemPosition !== undefined) widgets.systemPosition = w.systemPosition;
                if (w.quotePosition !== undefined) widgets.quotePosition = w.quotePosition;
                if (w.nowPlayingPosition !== undefined) widgets.nowPlayingPosition = w.nowPlayingPosition;
                if (w.calendarPosition !== undefined) widgets.calendarPosition = w.calendarPosition;
                if (w.stockPosition !== undefined) widgets.stockPosition = w.stockPosition;
                if (w.marginX !== undefined) widgets.marginX = w.marginX;
                if (w.marginY !== undefined) widgets.marginY = w.marginY;
            }

            // Features
            if (d.features) {
                let f = d.features;
                if (f.wallpaperWidgets !== undefined) features.wallpaperWidgets = f.wallpaperWidgets;
                if (f.autoHideWidgets !== undefined) features.autoHideWidgets = f.autoHideWidgets;
                if (f.autoHideBarInFullscreen !== undefined) features.autoHideBarInFullscreen = f.autoHideBarInFullscreen;
                if (f.mediaPopup !== undefined) features.mediaPopup = f.mediaPopup;
                if (f.clipboardHistory !== undefined) features.clipboardHistory = f.clipboardHistory;
                if (f.wallpaperSelector !== undefined) features.wallpaperSelector = f.wallpaperSelector;
            }

            // Per-widget configs
            if (d.clock) {
                let c = d.clock;
                if (c.timeFormat !== undefined) clockConfig.timeFormat = c.timeFormat;
                if (c.dateFormat !== undefined) clockConfig.dateFormat = c.dateFormat;
                if (c.showDate !== undefined) clockConfig.showDate = c.showDate;
                if (c.showSeconds !== undefined) clockConfig.showSeconds = c.showSeconds;
                if (c.fontSize !== undefined && c.fontSize > 0) clockConfig.fontSize = c.fontSize;
            }
            if (d.weather) {
                if (d.weather.useMetric !== undefined) weatherConfig.useMetric = d.weather.useMetric;
                if (d.weather.fontSize !== undefined && d.weather.fontSize > 0) weatherConfig.fontSize = d.weather.fontSize;
            }
            if (d.system) {
                if (d.system.showCpu !== undefined) systemConfig.showCpu = d.system.showCpu;
                if (d.system.showRam !== undefined) systemConfig.showRam = d.system.showRam;
                if (d.system.fontSize !== undefined && d.system.fontSize > 0) systemConfig.fontSize = d.system.fontSize;
            }
            if (d.quote) {
                if (d.quote.maxWidth !== undefined) quoteConfig.maxWidth = d.quote.maxWidth;
                if (d.quote.fontSize !== undefined) quoteConfig.fontSize = d.quote.fontSize;
                if (d.quote.refreshInterval !== undefined) quoteConfig.refreshInterval = d.quote.refreshInterval;
            }
            if (d.nowPlaying) {
                if (d.nowPlaying.showArt !== undefined) nowPlayingConfig.showArt = d.nowPlaying.showArt;
                if (d.nowPlaying.artSize !== undefined && d.nowPlaying.artSize > 0) nowPlayingConfig.artSize = d.nowPlaying.artSize;
                if (d.nowPlaying.fontSize !== undefined) nowPlayingConfig.fontSize = d.nowPlaying.fontSize;
            }
            if (d.calendar) {
                if (d.calendar.showWeekNumbers !== undefined) calendarConfig.showWeekNumbers = d.calendar.showWeekNumbers;
                if (d.calendar.cellSize !== undefined) calendarConfig.cellSize = d.calendar.cellSize;
            }
            if (d.stock) {
                if (d.stock.symbols !== undefined) stockConfig.symbols = d.stock.symbols;
                if (d.stock.fontSize !== undefined) stockConfig.fontSize = d.stock.fontSize;
                if (d.stock.refreshInterval !== undefined) stockConfig.refreshInterval = d.stock.refreshInterval;
            }
        } catch(e) {
            console.log("Config: failed to parse JSON:", e);
        }
    }

    property var _loadProc: Process {
        property string _buf: ""
        command: ["cat", config._configPath]
        stdout: SplitParser {
            onRead: line => { _loadProc._buf += line + "\n"; }
        }
        onExited: (code) => {
            if (code === 0 && _loadProc._buf.trim() !== "") {
                config._applyJson(_loadProc._buf);
            }
            _loadProc._buf = "";
        }
    }

    property var _saveProc: Process {}

    Component.onCompleted: load()
}
