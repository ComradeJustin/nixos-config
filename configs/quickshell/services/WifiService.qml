import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

// Network state via Quickshell's native NetworkManager binding.
// Replaces the old nmcli/bash pipelines; fully event-driven. nmcli survives
// only where the native API has no equivalent: joining hidden SSIDs and
// listing saved-but-out-of-range connections.
Scope {
    id: root

    // ── Status (for bar display) ──
    property string iface: ""
    property string ssid: ""
    property int signal: -1
    property bool connected: false
    property bool enabled: Networking.wifiEnabled

    // ── Network list (for CC wifi tab) ──
    property var networks: ListModel {}
    property var savedNetworks: ListModel {}
    property bool scanning: false

    // ── Connection feedback ──
    // "" while idle, "connecting", "ok", or "error"
    property string lastConnectStatus: ""
    property string lastConnectSsid: ""
    signal connectFinished(string ssid, bool ok, string message)

    // ── Connection edge events (for hooks + notifications) ──
    // Fired on the *transition* — not on shell startup.
    signal wifiConnected(string ssid)
    signal wifiDisconnected(string ssid)
    property string _prevSsid: ""
    property bool _wifiInitialized: false

    // When true, list refreshes are suppressed (e.g. while a password
    // dialog is open) so the network list doesn't reshuffle under input.
    property bool freezeUpdates: false

    // ── Native device discovery ──
    readonly property var wifiDevice: {
        let devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wifi) return devices[i];
        return null;
    }
    readonly property var wiredDevice: {
        let devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wired) return devices[i];
        return null;
    }

    Component.onCompleted: {
        refreshStatus();
        rebuildNetworks();
        savedProc.running = true;
    }

    function activeWifiNetwork() {
        if (!wifiDevice) return null;
        let list = wifiDevice.networks.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].connected) return list[i];
        return null;
    }

    function findBySsid(networkSsid) {
        if (!wifiDevice) return null;
        let list = wifiDevice.networks.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].name === networkSsid) return list[i];
        return null;
    }

    // signalStrength scale is not documented; normalize either 0..1 or 0..100
    function signalPct(network) {
        let s = network.signalStrength;
        return Math.round(s <= 1.0 ? s * 100 : s);
    }

    function securityLabel(sec) {
        if (sec === WifiSecurityType.Open) return "";
        if (sec === WifiSecurityType.Sae || sec === WifiSecurityType.Wpa3SuiteB192) return "WPA3";
        if (sec === WifiSecurityType.Wpa2Psk || sec === WifiSecurityType.Wpa2Eap) return "WPA2";
        if (sec === WifiSecurityType.WpaPsk || sec === WifiSecurityType.WpaEap) return "WPA";
        if (sec === WifiSecurityType.StaticWep || sec === WifiSecurityType.DynamicWep) return "WEP";
        if (sec === WifiSecurityType.Owe) return "OWE";
        return "secured";
    }

    // ── Status + edge detection ──
    function refreshStatus() {
        if (root.wiredDevice && root.wiredDevice.connected) {
            root.iface = "ethernet";
            root.connected = true;
            root.ssid = "";
            root.signal = -1;
        } else if (!Networking.wifiEnabled) {
            root.iface = "";
            root.connected = false;
            root.ssid = "";
            root.signal = -1;
        } else {
            let active = activeWifiNetwork();
            if (active) {
                root.iface = "wifi";
                root.connected = true;
                root.ssid = active.name;
                root.signal = signalPct(active);
            } else {
                root.iface = "";
                root.connected = false;
                root.ssid = "";
                root.signal = -1;
            }
        }

        // Edge detection: SSID for wifi, "ethernet" for wired, "" for none.
        let nowSsid = root.connected ? (root.ssid || root.iface) : "";
        if (!root._wifiInitialized) {
            root._prevSsid = nowSsid;
            root._wifiInitialized = true;
        } else if (nowSsid !== root._prevSsid) {
            if (root._prevSsid.length > 0 && nowSsid.length === 0) {
                root.wifiDisconnected(root._prevSsid);
            } else if (nowSsid.length > 0) {
                if (root._prevSsid.length > 0) root.wifiDisconnected(root._prevSsid);
                root.wifiConnected(nowSsid);
                root._fireWifiNotify(nowSsid);
            }
            root._prevSsid = nowSsid;
        }
    }

    // ── Network list for the CC/settings UI ──
    function rebuildNetworks() {
        if (root.freezeUpdates || !root.wifiDevice) return;
        let list = root.wifiDevice.networks.values.slice();
        list.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
        root.networks.clear();
        for (let i = 0; i < list.length; i++) {
            let n = list[i];
            let sec = securityLabel(n.security);
            root.networks.append({
                "wifiActive": n.connected,
                "wifiSsid": n.name,
                "wifiSignal": signalPct(n),
                "wifiSecurity": sec,
                "wifiSecured": sec.length > 0
            });
        }
    }

    // ── Change wiring ──
    // .values-based bindings only refresh on add/remove, so per-network
    // property changes are watched through an Instantiator of Connections.
    Instantiator {
        model: root.wifiDevice ? root.wifiDevice.networks : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() { statusDebounce.restart(); listDebounce.restart(); }
            function onSignalStrengthChanged() { if (modelData.connected) statusDebounce.restart(); }
            function onStateChanged() {
                if (modelData !== root._pendingNet) return;
                if (modelData.state === ConnectionState.Connected) {
                    root._finishConnect(true, "Connected");
                }
            }
            function onConnectionFailed() {
                if (modelData === root._pendingNet) root._finishConnect(false, "Failed to connect");
            }
            function onRequestConnectWithPsk() {
                if (modelData === root._pendingNet) root._finishConnect(false, "Password required");
            }
        }
    }
    Connections {
        target: root.wiredDevice
        function onConnectedChanged() { statusDebounce.restart(); }
    }
    Connections {
        target: Networking
        function onWifiEnabledChanged() { statusDebounce.restart(); listDebounce.restart(); }
    }
    onWifiDeviceChanged: { statusDebounce.restart(); listDebounce.restart(); }

    Timer { id: statusDebounce; interval: 150; onTriggered: root.refreshStatus() }
    Timer { id: listDebounce; interval: 300; onTriggered: root.rebuildNetworks() }

    // ── Scanning ──
    function scan() {
        if (root.freezeUpdates || !root.wifiDevice) return;
        root.wifiDevice.scannerEnabled = true;
        root.scanning = true;
        scanOffTimer.restart();
        listDebounce.restart();
    }
    Timer {
        id: scanOffTimer
        interval: 15000
        onTriggered: {
            if (root.wifiDevice) root.wifiDevice.scannerEnabled = false;
            root.scanning = false;
            root.rebuildNetworks();
        }
    }

    // ── Actions ──
    property var _pendingNet: null

    function connectTo(networkSsid, password) {
        let network = findBySsid(networkSsid);
        if (!network) {
            root.connectFinished(networkSsid, false, "Network not found");
            return;
        }
        root.lastConnectStatus = "connecting";
        root.lastConnectSsid = networkSsid;
        root._pendingNet = network;
        if (password && password.length > 0) network.connectWithPsk(password);
        else network.connect();
    }

    function _finishConnect(ok, message) {
        let pendingSsid = root.lastConnectSsid;
        root._pendingNet = null;
        root.lastConnectStatus = ok ? "ok" : "error";
        root.connectFinished(pendingSsid, ok, message);
        if (ok) {
            root.freezeUpdates = false;
            root.rebuildNetworks();
        }
    }

    function disconnect() {
        if (root.wifiDevice) root.wifiDevice.disconnect();
    }

    function toggle() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function forget(networkSsid) {
        let network = findBySsid(networkSsid);
        if (network && network.known) {
            network.forget();
            root.loadSaved();
        } else {
            // Out of range — not visible to the native API; fall back to nmcli
            forgetProc.ssid = networkSsid;
            forgetProc.running = true;
        }
    }

    // ── Hidden networks (nmcli — native API can't target hidden SSIDs) ──
    function connectHidden(networkSsid, password) {
        root.lastConnectStatus = "connecting";
        root.lastConnectSsid = networkSsid;
        hiddenProc.ssid = networkSsid;
        hiddenProc.password = password || "";
        hiddenProc.running = true;
    }

    Process {
        id: hiddenProc
        property string ssid: ""
        property string password: ""
        property string _err: ""
        command: ["nmcli", "-w", "20", "dev", "wifi", "connect", ssid,
                  "password", password, "hidden", "yes"]
        stderr: SplitParser {
            onRead: data => { hiddenProc._err = (hiddenProc._err + " " + data).trim(); }
        }
        onExited: code => {
            let ok = (code === 0);
            let msg = ok ? "Connected" : (hiddenProc._err || "Failed to connect");
            hiddenProc._err = "";
            root.lastConnectStatus = ok ? "ok" : "error";
            root.connectFinished(hiddenProc.ssid, ok, msg);
            if (ok) root.freezeUpdates = false;
        }
    }

    // ── Saved networks (nmcli — includes out-of-range saved connections) ──
    function loadSaved() {
        if (root.freezeUpdates) return;
        savedProc.running = true;
    }

    Process {
        id: savedProc
        command: [
            "bash", "-c",
            "nmcli -t -f NAME,TYPE connection show 2>/dev/null | " +
            "awk -F: '$2==\"802-11-wireless\" || $2==\"wifi\" {print $1}'"
        ]
        stdout: SplitParser {
            onRead: data => {
                var name = (data || "").trim();
                if (name.length === 0) return;
                root.savedNetworks.append({ "savedSsid": name });
            }
        }
        onStarted: { root.savedNetworks.clear(); }
    }

    Process {
        id: forgetProc
        property string ssid: ""
        command: ["nmcli", "connection", "delete", ssid]
        onExited: { root.loadSaved(); }
    }

    // Built-in notification — fires on every fresh connect transition.
    // `x-canonical-private-synchronous` makes repeat toasts replace each other.
    property Component _wifiNotifyRunner: Component {
        Process {
            property var argv: []
            command: argv
            running: true
            onExited: Qt.callLater(() => destroy())
        }
    }

    function _fireWifiNotify(ssid) {
        _wifiNotifyRunner.createObject(root, {
            argv: [
                "notify-send",
                "-a", "System Information",
                "-i", "network-wireless",
                "-h", "string:x-canonical-private-synchronous:sysinfo-wifi",
                "-t", "4000",
                "Wi-Fi", "Connected to " + ssid
            ]
        });
    }
}
