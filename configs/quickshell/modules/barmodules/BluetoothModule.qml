import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Theme is now a singleton - access via Root.Theme.propertyName

    property var bluetoothService: null

    // Hide module if bluetooth is unavailable (no bluetoothctl)
    visible: root.bluetoothService !== null

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: {
                if (!root.bluetoothService) return Root.Theme.iconBtOff;
                if (!root.bluetoothService.enabled) return Root.Theme.iconBtOff;
                if (root.bluetoothService.connected) return Root.Theme.iconBtConnected;
                return Root.Theme.iconBtOn;
            }
            color: {
                if (!root.bluetoothService || !root.bluetoothService.enabled) return Root.Theme.textDimmed;
                if (root.bluetoothService.connected) return Root.Theme.accentSuccess;
                return Root.Theme.domainNetwork;
            }
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: {
                if (!root.bluetoothService || !root.bluetoothService.enabled) return "Off";
                if (root.bluetoothService.connected) {
                    var name = root.bluetoothService.connectedDevice;
                    return name.length > 10 ? name.substring(0, 8) + "…" : name;
                }
                return "On";
            }
            color: {
                if (!root.bluetoothService || !root.bluetoothService.enabled) return Root.Theme.textDimmed;
                if (root.bluetoothService.connected) return Root.Theme.accentSuccess;
                return Root.Theme.domainNetwork;
            }
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: true }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
