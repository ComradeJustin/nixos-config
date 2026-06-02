import QtQuick
import ".." as Root
import "../components" as Components
import "../core" as Core

// Background weather widget — binds to WeatherService
Components.WidgetFrame {
    id: root
    widgetName: "weather"

    property var weatherService: Core.ServiceManager.weather
    property int fontSize: Root.Config.weatherConfig.fontSize

    Row {
        spacing: Root.Theme.spacingM

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.weatherService ? root.weatherService.icon : Root.Icons.weatherDefault
            color: Root.Theme.widgetText
            font { family: Root.Theme.fontIcons; pixelSize: root.fontSize * 1.2 }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: root.weatherService ? root.weatherService.temperature : "--"
                color: Root.Theme.widgetText
                font { family: Root.Theme.fontDisplay; pixelSize: root.fontSize; weight: Font.Medium }
            }

            Text {
                text: root.weatherService ? root.weatherService.condition : ""
                color: Root.Theme.widgetTextDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Math.round(root.fontSize * 0.4) }
            }
        }
    }
}
