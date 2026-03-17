import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Root.Theme { id: theme }

    property var bluetoothService: null

    // Hide module if bluetooth is unavailable (no bluetoothctl)
    visible: root.bluetoothService !== null

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: {
                if (!root.bluetoothService) return theme.iconBtOff;
                if (!root.bluetoothService.enabled) return theme.iconBtOff;
                if (root.bluetoothService.connected) return theme.iconBtConnected;
                return theme.iconBtOn;
            }
            color: {
                if (!root.bluetoothService || !root.bluetoothService.enabled) return theme.textDimmed;
                if (root.bluetoothService.connected) return theme.textAccent;
                return theme.textPrimary;
            }
            font { family: theme.fontFamily; pixelSize: theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: {
                if (!root.bluetoothService || !root.bluetoothService.enabled) return "off";
                if (root.bluetoothService.connected) {
                    // Truncate long device names
                    var name = root.bluetoothService.connectedDevice;
                    return name.length > 12 ? name.substring(0, 10) + "…" : name;
                }
                return "on";
            }
            color: {
                if (!root.bluetoothService || !root.bluetoothService.enabled) return theme.textDimmed;
                if (root.bluetoothService.connected) return theme.textAccent;
                return theme.textPrimary;
            }
            font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
