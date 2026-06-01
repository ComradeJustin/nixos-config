import QtQuick
import ".." as Root
import "../components" as Components

// Background clock widget with time and date display
Components.WidgetFrame {
    id: root
    widgetName: "clock"

    readonly property var cfg: Root.Config.clockConfig
    property string timeFormat: cfg.showSeconds ? cfg.timeFormat.replace("mm", "mm:ss") : cfg.timeFormat
    property string dateFormat: cfg.dateFormat
    property bool showDate: cfg.showDate
    property bool showSeconds: cfg.showSeconds
    property int clockFontSize: cfg.fontSize

    property string currentTime: ""
    property string currentDate: ""

    Timer {
        id: clockTimer
        interval: root.showSeconds ? 1000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let now = new Date();
            root.currentTime = Qt.formatDateTime(now, root.timeFormat);
            root.currentDate = Qt.formatDateTime(now, root.dateFormat);
        }
    }

    Column {
        spacing: Root.Theme.spacingXS

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.currentTime
            color: Root.Theme.widgetText
            font {
                family: Root.Theme.fontDisplay
                pixelSize: root.clockFontSize
                bold: true
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showDate
            text: root.currentDate
            color: Root.Theme.widgetTextDimmed
            font {
                family: Root.Theme.fontFamily
                pixelSize: Math.round(root.clockFontSize * 0.35)
            }
        }
    }
}
