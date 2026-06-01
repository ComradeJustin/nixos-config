pragma Singleton
import QtQuick

// Holds references to all live service instances.
// shell.qml registers services here; modules use ServiceManager.get("key")
// or the convenience accessors below to reach them.
//
// register() reassigns `_services` to a fresh object, which notifies the
// accessor bindings — so they re-evaluate when a service is (re)registered
// without needing an explicit revision counter.
QtObject {
    id: mgr

    property var _services: ({})

    function register(key, instance) {
        let old = _services;
        let s = {};
        for (let k in old) s[k] = old[k];
        s[key] = instance;
        _services = s;
    }

    function get(key) {
        return _services[key] || null;
    }

    // ── Service accessors ──
    readonly property var audio:        _services["audio"]        || null
    readonly property var player:       _services["player"]       || null
    readonly property var power:        _services["power"]        || null
    readonly property var powerProfile: _services["powerProfile"] || null
    readonly property var notif:        _services["notif"]        || null
    readonly property var wifi:         _services["wifi"]         || null
    readonly property var bluetooth:    _services["bluetooth"]    || null
    readonly property var brightness:   _services["brightness"]   || null
    readonly property var window:       _services["window"]       || null
    readonly property var idleInhibit:  _services["idleInhibit"]  || null
    readonly property var weather:      _services["weather"]      || null
    readonly property var systemStats:  _services["systemStats"]  || null
    readonly property var nightLight:   _services["nightLight"]   || null
    readonly property var hooks:        _services["hooks"]        || null
    readonly property var inputMethod:  _services["inputMethod"]  || null
    readonly property var wallpaper:    _services["wallpaper"]    || null

    // ── Module references — registered by shell.qml ──
    readonly property var bar:            _services["bar"]            || null
    readonly property var controlCenter:  _services["controlCenter"]  || null
    readonly property var powerMenu:      _services["powerMenu"]      || null
    readonly property var widgetOverlay:  _services["widgetOverlay"]  || null
    readonly property var settingsWindow: _services["settingsWindow"] || null

    // Shared bar popup window reference — registered by Bar.qml
    property var barPopup: null

    // Shared bar tooltip window reference — registered by Bar.qml
    property var barTooltip: null
}
