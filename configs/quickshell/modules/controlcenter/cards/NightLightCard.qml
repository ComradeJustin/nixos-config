import QtQuick
import QtQuick.Effects
import "../../.." as Root
import "../../../components" as Components
import "../../../core" as Core

// NightLightCard — Control Center night light pane.
//
// Follows NetworkCard's visual language themed with domainNotifications
// (warm yellow, base0A) — fits the "warm screen" theme.
//
// Bound to Core.ServiceManager.nightLight (NightLightService). Left-click
// the pill toggles night light. Right-click opens Settings → Display.
Rectangle {
    id: card

    width: parent ? parent.width : 320
    implicitHeight: 96

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

    // ── Soft warm glow ──
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: card.active
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.18)
            }
            GradientStop { position: 0.9; color: "transparent" }
        }
        Behavior on opacity { NumberAnimation { duration: 250 } }
        opacity: card.active ? 1 : 0
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
            color: card.active
                ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.22)
                : Root.Theme.base02
            border.width: 1
            border.color: card.active
                ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.5)
                : Root.Theme.borderColor

            Behavior on color  { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

            Text {
                anchors.centerIn: parent
                text: card.active ? Root.Icons.nightOn : Root.Icons.nightOff
                color: card.active ? card.accent : Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 30 }

                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        // Info column
        Column {
            width: parent.width - iconTile.width - togglePill.width - 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: card.active ? "Night Light on" : (card.enabled ? "Waiting for location" : "Night Light off")
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: 14; bold: true }
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: {
                    if (!card.enabled) return "Click to enable";
                    if (card.active) return card.dayTemp + "K day · " + card.nightTemp + "K night";
                    return "wlsunset not running";
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
                ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.32)
                : Qt.rgba(card.accent.r, card.accent.g, card.accent.b, card.enabled ? 0.22 : 0.10)
            border.width: 1
            border.color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b,
                                  card.enabled ? 0.55 : 0.25)
            scale: toggleMouse.pressed ? 0.92 : 1.0

            Behavior on color  { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }
            Behavior on scale  { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text: card.enabled ? Root.Icons.nightOn : Root.Icons.nightOff
                color: card.accent
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

    // Right-click → Settings → Display
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
