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

        // Bar style: "flat" (default, hugs screen edge) or "float" (floating with margin + rounded)
        property string style: "flat"
        // Whether to show grouped backgrounds behind module groups
        property bool showGroups: false
        // Show CPU sparkline graph in resource module
        property bool showCpuGraph: true

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

    // Remembers where a module was before disabling, so re-enable restores it
    property var _disabledPositions: ({})

    function toggleBarModule(key, defaultSection) {
        let sections = ["layoutLeft", "layoutCenter", "layoutRight"];
        // ── Disable: remove from current section, remember position ──
        for (let s of sections) {
            let arr = bar[s];
            let idx = arr.indexOf(key);
            if (idx >= 0) {
                _disabledPositions[key] = { section: s, index: idx };
                arr.splice(idx, 1);
                bar[s] = [...arr];
                save();
                return;
            }
        }
        // ── Enable: restore to remembered position, or fall back to default ──
        let remembered = _disabledPositions[key];
        let target, insertIdx;
        if (remembered) {
            target = remembered.section;
            insertIdx = Math.min(remembered.index, bar[target].length);
            delete _disabledPositions[key];
        } else {
            target = "layout" + defaultSection.charAt(0).toUpperCase() + defaultSection.slice(1);
            let arr = bar[target];
            let defaultOrder = _getDefaultOrder(target);
            let defaultIdx = defaultOrder.indexOf(key);
            insertIdx = arr.length;
            for (let i = 0; i < arr.length; i++) {
                let existingDefaultIdx = defaultOrder.indexOf(arr[i]);
                if (existingDefaultIdx > defaultIdx) {
                    insertIdx = i;
                    break;
                }
            }
        }
        let arr = bar[target];
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
    // ── JSON persistence ──
    // ══════════════════════════════════════════════════════════════════

    readonly property string _configPath: Quickshell.env("HOME") + "/.config/quickshell/config.json"

    // Section mapping: JSON key → QtObject
    readonly property var _sections: ({
        bar: bar, widgets: widgets, features: features, behavior: behavior,
        clock: clockConfig, weather: weatherConfig, system: systemConfig,
        quote: quoteConfig, nowPlaying: nowPlayingConfig,
        calendar: calendarConfig, stock: stockConfig
    })

    function load() {
        _loadProc.running = true;
    }

    function save() {
        let data = {};
        for (let key in _sections) {
            let src = _sections[key];
            let obj = {};
            for (let prop in src) {
                // Skip QtObject internals, signals, and functions
                if (prop === "objectName" || prop.endsWith("Changed") || prop.startsWith("_")
                    || typeof src[prop] === "function"
                    || (typeof src[prop] === "object" && src[prop] !== null && !(src[prop] instanceof Array)))
                    continue;
                obj[prop] = src[prop];
            }
            data[key] = obj;
        }
        let json = JSON.stringify(data, null, 2);
        _saveProc.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"",
            "--", _configPath, json];
        _saveProc.running = true;
    }

    function _applyJson(json) {
        try {
            let d = JSON.parse(json);
            for (let key in _sections) {
                if (!d[key]) continue;
                let target = _sections[key];
                for (let prop in d[key]) {
                    if (target[prop] !== undefined) target[prop] = d[key][prop];
                }
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
