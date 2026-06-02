import QtQuick
import "../../.." as Root
import "../../../components" as Components
import "../../../core" as Core

// WeatherCard — current conditions + 5-day forecast (flat, header-led).
Rectangle {
    id: card

    width: parent ? parent.width : 320
    implicitHeight: body.implicitHeight + Root.Theme.spacingM * 2

    readonly property var svc: Core.ServiceManager.weather
    readonly property bool ready: svc ? svc.initialized : false

    radius: Root.Theme.radiusMedium
    color: Root.Theme.ccSectionBg
    border.width: Root.Theme.borderWidth
    border.color: Root.Theme.borderColor
    clip: true

    // Flat accent strip
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 3
        color: Root.Theme.domainWeather
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

        // ── Header: current-condition icon + title + refresh ──
        Components.CCCardHeader {
            width: parent.width
            icon: card.svc ? card.svc.icon : Root.Icons.weatherDefault
            title: "Weather"
            accent: Root.Theme.domainWeather

            Rectangle {
                id: refreshPill
                width: 28; height: 28
                radius: width / 2
                color: refreshMouse.containsMouse
                    ? Qt.rgba(Root.Theme.domainWeather.r, Root.Theme.domainWeather.g, Root.Theme.domainWeather.b, 0.32)
                    : Qt.rgba(Root.Theme.domainWeather.r, Root.Theme.domainWeather.g, Root.Theme.domainWeather.b, 0.15)
                border.width: 1
                border.color: Qt.rgba(Root.Theme.domainWeather.r, Root.Theme.domainWeather.g, Root.Theme.domainWeather.b, 0.45)
                scale: refreshMouse.pressed ? 0.92 : 1.0

                Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: Root.Icons.reset
                    color: Root.Theme.domainWeather
                    font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSizeL }
                    rotation: card.svc && card.svc.fetching ? 360 : 0
                    Behavior on rotation { NumberAnimation { duration: 600; easing.type: Easing.InOutCubic } }
                }
                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (card.svc) card.svc.fetchWeather()
                }
            }
        }

        // ── Current conditions ──
        Row {
            width: parent.width
            spacing: Root.Theme.spacingM

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: card.svc ? card.svc.temperature : "--"
                color: Root.Theme.textPrimary
                // Display serif for the focal temperature.
                font { family: Root.Theme.fontDisplay; pixelSize: Root.Theme.fontSize4XL; weight: Font.Medium }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: card.svc && card.svc.condition.length > 0
                        ? card.svc.condition
                        : (card.ready ? "No data" : "Loading…")
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS; bold: true }
                }
                Text {
                    visible: card.svc && card.svc.feelsLike.length > 0
                    text: card.svc ? "Feels " + card.svc.feelsLike : ""
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                }
            }
        }

        // ── 5-day forecast ──
        Row {
            width: parent.width
            visible: card.svc && card.svc.forecast.length > 0

            Repeater {
                model: card.svc ? card.svc.forecast : []

                Column {
                    width: (card.svc && card.svc.forecast.length > 0)
                        ? parent.width / card.svc.forecast.length : 0
                    spacing: 3

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.day
                        color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS; bold: true; capitalization: Font.AllUppercase }
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.icon
                        color: Root.Theme.domainWeather
                        font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSizeL }
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.hi + "°"
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeS; bold: true }
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.lo + "°"
                        color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeXS }
                    }
                }
            }
        }
    }
}
