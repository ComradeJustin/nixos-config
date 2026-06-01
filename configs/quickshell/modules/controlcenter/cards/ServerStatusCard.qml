import QtQuick
import Quickshell.Io
import "../../.." as Root
import "../../../components" as Components

// ServerStatusCard — fetches status from status-reporter API on each host.
// Hosts are configured via the `hosts` property. Services render dynamically.
Rectangle {
    id: card

    width: parent ? parent.width : 320
    implicitHeight: contentCol.implicitHeight + 24

    radius: Root.Theme.radiusMedium
    color: Root.Theme.ccSectionBg
    border.width: Root.Theme.borderWidth
    border.color: Root.Theme.borderColor
    clip: true

    // Soft domain glow
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Qt.rgba(Root.Theme.domainNetwork.r,
                               Root.Theme.domainNetwork.g,
                               Root.Theme.domainNetwork.b, 0.12)
            }
            GradientStop { position: 0.9; color: "transparent" }
        }
    }

    // ── Configuration ──
    // Each host: { name, address, port }
    property var hosts: [
        { name: "home-core", address: "home-core", port: 9200 }
    ]

    property int activeHost: 0
    property int _rev: 0

    // Per-host cached data: { "home-core": { services: {...}, uptime: "...", ... }, ... }
    property var _hostData: ({})

    // Friendly display names for systemd service names
    readonly property var svcLabels: ({
        "nginx": { label: "Nginx", icon: "󰒍" },
        "tailscaled": { label: "Tailscale", icon: "󰖟" },
        "harmonia": { label: "Harmonia", icon: "󰏗" },
        "nix-daemon": { label: "Builder", icon: "󱂵" },
        "grafana": { label: "Grafana", icon: "󱂬" },
        "adguardhome": { label: "AdGuard", icon: "󰟒" },
        "jellyfin": { label: "Jellyfin", icon: "󰎁" },
        "radarr": { label: "Radarr", icon: "󰿎" },
        "sonarr": { label: "Sonarr", icon: "󰿎" },
        "qbittorrent": { label: "qBittorrent", icon: "󰇚" },
        "prowlarr": { label: "Prowlarr", icon: "󰜏" },
        "postgresql": { label: "Postgres", icon: "󰆼" },
        "docker": { label: "Docker", icon: "󰡨" }
    })

    function currentData() {
        void(_rev);
        const h = hosts[activeHost];
        return h ? (_hostData[h.name] || null) : null;
    }

    function serviceList() {
        const d = currentData();
        if (!d || !d.services) return [];
        const list = [];
        for (const key in d.services) {
            const info = svcLabels[key] || { label: key, icon: "󰒋" };
            list.push({
                key: key,
                label: info.label,
                icon: info.icon,
                online: d.services[key]
            });
        }
        return list;
    }

    function onlineCount() {
        const svcs = currentData();
        if (!svcs || !svcs.services) return 0;
        let c = 0;
        for (const k in svcs.services) if (svcs.services[k]) c++;
        return c;
    }

    function totalCount() {
        const svcs = currentData();
        if (!svcs || !svcs.services) return 0;
        return Object.keys(svcs.services).length;
    }

    // ── Polling ──
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            for (let i = 0; i < hosts.length; i++) {
                fetchRepeater.itemAt(i).startFetch();
            }
        }
    }

    // One Process per host to fetch status JSON
    Repeater {
        id: fetchRepeater
        model: card.hosts.length

        Item {
            function startFetch() { proc._buf = ""; proc.running = true; }

            Process {
                id: proc
                property string _buf: ""
                command: ["curl", "-s", "--connect-timeout", "3", "--max-time", "5",
                          "http://" + card.hosts[index].address + ":" + card.hosts[index].port + "/status.json"]

                stdout: SplitParser {
                    onRead: line => { proc._buf += line + "\n"; }
                }

                onExited: (code) => {
                    if (code === 0 && proc._buf.length > 0) {
                        try {
                            const data = JSON.parse(proc._buf);
                            card._hostData[card.hosts[index].name] = data;
                        } catch(e) {
                            card._hostData[card.hosts[index].name] = null;
                        }
                    } else {
                        card._hostData[card.hosts[index].name] = null;
                    }
                    card._rev++;
                }
            }
        }
    }

    Column {
        id: contentCol
        anchors {
            left: parent.left; right: parent.right
            top: parent.top; margins: Root.Theme.spacingM
        }
        spacing: Root.Theme.spacingS

        // ── Host tabs (only shown if multiple hosts) ──
        Row {
            width: parent.width
            spacing: Root.Theme.spacingXS
            visible: card.hosts.length > 1

            Repeater {
                model: card.hosts

                Rectangle {
                    width: Math.min(implicitWidth + 16, (contentCol.width - (card.hosts.length - 1) * 4) / card.hosts.length)
                    implicitWidth: tabText.implicitWidth
                    height: 24
                    radius: Root.Theme.radiusSmall
                    color: index === card.activeHost
                        ? Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.2)
                        : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.06)
                    border.width: index === card.activeHost ? 1 : 0
                    border.color: Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.4)

                    Text {
                        id: tabText
                        anchors.centerIn: parent
                        text: modelData.name
                        color: index === card.activeHost ? Root.Theme.textPrimary : Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.activeHost = index
                    }
                }
            }
        }

        // ── Header ──
        Row {
            width: parent.width
            spacing: Root.Theme.spacingS

            Rectangle {
                width: 36; height: 36
                radius: Root.Theme.radiusSmall
                color: Qt.rgba(Root.Theme.domainNetwork.r,
                               Root.Theme.domainNetwork.g,
                               Root.Theme.domainNetwork.b, 0.22)
                border.width: 1
                border.color: Qt.rgba(Root.Theme.domainNetwork.r,
                                      Root.Theme.domainNetwork.g,
                                      Root.Theme.domainNetwork.b, 0.5)

                Text {
                    anchors.centerIn: parent
                    text: "󰒋"
                    color: Root.Theme.domainNetwork
                    font { family: Root.Theme.fontIcons; pixelSize: 20 }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: card.hosts[card.activeHost] ? card.hosts[card.activeHost].name : "unknown"
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeL; bold: true }
                }
                Text {
                    text: {
                        void(card._rev);
                        const d = card.currentData();
                        if (!d) return "unreachable";
                        return card.onlineCount() + "/" + card.totalCount() + " services online";
                    }
                    color: {
                        void(card._rev);
                        const d = card.currentData();
                        if (!d) return Root.Theme.accentDanger;
                        return card.onlineCount() === card.totalCount() ? Root.Theme.accentSuccess : Root.Theme.textDimmed;
                    }
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                }
            }
        }

        // ── System info row ──
        Row {
            width: parent.width
            spacing: 0
            visible: card.currentData() !== null

            Repeater {
                model: {
                    void(card._rev);
                    const d = card.currentData();
                    if (!d) return [];
                    return [
                        { label: "UP", value: d.uptime || "--" },
                        { label: "LOAD", value: d.load || "--" },
                        { label: "MEM", value: d.memory || "--" },
                        { label: "DISK", value: d.disk || "--" }
                    ];
                }

                Rectangle {
                    width: contentCol.width / 4
                    height: 32
                    color: "transparent"

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: 8 }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.value
                            color: Root.Theme.textPrimary
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                        }
                    }
                }
            }
        }

        // ── Service grid (dynamic columns) ──
        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 6
            rowSpacing: 4

            Repeater {
                model: {
                    void(card._rev);
                    return card.serviceList();
                }

                Rectangle {
                    id: svcTile
                    width: (contentCol.width - 6) / 2
                    height: 28
                    radius: Root.Theme.radiusSmall

                    color: svcMouse.containsMouse
                        ? Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.12)
                        : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.06)
                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Root.Theme.spacingS }
                        spacing: 6

                        Rectangle {
                            width: 6; height: 6; radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.online ? Root.Theme.accentSuccess : Root.Theme.accentDanger
                        }

                        Text {
                            text: modelData.icon
                            color: modelData.online ? Root.Theme.textPrimary : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM }
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: modelData.label
                            color: modelData.online ? Root.Theme.textPrimary : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: svcMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
    }
}
