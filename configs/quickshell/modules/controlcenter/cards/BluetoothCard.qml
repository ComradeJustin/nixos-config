import QtQuick
import QtQuick.Effects
import "../../.." as Root
import "../../../components" as Components
import "../../../core" as Core

// BluetoothCard — Control Center Bluetooth pane.
//
// Follows NetworkCard's visual language (rounded rect, ccSectionBg,
// icon tile, info column, accent toggle pill) themed with domainNetwork.
//
// Bound to Core.ServiceManager.bluetooth (BluetoothService). Left-click
// the pill toggles the BT adapter. Right-click opens Settings → Connections.
Rectangle {
    id: card

    width: parent ? parent.width : 320
    implicitHeight: 96

    readonly property var svc: Core.ServiceManager.bluetooth
    readonly property bool enabled:   svc ? svc.enabled   : false
    readonly property bool connected: svc ? svc.connected : false
    readonly property string deviceName: svc ? svc.connectedDevice : ""
    readonly property string deviceType: svc ? svc.connectedType   : ""

    radius: Root.Theme.radiusMedium
    color: Root.Theme.ccSectionBg
    border.width: Root.Theme.borderWidth
    border.color: Root.Theme.borderColor
    clip: true

    // ── Soft domain-tinted glow ──
    Rectangle {
        id: glowBg
        anchors.fill: parent
        radius: parent.radius
        visible: card.connected
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Qt.rgba(Root.Theme.domainNetwork.r,
                               Root.Theme.domainNetwork.g,
                               Root.Theme.domainNetwork.b, 0.18)
            }
            GradientStop { position: 0.9; color: "transparent" }
        }
        Behavior on opacity { NumberAnimation { duration: Root.Theme.animNormal } }
        opacity: card.connected ? 1 : 0
    }

    // ── Content row ──
    Row {
        id: contentRow
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: 12
        }
        spacing: 12

        // Icon tile
        Rectangle {
            id: iconTile
            width: 60; height: 60
            radius: Root.Theme.radiusSmall
            color: card.connected
                ? Qt.rgba(Root.Theme.domainNetwork.r,
                          Root.Theme.domainNetwork.g,
                          Root.Theme.domainNetwork.b, 0.22)
                : Root.Theme.base02
            border.width: 1
            border.color: card.connected
                ? Qt.rgba(Root.Theme.domainNetwork.r,
                          Root.Theme.domainNetwork.g,
                          Root.Theme.domainNetwork.b, 0.5)
                : Root.Theme.borderColor

            Behavior on color  { ColorAnimation { duration: Root.Theme.anim.exitDuration } }
            Behavior on border.color { ColorAnimation { duration: Root.Theme.anim.exitDuration } }

            Text {
                anchors.centerIn: parent
                text: card.connected ? Root.Icons.btConnected
                    : (card.enabled ? Root.Icons.btOn : Root.Icons.btOff)
                color: card.connected ? Root.Theme.domainNetwork : Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 30 }

                Behavior on color { ColorAnimation { duration: Root.Theme.anim.exitDuration } }
            }
        }

        // Info column
        Column {
            width: parent.width - iconTile.width - togglePill.width - 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: {
                    if (!card.enabled) return "Bluetooth off";
                    if (card.connected && card.deviceName.length > 0) return card.deviceName;
                    if (card.connected) return "Connected";
                    return "Not connected";
                }
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: 14; bold: true }
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: {
                    if (!card.enabled) return "Click to enable";
                    if (card.connected && card.deviceType.length > 0) return card.deviceType;
                    if (card.connected) return "Device connected";
                    return "No devices paired";
                }
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 11 }
                elide: Text.ElideRight
            }
        }

        // Toggle pill
        Rectangle {
            id: togglePill
            width: 30; height: 30
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: toggleMouse.containsMouse
                ? Qt.rgba(Root.Theme.domainNetwork.r,
                          Root.Theme.domainNetwork.g,
                          Root.Theme.domainNetwork.b, 0.32)
                : Qt.rgba(Root.Theme.domainNetwork.r,
                          Root.Theme.domainNetwork.g,
                          Root.Theme.domainNetwork.b, card.enabled ? 0.22 : 0.10)
            border.width: 1
            border.color: Qt.rgba(Root.Theme.domainNetwork.r,
                                  Root.Theme.domainNetwork.g,
                                  Root.Theme.domainNetwork.b,
                                  card.enabled ? 0.55 : 0.25)
            scale: toggleMouse.pressed ? 0.92 : 1.0

            Behavior on color  { ColorAnimation { duration: Root.Theme.anim.microDuration } }
            Behavior on border.color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
            Behavior on scale  { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text: card.enabled ? Root.Icons.btOn : Root.Icons.btOff
                color: Root.Theme.domainNetwork
                font { family: Root.Theme.fontFamily; pixelSize: 16 }
            }

            MouseArea {
                id: toggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (card.svc) card.svc.toggle()
            }
        }
    }

    // Right-click → Settings → Connections
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                let sw = Core.ServiceManager.settingsWindow;
                if (sw && sw.open) sw.open("connections");
                else if (sw && sw.toggle) sw.toggle();
            }
        }
    }
}
