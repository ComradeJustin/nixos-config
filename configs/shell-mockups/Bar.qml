import QtQuick
import Quickshell
import Quickshell.Wayland

// The bar: a strip of ruled cells along the top edge, laid out like a
// departure board. Every cell is a small label over its value.
// Left: workspaces and the focused window. Centre: date and time.
// Right: network, tailnet, volume, battery. Sample values, except the clock.
PanelWindow {
    id: bar

    // The shell root (shell.qml).
    required property var shell

    readonly property int barHeight: 36
    // Horizontal padding inside every cell.
    readonly property int cellPadding: 14

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: barHeight
    color: Theme.slab
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Top

    // One cell: a small label on the first line, the value on the second.
    component Cell: Item {
        id: cell

        property string label
        default property alias content: valueRow.data

        implicitWidth: Math.max(cellLabel.implicitWidth, valueRow.implicitWidth) + bar.cellPadding * 2
        height: bar.barHeight

        Label {
            id: cellLabel

            x: bar.cellPadding
            y: 6
            text: cell.label
            caps: true
            color: Theme.inkDim
            font.pixelSize: 8
        }

        Row {
            id: valueRow

            x: bar.cellPadding
            y: 16
            height: 14
            spacing: 8
        }
    }

    // The value text inside a cell.
    component Value: Label {
        anchors.verticalCenter: parent.verticalCenter
        caps: true
        weight: 650
        color: Theme.ink
        font.pixelSize: 11
    }

    // The vertical rule between cells.
    component Rule: Rectangle {
        width: 1
        height: bar.barHeight
        color: Theme.rule
    }

    // --- Left: workspaces, focused window ---
    Row {
        anchors.left: parent.left

        Cell {
            label: "workspace"

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: 5

                    // Focused: an inverted block. Occupied: outlined. Empty: just the number.
                    Rectangle {
                        required property int index

                        readonly property bool focused: index === 1
                        readonly property bool occupied: index < 3

                        width: 20
                        height: 14
                        color: focused ? Theme.accent : "transparent"
                        border.width: occupied && !focused ? 1 : 0
                        border.color: Theme.rule

                        Label {
                            anchors.centerIn: parent
                            text: parent.index + 1
                            weight: parent.focused ? 800 : 550
                            color: parent.focused ? Theme.onAccent : (parent.occupied ? Theme.ink : Theme.inkDim)
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }

        Rule {}

        Cell {
            label: "focus"

            Value {
                text: "Cursor — nixos-config"
            }
        }

        Rule {}
    }

    // --- Centre: date over time ---
    Row {
        anchors.horizontalCenter: parent.horizontalCenter

        Rule {}

        Cell {
            label: Qt.formatDateTime(bar.shell.now, "ddd d MMM")

            Value {
                text: Qt.formatDateTime(bar.shell.now, "hh:mm")
                weight: 850
                font.pixelSize: 13
            }
        }

        Rule {}
    }

    // --- Right: network, tailnet, volume, battery ---
    Row {
        anchors.right: parent.right

        Rule {}

        Cell {
            label: "network"

            Value {
                text: "Home-5G"
            }

            LevelBar {
                anchors.verticalCenter: parent.verticalCenter
                level: 0.75
            }
        }

        Rule {}

        Cell {
            label: "tailnet"

            Value {
                text: "exit nixpc"
            }
        }

        Rule {}

        Cell {
            label: "volume"

            Value {
                text: bar.shell.volume
            }

            LevelBar {
                anchors.verticalCenter: parent.verticalCenter
                level: bar.shell.volume / 100
            }
        }

        Rule {}

        Cell {
            label: "battery"

            Value {
                text: "28%"
            }

            LevelBar {
                anchors.verticalCenter: parent.verticalCenter
                level: 0.28
            }
        }
    }

    // Rule along the bottom of the bar.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.rule
    }
}
