import Quickshell
import Quickshell.Bluetooth
import QtQuick

// Thin wrapper around Quickshell.Bluetooth.defaultAdapter.
//
// Talks to BlueZ over D-Bus directly (no bluetoothctl shelling), so
// discovery actually finds new devices. Keeps the legacy property surface
// (enabled / connected / connectedDevice / scanning / devices) that
// BluetoothModule.qml, HooksService, and the ConnectionsPage already bind
// to, and adds device-object helpers (connectDevice / disconnectDevice /
// pairDevice / forgetDevice) that take a BluetoothDevice directly.
QtObject {
    id: root

    // ── Direct adapter handles ───────────────────────────────────────
    readonly property var adapter: Bluetooth.defaultAdapter

    // Raw reactive device list. Repeater can take `adapter.devices` as a
    // model directly and use `required property var modelData` in the
    // delegate. We also expose `.values` via `deviceList` for JS filtering.
    readonly property var deviceList: adapter ? adapter.devices.values : []

    // ── Legacy status surface ────────────────────────────────────────
    readonly property bool enabled:  adapter ? adapter.enabled : false
    readonly property bool scanning: adapter ? adapter.discovering : false

    // Filter connected devices for `connected` / `connectedDevice`. Re-
    // evaluates whenever any device's `.connected` flips because the
    // property system tracks the nested reads (Noctalia uses the same
    // pattern).
    readonly property var _connected: {
        if (!adapter) return [];
        return adapter.devices.values.filter(d => d && d.connected);
    }
    readonly property bool connected: _connected.length > 0
    readonly property string connectedDevice: connected ? (_connected[0].name || _connected[0].deviceName || "") : ""
    readonly property string connectedType:   connected ? (_connected[0].icon || "other") : ""

    // ── Edge signals (for HooksService) ──────────────────────────────
    signal bluetoothDeviceConnected(string name, string type)
    signal bluetoothDeviceDisconnected(string name)
    property string _prevConn: ""

    onConnectedDeviceChanged: {
        if (connectedDevice !== _prevConn) {
            if (_prevConn.length > 0) bluetoothDeviceDisconnected(_prevConn);
            if (connectedDevice.length > 0) bluetoothDeviceConnected(connectedDevice, connectedType);
            _prevConn = connectedDevice;
        }
    }

    // ── Scan / discovery ─────────────────────────────────────────────
    // `force` arg is preserved for API compat with old call sites.
    function scan(force) {
        if (!adapter) return;
        adapter.discovering = true;
    }

    function stopScan() {
        if (adapter) adapter.discovering = false;
    }

    function toggle() {
        if (adapter) adapter.enabled = !adapter.enabled;
    }

    // ── Device-object actions (preferred API) ────────────────────────
    function connectDevice(device) {
        if (!device) return;
        try { device.trusted = true; device.connect(); } catch (e) {}
    }
    function disconnectDevice(device) {
        if (!device) return;
        try { device.disconnect(); } catch (e) {}
    }
    function pairDevice(device) {
        if (!device) return;
        try { device.pair(); } catch (e) {}
    }
    function forgetDevice(device) {
        if (!device) return;
        try { device.trusted = false; device.forget(); } catch (e) {}
    }

    // ── Legacy MAC-based API (back-compat shim) ──────────────────────
    function _findByMac(mac) {
        let list = deviceList;
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].address === mac) return list[i];
        }
        return null;
    }
    function connect(mac)    { connectDevice(_findByMac(mac)); }
    function disconnect(mac) { disconnectDevice(_findByMac(mac)); }
    function pair(mac)       { pairDevice(_findByMac(mac)); }
    function remove(mac)     { forgetDevice(_findByMac(mac)); }
}
