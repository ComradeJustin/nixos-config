import QtQuick
import "../../.." as Root
import "../../../core" as Core

// WeatherCard — current conditions at a glance.
Rectangle {
    id: card

    width: parent ? parent.width : 320
    implicitHeight: 96

    readonly property var svc: Core.ServiceManager.weather
    readonly property bool ready: svc ? svc.initialized : false

    radius: Root.Theme.radiusMedium
    color: Root.Theme.ccSectionBg
    border.width: Root.Theme.borderWidth
    border.color: Root.Theme.borderColor
    clip: true

    // Soft domain glow
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: card.ready
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Qt.rgba(Root.Theme.domainWeather.r,
                               Root.Theme.domainWeather.g,
                               Root.Theme.domainWeather.b, 0.12)
            }
            GradientStop { position: 0.9; color: "transparent" }
        }
    }

    Row {
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
            color: Qt.rgba(Root.Theme.domainWeather.r,
                           Root.Theme.domainWeather.g,
                           Root.Theme.domainWeather.b, card.ready ? 0.22 : 0.08)
            border.width: 1
            border.color: Qt.rgba(Root.Theme.domainWeather.r,
                                  Root.Theme.domainWeather.g,
                                  Root.Theme.domainWeather.b, card.ready ? 0.5 : 0.2)

            Behavior on color { ColorAnimation { duration: Root.Theme.anim.exitDuration } }
            Behavior on border.color { ColorAnimation { duration: Root.Theme.anim.exitDuration } }

            Text {
                anchors.centerIn: parent
                text: card.svc ? card.svc.icon : Root.Icons.weatherDefault
                color: card.ready ? Root.Theme.domainWeather : Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 28 }
                Behavior on color { ColorAnimation { duration: Root.Theme.anim.exitDuration } }
            }
        }

        // Info column
        Column {
            width: parent.width - iconTile.width - refreshPill.width - 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: card.svc ? card.svc.temperature : "--"
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: 22; bold: true }
            }

            Text {
                width: parent.width
                text: card.svc && card.svc.condition.length > 0
                    ? card.svc.condition
                    : (card.ready ? "No data" : "Loading...")
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 11 }
                elide: Text.ElideRight
            }
        }

        // Refresh pill
        Rectangle {
            id: refreshPill
            width: 30; height: 30
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: refreshMouse.containsMouse
                ? Qt.rgba(Root.Theme.domainWeather.r,
                          Root.Theme.domainWeather.g,
                          Root.Theme.domainWeather.b, 0.32)
                : Qt.rgba(Root.Theme.domainWeather.r,
                          Root.Theme.domainWeather.g,
                          Root.Theme.domainWeather.b, 0.15)
            border.width: 1
            border.color: Qt.rgba(Root.Theme.domainWeather.r,
                                  Root.Theme.domainWeather.g,
                                  Root.Theme.domainWeather.b, 0.45)
            scale: refreshMouse.pressed ? 0.92 : 1.0

            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text: Root.Icons.reset
                color: Root.Theme.domainWeather
                font { family: Root.Theme.fontFamily; pixelSize: 14 }
                rotation: card.svc && card.svc.fetching ? 360 : 0
                Behavior on rotation { NumberAnimation { duration: 600; easing.type: Easing.InOutCubic } }
            }

            MouseArea {
                id: refreshMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (card.svc) card.svc.fetchWeather()
            }
        }
    }
}
