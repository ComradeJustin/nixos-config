import QtQuick
import Quickshell
import Quickshell.Wayland

// The bar: one line of type and nothing else.
// Left: workspace numbers and the focused window. Centre: date and time.
// Right: network and battery. Volume is not here; it shows itself when it
// changes (VolumeReadout). Sample values, except the clock.
PanelWindow {
    id: bar

    // The shell root (shell.qml).
    required property var shell

    // Space between the screen edge and the first and last words.
    readonly property int edgeMargin: 18

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 30
    color: Theme.slab
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Top

    // --- Left: workspaces, then the focused window ---
    Row {
        anchors.left: parent.left
        anchors.leftMargin: bar.edgeMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: 22

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 13

            Repeater {
                model: 5

                // Focused: heavy and in the accent colour. Occupied: normal. Empty: dim.
                Label {
                    required property int index

                    readonly property bool focused: index === 1
                    readonly property bool occupied: index < 3

                    text: index + 1
                    mono: true
                    weight: focused ? 900 : 450
                    color: focused ? Theme.accent : (occupied ? Theme.inkSoft : Theme.inkDim)
                    opacity: occupied || focused ? 1 : 0.55
                }
            }
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "Cursor — nixos-config"
        }
    }

    // --- Centre: date, then the time ---
    Row {
        anchors.centerIn: parent
        spacing: 10

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(bar.shell.now, "ddd d MMM")
            color: Theme.inkDim
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(bar.shell.now, "hh:mm")
            mono: true
            weight: 800
            color: Theme.ink
        }
    }

    // --- Right: network, then battery ---
    Row {
        anchors.right: parent.right
        anchors.rightMargin: bar.edgeMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: 22

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Label {
                text: "Home-5G"
            }

            Label {
                text: "via nixpc"
                color: Theme.inkDim
            }
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "28%"
            mono: true
            weight: 800
            color: Theme.ink
        }
    }
}
