import QtQuick
import "../../.." as Root
import "../../../components" as Components
import "../../../core" as Core

// NightLightCard — Control Center night light pane (flat, header-led).
// Header: state icon + "Night Light" + toggle pill.
// Body: state + day/night temperature. Right-click opens Settings → Display.
Rectangle {
    id: card

    width: parent ? parent.width : 320
    implicitHeight: body.implicitHeight + Root.Theme.spacingM * 2

    readonly property var svc: Core.ServiceManager.nightLight
    readonly property bool enabled: svc ? svc.enabled : false
    readonly property bool active:  svc ? svc.active  : false
    readonly property int dayTemp:   svc ? svc.dayTemp   : 6500
    readonly property int nightTemp: svc ? svc.nightTemp : 4000

    // Warm yellow accent
    readonly property color accent: Root.Theme.domainNotifications

    radius: Root.Theme.radiusMedium
    color: Root.Theme.ccSectionBg
    border.width: Root.Theme.borderWidth
    border.color: Root.Theme.borderColor
    clip: true

    // Flat accent strip
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 3
        color: card.accent
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

        Components.CCCardHeader {
            width: parent.width
            icon: card.active ? Root.Icons.nightOn : Root.Icons.nightOff
            title: "Night Light"
            accent: card.accent

            Rectangle {
                id: togglePill
                width: 30; height: 30
                radius: width / 2
                color: toggleMouse.containsMouse
                    ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.32)
                    : Qt.rgba(card.accent.r, card.accent.g, card.accent.b, card.enabled ? 0.22 : 0.10)
                border.width: 1
                border.color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, card.enabled ? 0.55 : 0.25)
                scale: toggleMouse.pressed ? 0.92 : 1.0

                Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                Behavior on border.color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: card.enabled ? Root.Icons.nightOn : Root.Icons.nightOff
                    color: card.accent
                    font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize2XL }
                }
                MouseArea {
                    id: toggleMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (card.svc) card.svc.toggle()
                }
            }
        }

        Column {
            width: parent.width
            spacing: 2

            Text {
                width: parent.width
                text: card.active ? "Night Light on" : (card.enabled ? "Waiting for location" : "Night Light off")
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeL; bold: true }
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: {
                    if (!card.enabled) return "Click the toggle to enable";
                    if (card.active) return card.dayTemp + "K day · " + card.nightTemp + "K night";
                    return "wlsunset not running";
                }
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                elide: Text.ElideRight
            }
        }
    }

    // Right-click anywhere → Settings → Display
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                let sw = Core.ServiceManager.settingsWindow;
                if (sw && sw.open) sw.open("display");
                else if (sw && sw.toggle) sw.toggle();
            }
        }
    }
}
