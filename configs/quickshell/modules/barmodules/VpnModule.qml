import QtQuick
import Quickshell.Io
import "../.." as Root
import "../../components" as Components

Components.BarItem {
    id: root

    property bool connected: false
    property string exitNode: ""
    property bool loading: true

    icon: connected ? Root.Icons.vpnOn : Root.Icons.vpnOff
    value: {
        if (loading) return "";
        if (!connected) return "Off";
        if (exitNode) return exitNode;
        return "On";
    }
    accent: connected ? Root.Theme.domainNetwork : Root.Theme.textDimmed
    tooltipText: {
        if (loading) return "Checking VPN...";
        if (!connected) return "Tailscale disconnected";
        if (exitNode) return "VPN via " + exitNode;
        return "Tailscale connected";
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statusProc.running = true
    }

    Process {
        id: statusProc
        property string _buf: ""
        command: ["tailscale", "status", "--json"]

        stdout: SplitParser {
            onRead: line => { statusProc._buf += line + "\n"; }
        }

        onExited: (code) => {
            root.loading = false;
            if (code !== 0) {
                root.connected = false;
                root.exitNode = "";
                statusProc._buf = "";
                return;
            }
            try {
                let d = JSON.parse(statusProc._buf);
                // BackendState "Running" means connected
                root.connected = (d.BackendState === "Running");

                // Find active exit node
                root.exitNode = "";
                if (d.Peer) {
                    for (let key in d.Peer) {
                        let peer = d.Peer[key];
                        if (peer.ExitNode) {
                            // Use short hostname (strip domain)
                            let name = peer.HostName || peer.DNSName || "";
                            root.exitNode = name.split(".")[0];
                            break;
                        }
                    }
                }
            } catch(e) {
                root.connected = false;
                root.exitNode = "";
            }
            statusProc._buf = "";
        }
    }
}
