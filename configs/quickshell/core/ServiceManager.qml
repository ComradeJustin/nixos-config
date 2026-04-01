pragma Singleton
import QtQuick

// Holds references to all live service instances.
// shell.qml registers services here; modules use ServiceManager.get("key") to access them.
QtObject {
    id: mgr

    property var _services: ({})

    function register(key, instance) {
        let s = _services;
        s[key] = instance;
        _services = s;
    }

    function get(key) {
        return _services[key] || null;
    }

    // Convenience properties for type-safe access
    readonly property var audio:       _services["audio"] || null
    readonly property var player:      _services["player"] || null
    readonly property var power:       _services["power"] || null
    readonly property var notif:       _services["notif"] || null
    readonly property var wifi:        _services["wifi"] || null
    readonly property var bluetooth:   _services["bluetooth"] || null
    readonly property var brightness:  _services["brightness"] || null
    readonly property var window:      _services["window"] || null
    readonly property var idleInhibit: _services["idleInhibit"] || null
    readonly property var weather:     _services["weather"] || null
    readonly property var systemStats: _services["systemStats"] || null
}
