import QtQuick
import "../../.." as Root
import "../../../components" as Components
import "../../../core" as Core

// NetworkCard — Control Center network pane (flat, header-led).
// Header: accent wifi icon + "Network" + a radio toggle pill on the right.
// Body: current SSID / status. Right-click opens Settings → Connections.
Rectangle {
    id: card

    width: parent ? parent.width : 320
    implicitHeight: body.implicitHeight + Root.Theme.spacingM * 2

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

    // Flat accent strip
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 3
        color: Root.Theme.domainNetwork
    }

    Column {
        id: body
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            leftMargin: Root.Theme.spacingM + 3
            rightMargin: Root.Theme.spacingM
            topMargin: Root.Theme.spacingM
        }
        spacing: Root.Theme.spacingM

        // ── Header: icon + title + radio toggle pill ──
        Components.CCCardHeader {
            width: parent.width
            icon: Root.Icons.wifiIcon(card.svc)
            title: "Network"
            accent: Root.Theme.domainNetwork

            Rectangle {
                id: togglePill
                width: 30; height: 30
                radius: width / 2
                color: toggleMouse.containsMouse
                    ? Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.32)
                    : Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, card.enabled ? 0.22 : 0.10)
                border.width: 1
                border.color: Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, card.enabled ? 0.55 : 0.25)
                scale: toggleMouse.pressed ? 0.92 : 1.0

                Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                Behavior on border.color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

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

        // ── Status ──
        Column {
            width: parent.width
            spacing: 2

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
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeL; bold: true }
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: {
                    if (!card.enabled)  return "Click the toggle to enable";
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
    }

    // Right-click anywhere → Settings → Connections
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
