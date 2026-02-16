import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    Text {
        id: timeBlock
        anchors {
            verticalCenter: parent.verticalCenter
        }
        text: Qt.formatDateTime(clock.date, "hh:mm dd MMM, yyyy")
        color: '#ffffff'
        font.family: "Jost* 600 Semi"
        font.pixelSize: 16
        Component.onCompleted: {
            parent.width = timeBlock.contentWidth
        }
    }
}
