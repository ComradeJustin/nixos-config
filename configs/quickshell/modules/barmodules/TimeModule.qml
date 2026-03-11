import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Root.Theme { id: theme }

    property string dateFormat: "+%a %b %d"
    property string timeFormat: "+%H:%M"
    property string dateText: ""
    property string timeText: ""

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: theme.iconCal
            color: theme.textPrimary
            font { family: theme.fontFamily; pixelSize: theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.dateText || "--"
            color: theme.textPrimary
            font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            anchors.verticalCenter: parent.verticalCenter
        }

        Item { width: 8; height: 1 }

        Text {
            text: theme.iconClock
            color: theme.textPrimary
            font { family: theme.fontFamily; pixelSize: theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.timeText || "--:--"
            color: theme.textPrimary
            font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Process {
        id: dateProc
        command: ["date", root.dateFormat]
        running: true

        stdout: SplitParser {
            onRead: data => { root.dateText = data; }
        }

        onExited: timeProc.running = true
    }

    Process {
        id: timeProc
        command: ["date", root.timeFormat]

        stdout: SplitParser {
            onRead: data => { root.timeText = data; }
        }

        onExited: pollTimer.start()
    }

    Timer {
        id: pollTimer
        interval: 1000
        onTriggered: dateProc.running = true
    }
}
