import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

Rectangle {
    Text {
        id: powerDisplay
        anchors {
            verticalCenter: parent.verticalCenter
        }
        text: Number(UPower.displayDevice.percentage * 100).toFixed(2) + "%"
        color: '#ffffff'
        font.family: "Jost* 600 Semi"
        font.pixelSize: 16
        Component.onCompleted: {
            parent.width = powerDisplay.contentWidth
        }
    }
}