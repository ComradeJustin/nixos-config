import QtQuick
import QtQuick.Layouts
import "../.." as Root
import "../../components" as Components

// Bluetooth tab content for ControlCenter
Flickable {
    id: root

    property var bluetoothService: null

    contentHeight: btTabCol.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: btTabCol
        width: parent.width
        spacing: 4

        // Connected device card
        Rectangle {
            visible: root.bluetoothService && root.bluetoothService.connected
            width: parent.width
            height: 44
            radius: Root.Theme.ccSectionRadius
            color: Root.Theme.ccSectionBg

            Row {
                anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
                spacing: 10

                Text {
                    text: Root.Theme.iconBtConnected
                    color: Root.Theme.domainNetwork
                    font { family: Root.Theme.fontFamily; pixelSize: 18 }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: root.bluetoothService ? root.bluetoothService.connectedDevice : ""
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
            visible: root.bluetoothService && root.bluetoothService.connected
        }

        Components.EmptyState {
            visible: root.bluetoothService ? root.bluetoothService.scanning : false
            message: "Scanning..."
            preferredHeight: 40
        }

        Components.EmptyState {
            visible: (root.bluetoothService ? root.bluetoothService.devices.count : 0) === 0 && !(root.bluetoothService && root.bluetoothService.scanning)
            message: "No devices"
        }

        // Paired devices header
        Text {
            visible: root.bluetoothService ? root.bluetoothService.devices.count > 0 : false
            text: "Paired"
            color: Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: 12; bold: true }
            leftPadding: 4
        }

        Repeater {
            model: root.bluetoothService ? root.bluetoothService.devices : null

            Components.DeviceListItem {
                width: btTabCol.width
                icon: model.btConnected ? Root.Theme.iconBtConnected : Root.Theme.iconBtOn
                label: model.btName
                isActive: model.btConnected
                accentColor: Root.Theme.domainNetwork
                onClicked: {
                    if (root.bluetoothService) {
                        if (model.btConnected)
                            root.bluetoothService.disconnect(model.btMac);
                        else
                            root.bluetoothService.connect(model.btMac);
                    }
                }
            }
        }
    }
}
