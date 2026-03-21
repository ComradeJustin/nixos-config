import QtQuick
import QtQuick.Layouts
import Niri 0.1
import "../.." as Root

Item {
    id: root
    implicitWidth: wsRow.implicitWidth
    implicitHeight: wsRow.implicitHeight

    // Theme is now a singleton - access via Root.Theme.propertyName

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

    // Workspace indicators - rounded pills that expand when focused
    Row {
        id: wsRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Repeater {
            model: niri.workspaces

            Rectangle {
                id: wsIndicator
                width: model.isFocused ? 18 : 6   // Pill when active, dot otherwise
                height: 6
                radius: 3                          // Fully rounded (half height)
                color: model.isFocused ? Root.Theme.wsFocused : Root.Theme.textPrimary
                opacity: model.isFocused ? 1.0
                       : model.isActive  ? 0.5
                       :                   0.2

                Behavior on width {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                // Subtle scale animation on focus change
                transform: Scale {
                    origin.x: wsIndicator.width / 2
                    origin.y: wsIndicator.height / 2
                    xScale: model.isFocused ? 1.0 : 1.0
                    yScale: model.isFocused ? 1.0 : 1.0
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
