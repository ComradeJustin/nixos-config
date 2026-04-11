pragma Singleton
import QtQuick

// Holds references to all live service instances.
// shell.qml registers services here; modules use ServiceManager.get("key") to access them.
QtObject {
    id: mgr

    property var _services: ({})

    property int _rev: 0

    function register(key, instance) {
        let old = _services;
        let s = {};
        for (let k in old) s[k] = old[k];
        s[key] = instance;
        _services = s;
        _rev++;
    }

    function get(key) {
        return _services[key] || null;
    }

    // Convenience properties — _rev dependency forces re-evaluation on registration
    // Services
    readonly property var audio:       _rev >= 0 ? (_services["audio"]       || null) : null
    readonly property var player:      _rev >= 0 ? (_services["player"]      || null) : null
    readonly property var power:       _rev >= 0 ? (_services["power"]       || null) : null
    readonly property var powerProfile:_rev >= 0 ? (_services["powerProfile"] || null) : null
    readonly property var notif:       _rev >= 0 ? (_services["notif"]       || null) : null
    readonly property var wifi:        _rev >= 0 ? (_services["wifi"]        || null) : null
    readonly property var bluetooth:   _rev >= 0 ? (_services["bluetooth"]   || null) : null
    readonly property var brightness:  _rev >= 0 ? (_services["brightness"]  || null) : null
    readonly property var window:      _rev >= 0 ? (_services["window"]      || null) : null
    readonly property var idleInhibit: _rev >= 0 ? (_services["idleInhibit"] || null) : null
    readonly property var weather:     _rev >= 0 ? (_services["weather"]     || null) : null
    readonly property var systemStats: _rev >= 0 ? (_services["systemStats"] || null) : null
    readonly property var nightLight:  _rev >= 0 ? (_services["nightLight"]  || null) : null
    readonly property var hooks:       _rev >= 0 ? (_services["hooks"]       || null) : null

    // Module references — registered by shell.qml
    readonly property var bar:            _rev >= 0 ? (_services["bar"]            || null) : null
    readonly property var controlCenter:  _rev >= 0 ? (_services["controlCenter"]  || null) : null
    readonly property var powerMenu:      _rev >= 0 ? (_services["powerMenu"]      || null) : null
    readonly property var widgetOverlay:  _rev >= 0 ? (_services["widgetOverlay"]  || null) : null
    readonly property var settingsWindow: _rev >= 0 ? (_services["settingsWindow"] || null) : null

    // Shared bar popup window reference — registered by Bar.qml
    property var barPopup: null

    // Shared bar tooltip window reference — registered by Bar.qml
    property var barTooltip: null
}
