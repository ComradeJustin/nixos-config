import QtQuick
import QtQuick.Effects
import "../../.." as Root
import "../../../components" as Components
import "../../../core" as Core

// NetworkCard — Control Center network pane.
//
// Matches PlayerCard's visual language (rounded rect, ccSectionBg,
// rounded thumbnail tile on the left, info column on the right, accent
// pill as primary action) but is themed around `domainNetwork` instead
// of `domainMedia`.
//
// Bound to Core.ServiceManager.wifi. Left-click the accent pill toggles
// the wifi radio. Right-click anywhere on the card opens Settings →
// Connections so the user can pick a network from the full list.
Rectangle {
    id: card

    width: parent ? parent.width : 320
    implicitHeight: 96

    readonly property var svc: Core.ServiceManager.wifi
    readonly property bool enabled:   svc ? svc.enabled   : false
    readonly property bool connected: svc ? svc.connected : false
    readonly property string ssid:    svc ? svc.ssid      : ""
    readonly property int sig:        svc ? svc.signal    : -1
    readonly property string iface:   svc ? svc.iface     : ""

    radius: Root.Theme.radiusMedium
    color: Root.Theme.ccSectionBg
    border.width: Root.Theme.borderWidth
    border.color: Root.Theme.borderColor
    clip: true

    // ── Soft domain-tinted glow behind the icon tile ──
    // Provides a subtle brand color wash without the heavy cost of a
    // full blurred artwork background (which the player card needs).
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

    // ── Layer: Content row ──
    Row {
        id: contentRow
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Root.Theme.spacingM
        }
        spacing: Root.Theme.spacingM

        // Icon tile on the left — mirrors PlayerCard's artFg
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
                text: Root.Icons.wifiIcon(card.svc)
                color: card.connected ? Root.Theme.domainNetwork : Root.Theme.textDimmed
                font { family: Root.Theme.fontIcons; pixelSize: 30 }

                Behavior on color { ColorAnimation { duration: Root.Theme.anim.exitDuration } }
            }
        }

        // SSID / status column
        Column {
            width: parent.width - iconTile.width - togglePill.width - 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: Root.Theme.spacingXS

            Text {
                width: parent.width
                text: {
                    if (!card.enabled)  return "Wi-Fi off";
                    if (card.iface === "ethernet") return "Ethernet";
                    if (card.connected && card.ssid.length > 0) return card.ssid;
                    if (card.connected) return "Connected";
                    return "Not connected";
                }
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXL; bold: true }
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: {
                    if (!card.enabled)  return "Click to enable";
                    if (card.iface === "ethernet") return "Wired connection";
                    if (card.connected) {
                        if (card.sig >= 0) return "Signal " + card.sig + "%";
                        return "Connected";
                    }
                    return "Right-click to pick a network";
                }
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                elide: Text.ElideRight
            }
        }

        // Always-lit toggle pill — mirrors PlayerCard's play/pause pill
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
                text: card.enabled ? Root.Icons.wifiHi : Root.Icons.wifiOff
                color: Root.Theme.domainNetwork
                font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize2XL }
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

    // Right-click anywhere on the card opens the full Connections tab of
    // the Settings window. This matches the right-click-quick-toggle →
    // settings pattern already wired up in ControlCenter.
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
