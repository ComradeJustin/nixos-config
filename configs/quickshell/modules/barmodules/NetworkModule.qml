import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Theme is now a singleton - access via Root.Theme.propertyName

    property var wifiService: null

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: {
                if (!root.wifiService || !root.wifiService.enabled) return Root.Theme.iconWifiOff;
                if (!root.wifiService.connected) return Root.Theme.iconWifiMin;
                if (root.wifiService.iface === "ethernet") return Root.Theme.iconEth;
                if (root.wifiService.signal > 75) return Root.Theme.iconWifiHi;
                if (root.wifiService.signal > 50) return Root.Theme.iconWifiMid;
                if (root.wifiService.signal > 25) return Root.Theme.iconWifiLow;
                return Root.Theme.iconWifiMin;
            }
            color: (root.wifiService && root.wifiService.connected) ? Root.Theme.domainNetwork : Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: {
                if (!root.wifiService || !root.wifiService.enabled) return "Off";
                if (!root.wifiService.connected) return "No net";
                if (root.wifiService.iface === "ethernet") return "Eth";
                return root.wifiService.ssid;
            }
            color: (root.wifiService && root.wifiService.connected) ? Root.Theme.domainNetwork : Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: true }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
