import QtQuick
import Quickshell
import Quickshell.Wayland

// Layout A — "Top bar".
// A slim bar attached to the top edge. Left: workspaces and the focused
// window. Centre: date and time. Right: the status cluster, which opens the
// status panel underneath it. Costs 30 pixels of height.
Scope {
    id: layout

    // The shell root (shell.qml), which holds which layout and panels are shown.
    required property var shell
    readonly property bool shown: shell.layout === "bar"

    PanelWindow {
        visible: layout.shown
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 30
        color: "transparent"
        WlrLayershell.namespace: "shell-mockup"
        WlrLayershell.layer: WlrLayer.Top

        Rectangle {
            anchors.fill: parent
            color: Theme.surface

            // Hairline under the bar.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.stroke
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16

                Workspaces {
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "nixos-config — Cursor"
                    color: Theme.textDim
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(layout.shell.now, "ddd d MMM")
                    color: Theme.textDim
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(layout.shell.now, "hh:mm")
                    color: Theme.textStrong
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                }
            }

            StatusIcons {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                onClicked: layout.shell.panelOpen = !layout.shell.panelOpen
            }
        }
    }

    // Status panel, dropping from the right end of the bar.
    PanelWindow {
        visible: layout.shown && layout.shell.panelOpen
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

    // Notification toast, top right. It moves below the panel when both show.
    PanelWindow {
        visible: layout.shown && layout.shell.toastOpen
        anchors {
            top: true
            right: true
        }
        margins {
            top: layout.shell.panelOpen ? panel.implicitHeight + 16 : 8
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
