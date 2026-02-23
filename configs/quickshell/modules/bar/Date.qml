import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    Text {
        property string date: "  " + Qt.formatDateTime(clock.date, "dddd dd MMM")

        id: timeBlock
        anchors {
            verticalCenter: parent.verticalCenter
        }
        text: date
        color: '#ffffff'
        font.family: "Jost* 600 Semi"
        font.pixelSize: 16
        Component.onCompleted: {
            parent.width = timeBlock.contentWidth
        }
    }
}
