import QtQuick
import QtQuick.Layouts
import Niri 0.1
import "../.." as Root

Item {
    id: root
    implicitWidth: wsRow.implicitWidth
    implicitHeight: wsRow.implicitHeight

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

    // Minimal workspace indicators - fixed size dots with opacity states
    Row {
        id: wsRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Repeater {
            model: niri.workspaces

            Rectangle {
                width: 6
                height: 6
                radius: 0  // Brutalist: fully square
                color: theme.textPrimary
                opacity: model.isFocused ? 1.0
                       : model.isActive  ? 0.5
                       :                   0.2

                Behavior on opacity {
                    NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4  // Larger hit area
                    cursorShape: Qt.PointingHandCursor
                    onClicked: niri.focusWorkspaceById(model.id)
                }
            }
        }
    }
}
