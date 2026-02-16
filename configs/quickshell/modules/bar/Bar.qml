import QtQuick
import QtQuick.Layouts
import Quickshell

PanelWindow {


    id: bar
    anchors {
        top: true
    }

    margins {
        top: 5
    }
    implicitWidth: Screen.width * 0.95
    implicitHeight: 30
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: '#383838'
        radius: 15


        opacity: 0.75;
    }
    // left
    RowLayout {
        anchors {
            left: parent.left
            leftMargin: 20
        }
        Text {
            text: ""
            font.family: "Jost* 600 Semi"
            font.pixelSize: 16
            color: '#ffffff'
            elide: Text.ElideRight
            wrapMode: Text.NoWrap

            Layout.maximumWidth: 500
            Layout.alignment: Qt.AlignVCenter
        }
        Item { Layout.preferredWidth: 5 }
        Loader { active: true; sourceComponent: Workspaces {} }
        /* Item { Layout.preferredWidth: 125 }   // fixed spacer
        // Window title
        Text {
            text: niri.focusedWindow?.title ?? ""
            font.family: "Jost* 600 Semi"
            font.pixelSize: 16
            color: '#ffffff'
            elide: Text.ElideRight
            wrapMode: Text.NoWrap

            Layout.maximumWidth: 500
            Layout.alignment: Qt.AlignVCenter
        }
        */}

        // center
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }
            spacing: 10
            Loader { active: true; sourceComponent: Time {} }

        }
        // right
        RowLayout {
            anchors {
                verticalCenter: parent.verticalCenter
                right: parent.right
                rightMargin: 25
            }

            Loader { active: true; sourceComponent: Audio {} }

        }
    }
