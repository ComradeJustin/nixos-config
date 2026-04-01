import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".." as Root
import "../components" as Components
import "barmodules" as BarModules
import "../core" as Core

Scope {
    id: barScope

    property bool isHidden: false
    property bool showCava: false
    property var notifRef: null
    property var playerService: null
    property var powerService: null
    property var audioService: null
    property var powerMenuRef: null
    property var wifiService: null
    property var bluetoothService: null
    property var weatherService: null
    property var systemStatsService: null

    onIsHiddenChanged: {
        if (isHidden) {
            zoneReleaseTimer.start();
        } else {
            panel.visible = true;
            zoneRestoreTimer.start();
        }
    }

    Timer { id: zoneReleaseTimer; interval: 220; onTriggered: panel.visible = false }
    Timer { id: zoneRestoreTimer; interval: 220; onTriggered: {} }

    PanelWindow {
        id: panel

        anchors { top: true; left: true; right: true }
        implicitHeight: Root.Theme.barHeight

        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: barScope.isHidden ? 0 : Root.Theme.barHeight

        color: "transparent"

        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                id: bg
                width: parent.width
                height: Root.Theme.barHeight
                color: Root.Theme.barBackground
                y: barScope.isHidden ? -Root.Theme.barHeight : 0
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }

                // ── Left: navigation & context ──
                Row {
                    id: leftSection
                    height: Root.Theme.barHeight
                    anchors {
                        left: parent.left; leftMargin: Root.Theme.barPadding
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Root.Theme.barSpacing
                    width: Math.min(implicitWidth, mediaModule.x - Root.Theme.barPadding - Root.Theme.barSpacing)
                    clip: true

                    // Power icon (inline)
                    Text {
                        id: powerItem
                        visible: Root.Config.bar.layoutLeft.indexOf("power") >= 0
                        text: Root.Theme.iconPower
                        color: Root.Theme.accentDanger
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize + 2 }
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (barScope.powerMenuRef) barScope.powerMenuRef.toggle(); }
                        }
                    }

                    Components.Separator { vertical: true; anchors.verticalCenter: parent.verticalCenter; visible: powerItem.visible && workspaceItem.visible }

                    BarModules.WorkspaceModule {
                        id: workspaceItem
                        visible: Root.Config.bar.layoutLeft.indexOf("workspace") >= 0
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Components.Separator { vertical: true; anchors.verticalCenter: parent.verticalCenter; visible: workspaceItem.visible && timeItem.visible }

                    BarModules.TimeModule {
                        id: timeItem
                        visible: Root.Config.bar.layoutLeft.indexOf("time") >= 0
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Components.Separator { vertical: true; anchors.verticalCenter: parent.verticalCenter; visible: timeItem.visible && weatherItem.visible }

                    // Weather (inlined)
                    Components.BarItem {
                        id: weatherItem
                        visible: Root.Config.bar.layoutLeft.indexOf("weather") >= 0
                        anchors.verticalCenter: parent.verticalCenter
                        icon: barScope.weatherService ? barScope.weatherService.icon : Root.Theme.iconWeatherDefault
                        value: barScope.weatherService ? barScope.weatherService.temperature : "--"
                        accent: Root.Theme.domainWeather
                    }

                    Components.Separator { vertical: true; anchors.verticalCenter: parent.verticalCenter; visible: weatherItem.visible && windowItem.visible }

                    BarModules.WindowModule {
                        id: windowItem
                        visible: Root.Config.bar.layoutLeft.indexOf("window") >= 0
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // ── Center: media ──
                BarModules.MediaModule {
                    id: mediaModule
                    visible: Root.Config.bar.layoutCenter.indexOf("media") >= 0
                    anchors.centerIn: parent
                    playerService: barScope.playerService
                    onCavaToggled: barScope.showCava = !barScope.showCava
                }

                // ── Right: system & controls ──
                Row {
                    id: rightSection
                    height: Root.Theme.barHeight
                    anchors {
                        right: parent.right; rightMargin: Root.Theme.barPadding
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Root.Theme.barSpacing

                    // Resource (uses shared SystemStatsService)
                    Components.BarItem {
                        id: resourceItem
                        visible: Root.Config.bar.layoutRight.indexOf("resource") >= 0
                        anchors.verticalCenter: parent.verticalCenter
                        custom: true

                        property var svc: barScope.systemStatsService
                        property int cpuPercent: svc ? svc.cpuPercent : -1
                        property real ramUsedGb: svc ? svc.ramUsedGb : -1

                        Text {
                            text: Root.Theme.iconCpu
                            color: resourceItem.cpuPercent >= 90 ? Root.Theme.accentDanger : Root.Theme.domainSystem
                            font: resourceItem.iconFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: resourceItem.cpuPercent >= 0 ? resourceItem.cpuPercent + "%" : "--"
                            color: resourceItem.cpuPercent >= 90 ? Root.Theme.accentDanger : Root.Theme.domainSystem
                            font: resourceItem.valueFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: 4; height: 1 }
                        Text {
                            text: Root.Theme.iconRam
                            color: Root.Theme.domainSystem
                            font: resourceItem.iconFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: resourceItem.ramUsedGb >= 0 ? resourceItem.ramUsedGb.toFixed(1) + "G" : "--"
                            color: Root.Theme.domainSystem
                            font: resourceItem.valueFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Components.Separator { vertical: true; anchors.verticalCenter: parent.verticalCenter; visible: resourceItem.visible && audioItem.visible }

                    // Audio (inlined)
                    Components.BarItem {
                        id: audioItem
                        visible: Root.Config.bar.layoutRight.indexOf("audio") >= 0
                        anchors.verticalCenter: parent.verticalCenter
                        property int vol: barScope.audioService ? barScope.audioService.volume : -1
                        property bool muted: barScope.audioService ? barScope.audioService.muted : false
                        icon: Root.Theme.volumeIcon(vol, muted)
                        value: vol >= 0 ? vol + "%" : "--"
                        accent: muted ? Root.Theme.textDimmed : Root.Theme.domainMedia
                    }

                    Components.Separator { vertical: true; anchors.verticalCenter: parent.verticalCenter; visible: audioItem.visible && networkItem.visible }

                    // Network (inlined)
                    Components.BarItem {
                        id: networkItem
                        visible: Root.Config.bar.layoutRight.indexOf("network") >= 0
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Root.Theme.wifiIcon(barScope.wifiService)
                        value: {
                            let svc = barScope.wifiService;
                            if (!svc || !svc.enabled) return "Off";
                            if (!svc.connected) return "No net";
                            if (svc.iface === "ethernet") return "Eth";
                            return svc.ssid;
                        }
                        accent: (barScope.wifiService && barScope.wifiService.connected) ? Root.Theme.domainNetwork : Root.Theme.textDimmed
                    }

                    Components.Separator {
                        vertical: true; anchors.verticalCenter: parent.verticalCenter
                        visible: networkItem.visible && btItem.visible
                    }

                    // Bluetooth (inlined)
                    Components.BarItem {
                        id: btItem
                        anchors.verticalCenter: parent.verticalCenter
                        visible: barScope.bluetoothService !== null && Root.Config.bar.layoutRight.indexOf("bluetooth") >= 0
                        icon: {
                            let svc = barScope.bluetoothService;
                            if (!svc || !svc.enabled) return Root.Theme.iconBtOff;
                            if (svc.connected) return Root.Theme.iconBtConnected;
                            return Root.Theme.iconBtOn;
                        }
                        value: {
                            let svc = barScope.bluetoothService;
                            if (!svc || !svc.enabled) return "Off";
                            if (svc.connected) {
                                let name = svc.connectedDevice;
                                return name.length > 10 ? name.substring(0, 8) + "\u2026" : name;
                            }
                            return "On";
                        }
                        accent: {
                            let svc = barScope.bluetoothService;
                            if (!svc || !svc.enabled) return Root.Theme.textDimmed;
                            if (svc.connected) return Root.Theme.accentSuccess;
                            return Root.Theme.domainNetwork;
                        }
                    }

                    Components.Separator {
                        vertical: true; anchors.verticalCenter: parent.verticalCenter
                        visible: btItem.visible && batModule.visible
                    }

                    BarModules.BatteryModule {
                        id: batModule
                        visible: batModule.hasBattery && Root.Config.bar.layoutRight.indexOf("battery") >= 0
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Components.Separator { vertical: true; anchors.verticalCenter: parent.verticalCenter; visible: batModule.visible && trayModule.visible }

                    BarModules.TrayModule {
                        id: trayModule
                        visible: Root.Config.bar.layoutRight.indexOf("tray") >= 0
                        anchors.verticalCenter: parent.verticalCenter
                        barPanel: panel
                    }

                    Components.Separator { vertical: true; anchors.verticalCenter: parent.verticalCenter; visible: trayModule.visible && gearItem.visible }

                    // Gear icon (inlined)
                    Text {
                        id: gearItem
                        visible: Root.Config.bar.layoutRight.indexOf("gear") >= 0
                        text: Root.Theme.iconGear
                        color: (barScope.notifRef && barScope.notifRef.showing) ? Root.Theme.domainSettings : Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (barScope.notifRef) barScope.notifRef.toggle(); }
                        }
                    }
                }
            }
        }
    }

    // Media popup
    BarModules.MediaPopup {
        playerService: barScope.playerService
        showCava: barScope.showCava
        barHidden: barScope.isHidden
    }

    // Fullscreen detection
    Process {
        id: fsProc
        command: [
            "bash", "-c",
            "command -v jq >/dev/null || { echo 0; exit; }; " +
            "w=$(niri msg -j focused-window 2>/dev/null) || { echo 0; exit; }; " +
            "ww=$(echo \"$w\" | jq '.layout.window_size[0] // 0'); " +
            "wh=$(echo \"$w\" | jq '.layout.window_size[1] // 0'); " +
            "wsid=$(echo \"$w\" | jq '.workspace_id // -1'); " +
            "ws=$(niri msg -j workspaces 2>/dev/null) || { echo 0; exit; }; " +
            "output=$(echo \"$ws\" | jq -r --argjson id \"$wsid\" '.[] | select(.id == $id) | .output // \"\"'); " +
            "[ -z \"$output\" ] && { echo 0; exit; }; " +
            "o=$(niri msg -j outputs 2>/dev/null) || { echo 0; exit; }; " +
            "ow=$(echo \"$o\" | jq --arg n \"$output\" '.[$n].logical.width // 0'); " +
            "oh=$(echo \"$o\" | jq --arg n \"$output\" '.[$n].logical.height // 0'); " +
            "if [ \"${ww%.*}\" -ge \"${ow%.*}\" ] 2>/dev/null && [ \"${wh%.*}\" -ge \"${oh%.*}\" ] 2>/dev/null; then " +
            "  echo \"1 $output\"; " +
            "else " +
            "  echo 0; " +
            "fi"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(" ");
                if (parts[0] === "1") {
                    let fsOutput = parts.slice(1).join(" ");
                    let barScreen = panel.screen?.name ?? "";
                    barScope.isHidden = (barScreen === "" || fsOutput === barScreen);
                } else {
                    barScope.isHidden = false;
                }
            }
        }

        onExited: fsPollTimer.start()
    }

    Timer { id: fsPollTimer; interval: 350; onTriggered: fsProc.running = true }
}
