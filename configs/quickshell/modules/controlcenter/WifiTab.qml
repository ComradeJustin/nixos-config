import QtQuick
import QtQuick.Layouts
import "../.." as Root
import "../../components" as Components

// WiFi/Network tab content for ControlCenter
Components.SmoothFlickable {
    id: root

    property var wifiService: null

    contentHeight: wifiTabCol.implicitHeight
    clip: true

    Column {
        id: wifiTabCol
        width: parent.width
        spacing: 4

        // Connected network card
        Rectangle {
            visible: root.wifiService && root.wifiService.connected
            width: parent.width
            height: 44
            radius: Root.Theme.ccSectionRadius
            color: Root.Theme.ccSectionBg

            Row {
                anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
                spacing: 10

                Text {
                    text: Root.Theme.iconWifiHi
                    color: Root.Theme.domainNetwork
                    font { family: Root.Theme.fontFamily; pixelSize: 18 }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: root.wifiService ? root.wifiService.ssid : ""
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true }
                    }
                    Text {
                        text: "Connected"
                        color: Root.Theme.accentSuccess
                        font { family: Root.Theme.fontFamily; pixelSize: 10; letterSpacing: 1 }
                    }
                }
            }
        }

        Components.Separator {
            visible: root.wifiService && root.wifiService.connected
        }

        Components.EmptyState {
            visible: (root.wifiService ? root.wifiService.networks.count : 0) === 0
            message: "Scanning..."
        }

        // Available networks header
        Text {
            visible: {
                if (!root.wifiService) return false;
                var count = 0;
                for (var i = 0; i < root.wifiService.networks.count; i++) {
                    if (!root.wifiService.networks.get(i).wifiActive) count++;
                }
                return count > 0;
            }
            text: "Available"
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: 12 }
            leftPadding: 4
        }

        Repeater {
            model: root.wifiService ? root.wifiService.networks : null

            Components.DeviceListItem {
                visible: !model.wifiActive
                width: wifiTabCol.width
                height: visible ? 36 : 0
                icon: model.wifiSignal > 75 ? Root.Theme.iconWifiHi
                    : model.wifiSignal > 50 ? Root.Theme.iconWifiMid
                    : model.wifiSignal > 25 ? Root.Theme.iconWifiLow
                    : Root.Theme.iconWifiMin
                label: model.wifiSsid
                isActive: false
                accentColor: Root.Theme.domainNetwork
                onClicked: {
                    if (root.wifiService) root.wifiService.connectTo(model.wifiSsid);
                }
            }
        }
    }
}
