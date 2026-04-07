import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    // ── Status (for bar display) ──
    property string iface: ""
    property string ssid: ""
    property int signal: -1
    property bool connected: false
    property bool enabled: true

    // ── Network list (for CC wifi tab) ──
    property var networks: ListModel {}
    property var savedNetworks: ListModel {}
    property bool scanning: false

    // ── Connection feedback ──
    // Updates to "" while idle, "connecting", "ok", or an error message
    property string lastConnectStatus: ""
    property string lastConnectSsid: ""
    signal connectFinished(string ssid, bool ok, string message)

    // ── Connection edge events (for hooks + notifications) ──
    // Fired on the *transition* — not on shell startup. _wifiInitialized
    // suppresses the very first poll so we don't notify "Connected to X"
    // every time the shell launches with wifi already up.
    signal wifiConnected(string ssid)
    signal wifiDisconnected(string ssid)
    property string _prevSsid: ""
    property bool _wifiInitialized: false

    // Freeze flag: when true, scans/refreshes are suppressed (e.g. while
    // a password dialog is open) so the network list doesn't reshuffle
    // under the user's input.
    property bool freezeUpdates: false

    Component.onCompleted: {
        statusProc.running = true;
        savedProc.running = true;
    }

    // ── Quick status poll (bar) ──
    Process {
        id: statusProc
        command: [
            "bash", "-c",
            "wifi_radio=$(nmcli radio wifi 2>/dev/null); " +
            "if [ \"$wifi_radio\" = \"disabled\" ]; then " +
            "  echo radio-off; " +
            "elif nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q '^ethernet:connected$'; then " +
            "  echo ethernet; " +
            "else " +
            "  line=$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | grep '^yes' | head -1); " +
            "  ssid=$(echo \"$line\" | cut -d: -f2); " +
            "  sig=$(echo \"$line\" | cut -d: -f3); " +
            "  if [ -n \"$ssid\" ]; then " +
            "    echo \"wifi:$ssid:$sig\"; " +
            "  else " +
            "    echo disconnected; " +
            "  fi; " +
            "fi"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                if (data === "radio-off") {
                    root.enabled = false;
                    root.iface = "";
                    root.connected = false;
                    root.ssid = "";
                    root.signal = -1;
                } else if (data === "ethernet") {
                    root.enabled = true;
                    root.iface = "ethernet";
                    root.connected = true;
                    root.ssid = "";
                    root.signal = -1;
                } else if (data.indexOf("wifi:") === 0) {
                    var parts = data.split(":");
                    var s = parts[1] || "";
                    root.enabled = true;
                    if (s.length === 0) {
                        root.iface = "";
                        root.connected = false;
                        root.ssid = "";
                        root.signal = -1;
                    } else {
                        root.iface = "wifi";
                        root.connected = true;
                        root.ssid = s;
                        root.signal = parseInt(parts[2]) || 0;
                    }
                } else {
                    // "disconnected" — radio on but not joined to any network
                    root.enabled = true;
                    root.iface = "";
                    root.connected = false;
                    root.ssid = "";
                    root.signal = -1;
                }

                // ── Edge detection ──
                // Compare against previous connection identity. Use SSID for
                // wifi, "ethernet" for wired, "" for disconnected.
                let nowSsid = root.connected ? (root.ssid || root.iface) : "";
                if (!root._wifiInitialized) {
                    root._prevSsid = nowSsid;
                    root._wifiInitialized = true;
                } else if (nowSsid !== root._prevSsid) {
                    if (root._prevSsid.length > 0 && nowSsid.length === 0) {
                        root.wifiDisconnected(root._prevSsid);
                    } else if (nowSsid.length > 0) {
                        // Direct switch (A → B) fires both events.
                        if (root._prevSsid.length > 0) root.wifiDisconnected(root._prevSsid);
                        root.wifiConnected(nowSsid);
                        root._fireWifiNotify(nowSsid);
                    }
                    root._prevSsid = nowSsid;
                }
            }
        }

        onExited: statusPoll.start()
    }

    // Built-in notification — fires on every fresh connect transition.
    // The `x-canonical-private-synchronous` hint causes mako/dunst to replace
    // any prior wifi notification with this one rather than stacking, so
    // toggling the network repeatedly produces at most one visible toast.
    // Hooks can layer extra behavior via the `wifi.connected` event.
    //
    // Dynamic per-fire spawn (not a declarative Process) so the argv can't
    // get cached at instantiation time — any future edit to the label or
    // icon takes effect on the next fire instead of requiring a full shell
    // restart.
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

    Timer {
        id: statusPoll
        interval: 10000
        onTriggered: { if (!root.freezeUpdates) statusProc.running = true; }
    }

    // ── Full scan (CC wifi tab) ──
    function scan() {
        if (root.freezeUpdates) return;
        scanProc.running = true;
    }

    Process {
        id: scanProc
        // Deduplicate by SSID in awk: keep first occurrence (active or strongest signal after sort)
        command: [
            "bash", "-c",
            "nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list --rescan auto 2>/dev/null | " +
            "awk -F: '$2!=\"\" {printf \"%s\\t%s\\t%s\\t%s\\n\",$1,$2,$3,$4}' | " +
            "sort -t'	' -k1,1r -k3,3nr | " +
            "awk -F'\\t' '!seen[$2]++ {print}'"
        ]
        stdout: SplitParser {
            onRead: data => {
                var p = data.split("\t");
                if (p.length < 4) return;
                var isActive = p[0] === "yes";
                root.networks.append({
                    "wifiActive": isActive,
                    "wifiSsid": p[1],
                    "wifiSignal": parseInt(p[2]) || 0,
                    "wifiSecurity": p[3] || "",
                    "wifiSecured": (p[3] || "").length > 0 && p[3] !== "--"
                });
                if (isActive) {
                    root.ssid = p[1];
                    root.connected = true;
                }
            }
        }
        onStarted: {
            root.networks.clear();
            root.scanning = true;
        }
        onExited: {
            root.scanning = false;
        }
    }

    // ── Saved networks (nmcli connection list, type=wifi) ──
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

    // ── Actions ──
    // Connect to a visible network. password may be "" for open networks
    // or already-saved networks.
    function connectTo(networkSsid, password) {
        root.lastConnectStatus = "connecting";
        root.lastConnectSsid = networkSsid;
        connProc.ssid = networkSsid;
        connProc.password = password || "";
        connProc.hidden = false;
        connProc.running = true;
    }

    // Connect to a hidden network (must specify both SSID and password)
    function connectHidden(networkSsid, password) {
        root.lastConnectStatus = "connecting";
        root.lastConnectSsid = networkSsid;
        connProc.ssid = networkSsid;
        connProc.password = password || "";
        connProc.hidden = true;
        connProc.running = true;
    }

    function disconnect() {
        discProc.running = true;
        refreshAfter.start();
    }

    function forget(networkSsid) {
        forgetProc.ssid = networkSsid;
        forgetProc.running = true;
    }

    function toggle() {
        root.enabled = !root.enabled;
        toggleProc.on = root.enabled;
        toggleProc.running = true;
        if (!root.enabled) root.connected = false;
        refreshAfter.start();
    }

    Process {
        id: connProc
        property string ssid: ""
        property string password: ""
        property bool hidden: false
        property string _err: ""

        // Build the nmcli command dynamically. We use `nmcli -w 20 dev wifi connect`
        // for visible networks (works for open + secured + already-saved) and
        // `nmcli connection add` for hidden networks since `dev wifi connect`
        // can't target a hidden SSID reliably.
        command: {
            if (hidden) {
                return [
                    "nmcli", "-w", "20", "dev", "wifi", "connect", ssid,
                    "password", password, "hidden", "yes"
                ];
            }
            if (password.length > 0) {
                return ["nmcli", "-w", "20", "dev", "wifi", "connect", ssid, "password", password];
            }
            return ["nmcli", "-w", "20", "dev", "wifi", "connect", ssid];
        }

        stdout: SplitParser {
            onRead: data => { /* ignore stdout, exit code is what matters */ }
        }
        stderr: SplitParser {
            onRead: data => { connProc._err = (connProc._err + " " + data).trim(); }
        }

        onExited: code => {
            var ok = (code === 0);
            var msg = ok ? "Connected" : (connProc._err || "Failed to connect");
            connProc._err = "";
            root.lastConnectStatus = ok ? "ok" : "error";
            root.connectFinished(connProc.ssid, ok, msg);
            // On success, lift the freeze and refresh
            if (ok) {
                root.freezeUpdates = false;
                refreshAfter.start();
            }
        }
    }
    Process { id: discProc; command: ["nmcli", "dev", "disconnect", "wlan0"] }
    Process { id: toggleProc; property bool on: true; command: ["nmcli", "radio", "wifi", on ? "on" : "off"] }
    Process {
        id: forgetProc
        property string ssid: ""
        command: ["nmcli", "connection", "delete", ssid]
        onExited: { root.loadSaved(); }
    }

    Timer {
        id: refreshAfter
        interval: 1500
        onTriggered: {
            if (root.freezeUpdates) return;
            scanProc.running = true;
            statusProc.running = true;
            savedProc.running = true;
        }
    }
}
