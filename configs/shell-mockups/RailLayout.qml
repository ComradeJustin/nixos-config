import QtQuick
import Quickshell
import Quickshell.Wayland

// Layout B — "Side rail".
// A narrow rail on the left edge. niri stacks workspaces vertically and
// scrolls windows sideways, so a vertical workspace list matches how the
// desktop actually moves, and the rail costs width (which scrolls anyway)
// instead of height. Top: workspaces. Bottom: status, then the clock.
Scope {
    id: layout

    // The shell root (shell.qml), which holds which layout and panels are shown.
    required property var shell
    readonly property bool shown: shell.layout === "rail"

    PanelWindow {
        visible: layout.shown
        anchors {
            left: true
            top: true
            bottom: true
        }
        implicitWidth: 44
        color: "transparent"
        WlrLayershell.namespace: "shell-mockup"
        WlrLayershell.layer: WlrLayer.Top

        Rectangle {
            anchors.fill: parent
            color: Theme.surface

            // Hairline along the rail's inner edge.
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: 1
                color: Theme.stroke
            }

            Workspaces {
                anchors.top: parent.top
                anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                vertical: true
            }

            Column {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                StatusIcons {
                    anchors.horizontalCenter: parent.horizontalCenter
                    vertical: true
                    labelSize: 10
                    onClicked: layout.shell.panelOpen = !layout.shell.panelOpen
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 16
                    height: 1
                    color: Theme.stroke
                }

                // The clock, hours over minutes.
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(layout.shell.now, "hh")
                        color: Theme.textStrong
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(layout.shell.now, "mm")
                        color: Theme.textStrong
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(layout.shell.now, "ddd")
                    color: Theme.textDim
                    font.family: Theme.fontUi
                    font.pixelSize: 10
                }
            }
        }
    }

    // Status panel, opening beside the bottom of the rail.
    PanelWindow {
        visible: layout.shown && layout.shell.panelOpen
        anchors {
            left: true
            bottom: true
        }
        margins {
            left: 8
            bottom: 8
        }
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight
        color: "transparent"
        WlrLayershell.namespace: "shell-mockup"
        WlrLayershell.layer: WlrLayer.Overlay

        StatusPanel {
            id: panel

            now: layout.shell.now
        }
    }

    // Notification toast, top right.
    PanelWindow {
        visible: layout.shown && layout.shell.toastOpen
        anchors {
            top: true
            right: true
        }
        margins {
            top: 8
            right: 8
        }
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        implicitWidth: toast.implicitWidth
        implicitHeight: toast.implicitHeight
        color: "transparent"
        WlrLayershell.namespace: "shell-mockup"
        WlrLayershell.layer: WlrLayer.Overlay

        NotificationCard {
            id: toast

            floating: true
        }
    }
}
