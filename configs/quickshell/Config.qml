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
        property bool inputMethod: true

        // Bar style: "flat" (default, hugs screen edge) or "float" (floating with margin + rounded)
        property string style: "flat"
        // Whether to show grouped backgrounds behind module groups
        property bool showGroups: false
        // Show CPU sparkline graph in resource module
        property bool showCpuGraph: true
        // Show the Caffeine bar module even when idle inhibit is off (default
        // behavior is to only render it while caffeine is active, saving space)
        property bool showCaffeineWhenOff: false

        property var layoutLeft: ["power", "workspace", "time", "weather", "window"]
        property var layoutCenter: ["media"]
        property var layoutRight: ["resource", "audio", "network", "bluetooth", "vpn", "inputMethod", "battery", "caffeine", "tray", "gear"]
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

    // ── Control Center settings ──
    // Scaffolding for pluggable CC cards. `cards` holds per-card enables,
    // `cardLayout` is the ordered list of keys the CC will render (in order).
    // Both are consumed via Core.Registry.ccCards for component resolution.
    readonly property QtObject cc: QtObject {
        readonly property QtObject cards: QtObject {
            property bool profile: true
            property bool network: true
            property bool bluetooth: false
            property bool nightLight: false
            property bool player: true
            property bool systemMonitor: true
            property bool weather: true
            property bool calendar: true
            property bool serverStatus: true
        }
        property var cardLayout: ["profile", "player", "network", "bluetooth", "nightLight", "systemMonitor", "serverStatus", "weather", "calendar"]
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
        // How an app's multiple OSD toasts are presented:
        //   "hover"  — just the latest at rest, fans out the deck on hover (default)
        //   "stack"  — always show the recent cards stacked
        //   "single" — only ever the latest card + a count badge
        property string notifStackStyle: "hover"
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

    // ── Input Method ──
    readonly property QtObject inputMethod: QtObject {
        property bool liveConversion: false
        property bool prediction: true
    }

    // ── Appearance ──
    // Global UI-size multiplier (independent of the compositor's per-output
    // scale). Theme.uiScaleRatio reads this and routes all size/spacing/font/
    // radius tokens through it. 1.0 = native size.
    readonly property QtObject appearance: QtObject {
        property real uiScale: 1.0
        // Master switch for the staggered reveal animations (Control Center
        // cards, settings nav/pages, Spotlight results). Off = content appears
        // instantly with no fade/slide.
        property bool revealAnimations: true
    }

    // ── Night Light ──
    // Persisted state for NightLightService. Auto mode only — wlsunset
    // derives sunrise/sunset from latitude/longitude (pulled at runtime
    // from WeatherService), so we only need to store the enable flag and
    // the day/night Kelvin targets.
    readonly property QtObject nightLight: QtObject {
        property bool enabled: false
        property int dayTemp: 6500
        property int nightTemp: 4000
    }

    // ══════════════════════════════════════════════════════════════════
    // ── Schema version + defaults ──
    // The live QtObjects above are the SINGLE source of truth for both the
    // current values and their defaults: `_snapshotDefaults()` captures the
    // pristine values at startup (before persisted overrides are applied),
    // so defaults never have to be written out a second time. Used by
    // resetKey() / resetSection() / resetAll() and by the settings UI.
    // ══════════════════════════════════════════════════════════════════

    // Bump when a breaking schema change ships, and add a matching migration.
    readonly property int _configVersion: 1

    // Captured default snapshot (section → plain object), filled at startup.
    property var _defaults: ({})

    // version → function(parsedJson) that upgrades the config FROM the prior
    // version TO that version (mutating it in place). Runs on load when the
    // persisted version is older. Example:
    //   2: function(d) { if (d.bar) { d.bar.newKey = d.bar.oldKey; delete d.bar.oldKey; } }
    readonly property var _migrations: ({
    })

    // Plain serialisable copy of a config QtObject's own value properties
    // (skips QtObject internals, signals, functions, and nested objects).
    function _plainCopy(src) {
        let obj = {};
        for (let prop in src) {
            if (prop === "objectName" || prop.endsWith("Changed") || prop.startsWith("_")
                || typeof src[prop] === "function"
                || (typeof src[prop] === "object" && src[prop] !== null && !(src[prop] instanceof Array)))
                continue;
            obj[prop] = (src[prop] instanceof Array) ? src[prop].slice() : src[prop];
        }
        return obj;
    }

    // Snapshot pristine defaults from the live objects (call before load()).
    function _snapshotDefaults() {
        let snap = {};
        for (let key in _sections)
            snap[key] = _plainCopy(_sections[key]);
        _defaults = snap;
    }

    // Look up a default value by section/key (e.g. "bar", "showCpuGraph").
    // Returns undefined if no such default exists.
    function getDefault(section, key) {
        let s = _defaults[section];
        if (!s) return undefined;
        return s[key];
    }

    // Reset a single setting to its default and persist.
    function resetKey(section, key) {
        let dflt = getDefault(section, key);
        if (dflt === undefined) return;
        let target = _sections[section];
        if (!target || target[key] === undefined) return;
        // Arrays must be copied so QML detects the change.
        target[key] = (dflt instanceof Array) ? dflt.slice() : dflt;
        save();
    }

    // Reset every key in a section.
    function resetSection(section) {
        let dflts = _defaults[section];
        let target = _sections[section];
        if (!dflts || !target) return;
        for (let k in dflts) {
            if (target[k] === undefined) continue;
            let v = dflts[k];
            target[k] = (v instanceof Array) ? v.slice() : v;
        }
        save();
    }

    // Nuke all overrides.
    function resetAll() {
        for (let s in _defaults) resetSection(s);
    }

    // ── Default bar layout order — derived from the snapshot (single source) ──
    function _getDefaultOrder(section) {
        let b = _defaults.bar || {};
        if (section === "left" || section === "layoutLeft") return b.layoutLeft || [];
        if (section === "center" || section === "layoutCenter") return b.layoutCenter || [];
        if (section === "right" || section === "layoutRight") return b.layoutRight || [];
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

    function toggleCcCard(key) {
        cc.cards[key] = !cc.cards[key];
        save();
    }

    function moveCcCard(key, delta) {
        let arr = cc.cardLayout.slice();
        let idx = arr.indexOf(key);
        if (idx < 0) return;
        let newIdx = idx + delta;
        if (newIdx < 0 || newIdx >= arr.length) return;
        arr.splice(idx, 1);
        arr.splice(newIdx, 0, key);
        cc.cardLayout = arr;
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
        calendar: calendarConfig, stock: stockConfig,
        nightLight: nightLight,
        inputMethod: inputMethod,
        appearance: appearance
    })

    function load() {
        _loadProc.running = true;
    }

    function save() {
        let data = { _version: _configVersion };
        for (let key in _sections)
            data[key] = _plainCopy(_sections[key]);
        // CC has nested QtObjects, so serialize manually
        let ccData = { cardLayout: cc.cardLayout, cards: {} };
        for (let k in cc.cards) {
            if (k === "objectName" || k.endsWith("Changed") || typeof cc.cards[k] !== "boolean") continue;
            ccData.cards[k] = cc.cards[k];
        }
        data["cc"] = ccData;

        let json = JSON.stringify(data, null, 2);
        _saveProc.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"",
            "--", _configPath, json];
        _saveProc.running = true;
    }

    function _applyJson(json) {
        try {
            let d = JSON.parse(json);
            let persistedVersion = (typeof d._version === "number") ? d._version : 0;
            if (persistedVersion < _configVersion) _runMigrations(d, persistedVersion);
            for (let key in _sections) {
                if (!d[key]) continue;
                let target = _sections[key];
                for (let prop in d[key]) {
                    if (target[prop] !== undefined) target[prop] = d[key][prop];
                }
            }
            // CC has nested QtObjects — apply manually
            if (d["cc"]) {
                if (d["cc"].cardLayout) cc.cardLayout = d["cc"].cardLayout;
                if (d["cc"].cards) {
                    for (let k in d["cc"].cards) {
                        if (cc.cards[k] !== undefined) cc.cards[k] = d["cc"].cards[k];
                    }
                }
            }
            // Upgraded an older config → persist it stamped with the new version.
            if (persistedVersion < _configVersion) save();
        } catch(e) {
            console.log("Config: failed to parse JSON:", e);
        }
    }

    // Run registered migrations for every version newer than the persisted one.
    function _runMigrations(d, fromVersion) {
        for (let v = fromVersion + 1; v <= _configVersion; v++) {
            let m = _migrations[v];
            if (typeof m === "function") {
                try { m(d); } catch(e) { console.log("Config: migration", v, "failed:", e); }
            }
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

    Component.onCompleted: {
        _snapshotDefaults();
        load();
    }
}
