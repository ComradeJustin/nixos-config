import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Root.Theme { id: theme }

    property var wifiService: null

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: {
                if (!root.wifiService || !root.wifiService.connected) return theme.iconWifiOff;
                if (root.wifiService.iface === "ethernet") return theme.iconEth;
                if (root.wifiService.signal > 75) return theme.iconWifiHi;
                if (root.wifiService.signal > 50) return theme.iconWifiMid;
                if (root.wifiService.signal > 25) return theme.iconWifiLow;
                return theme.iconWifiMin;
            }
            color: (root.wifiService && root.wifiService.connected) ? theme.textPrimary : theme.textDimmed
            font { family: theme.fontFamily; pixelSize: theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: {
                if (!root.wifiService || !root.wifiService.connected) return "NET OFF";
                if (root.wifiService.iface === "ethernet") return "ETH";
                return root.wifiService.ssid;
            }
            color: (root.wifiService && root.wifiService.connected) ? theme.textPrimary : theme.textDimmed
            font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
