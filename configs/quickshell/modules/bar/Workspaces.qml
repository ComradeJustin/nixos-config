import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    anchors.left: parent.left
    height: 30
    width: 100
    color: "transparent"

    Rectangle {
        id: rowBackground
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        height: 24
        width: rowLayout.implicitWidth + 50
        radius: 12
        color: "#222222"
        opacity: 0.5
    }

    Row {
        id: rowLayout
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 10
        }
        spacing: 10

        Repeater {
            model: niri.workspaces

            Rectangle {
                visible: index < 5
                width: model.isFocused ? 20 : 10

                height: 10
                radius: 10

                color: model.isActive ? '#ffffff' : '#5f5f5f'
                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: 150 }}
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: niri.focusWorkspaceById(model.id)
                }
            }
        }
    }
}