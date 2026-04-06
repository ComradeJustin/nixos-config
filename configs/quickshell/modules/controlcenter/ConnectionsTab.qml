import QtQuick
import QtQuick.Layouts
import "../.." as Root
import "../../components" as Components

// Merged Wifi + Bluetooth connections tab for ControlCenter
Item {
    id: root

    property var wifiService: null
    property var bluetoothService: null

    property string activeSection: "wifi"  // "wifi" or "bluetooth"

    Column {
        anchors.fill: parent
        spacing: 6

        // ── Sub-tab toggle ──
        Rectangle {
            width: parent.width; height: 28
            radius: Root.Theme.radiusSmall
            color: Root.Theme.layer1

            Row {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: [
                        { key: "wifi",      icon: Root.Icons.wifiHi, label: "Wi-Fi" },
                        { key: "bluetooth", icon: Root.Icons.btOn,   label: "Bluetooth" }
                    ]
                    Rectangle {
                        required property var modelData
                        width: parent.width / 2; height: 28
                        radius: Root.Theme.radiusSmall
                        color: root.activeSection === modelData.key
                            ? Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.2)
                            : (subTabMouse.containsMouse ? Root.Theme.layer1Hover : "transparent")
                        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon + "  " + modelData.label
                            color: root.activeSection === modelData.key ? Root.Theme.domainNetwork : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: 11 }
                            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                        }
                        MouseArea {
                            id: subTabMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeSection = modelData.key;
                                if (modelData.key === "wifi" && root.wifiService) root.wifiService.scan();
                                if (modelData.key === "bluetooth" && root.bluetoothService) root.bluetoothService.scan(false);
                            }
                        }
                    }
                }
            }
        }

        // ── Wifi content ──
        Components.SmoothFlickable {
            width: parent.width
            height: parent.height - 34
            visible: opacity > 0
            opacity: root.activeSection === "wifi" ? 1 : 0
            transform: Translate {
                y: root.activeSection === "wifi" ? 0 : 4
                Behavior on y { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
            }
            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
            contentHeight: wifiCol.implicitHeight
            clip: true

            Column {
                id: wifiCol
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
                            text: Root.Icons.wifiHi
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
                        width: wifiCol.width
                        height: visible ? 36 : 0
                        icon: model.wifiSignal > 75 ? Root.Icons.wifiHi
                            : model.wifiSignal > 50 ? Root.Icons.wifiMid
                            : model.wifiSignal > 25 ? Root.Icons.wifiLow
                            : Root.Icons.wifiMin
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

        // ── Bluetooth content ──
        Components.SmoothFlickable {
            width: parent.width
            height: parent.height - 34
            visible: opacity > 0
            opacity: root.activeSection === "bluetooth" ? 1 : 0
            transform: Translate {
                y: root.activeSection === "bluetooth" ? 0 : 4
                Behavior on y { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
            }
            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
            contentHeight: btCol.implicitHeight
            clip: true

            Column {
                id: btCol
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
                            text: Root.Icons.btConnected
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
                        width: btCol.width
                        icon: model.btConnected ? Root.Icons.btConnected : Root.Icons.btOn
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
    }
}
