import QtQuick
import ".." as Root

// Background clock widget with time and date display
Item {
    id: root

    // Config properties (from Config.qml)
    property string timeFormat: "HH:mm"
    property string dateFormat: "dddd, MMMM d"
    property bool showDate: true
    property bool showSeconds: false
    property int clockFontSize: 48

    implicitWidth: content.implicitWidth + Root.Theme.widgetPadding * 2
    implicitHeight: content.implicitHeight + Root.Theme.widgetPadding * 2

    // Current time/date
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

    // Shadow layer
    Rectangle {
        anchors.fill: bg
        anchors.margins: -2
        anchors.topMargin: 2
        radius: Root.Theme.widgetRadius + 2
        color: Root.Theme.widgetShadowColor
        opacity: 0.4
    }

    // Widget background
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Root.Theme.widgetRadius
        color: Root.Theme.widgetBackground
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor
    }

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.currentTime
            color: Root.Theme.widgetText
            font {
                family: Root.Theme.fontMono
                pixelSize: root.clockFontSize
                bold: true
            }
        }

        Text {
            id: dateText
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
