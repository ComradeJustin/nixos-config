import QtQuick
import QtQuick.Layouts
import Niri 0.1
import "../.." as Root

Item {
    id: root
    implicitWidth: bg.width
    implicitHeight: bg.height

    Root.Theme { id: theme }

    property int maxVisible: 6

    Niri {
        id: niri
        Component.onCompleted: {
            connect();
            workspaces.maxCount = root.maxVisible;
        }

        onErrorOccurred: function(error) {
            console.warn("WorkspaceModule: niri error:", error);
        }
    }

    Rectangle {
        id: bg
        width: wsRow.implicitWidth + 24
        height: theme.barHeight - 6
        anchors.verticalCenter: parent.verticalCenter
        radius: 12
        color: theme.wsPillBg
        opacity: 0.5
    }

    Row {
        id: wsRow
        anchors.centerIn: bg
        spacing: 8

        Repeater {
            model: niri.workspaces

            Rectangle {
                width: model.isFocused ? 20 : 10
                height: 10
                radius: 10
                color: model.isFocused ? theme.wsFocused
                     : model.isActive  ? theme.wsActive
                     :                   theme.wsDimmed

                Behavior on width {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: niri.focusWorkspaceById(model.id)
                }
            }
        }
    }
}
