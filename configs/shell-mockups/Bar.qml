import QtQuick
import Quickshell
import Quickshell.Wayland

// The bar: a terminal status line. One row of cells, segments separated by
// a dim "│", bars drawn with block characters.
// Left: workspaces and the focused window. Centre: date and time.
// Right: the playing track, network, volume, battery.
// Sample values, except the clock and the volume the "volume key" changes.
PanelWindow {
    id: bar

    // The shell root (shell.qml).
    required property var shell

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.slab
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Top

    // The divider between segments.
    component Divider: Label {
        text: " │ "
        color: Theme.line
    }

    // A dim key in front of a value, e.g. "vol".
    component Key: Label {
        color: Theme.inkDim
    }

    // How much of the bar's line is typed in. It is erased when the focused
    // window goes fullscreen, because niri covers the bar then, and typed
    // back when it leaves.
    property real typed: shell.fullscreen ? 0 : 1

    Behavior on typed {
        NumberAnimation {
            duration: Theme.typeMs
        }
    }

    // A window onto the bar's line that widens and narrows by whole characters.
    Item {
        width: Theme.snapX(bar.typed * bar.width)
        height: bar.height
        clip: true

        // The line itself, always full width so nothing shifts as it is typed.
        Item {
            width: bar.width
            height: bar.height

            // --- Left: workspaces, focused window ---
            Row {
                x: Theme.cellWidth
                y: Theme.barTextY

                Repeater {
                    model: 5

                    // Focused: reverse video. Occupied: normal. Empty: dim.
                    Rectangle {
                        required property int index

                        readonly property bool focused: index === 1
                        readonly property bool occupied: index < 3

                        width: 3 * Theme.cellWidth
                        height: Theme.cellHeight
                        color: focused ? Theme.accent : "transparent"

                        Label {
                            x: Theme.cellWidth
                            text: parent.index + 1
                            color: parent.focused ? Theme.slab : (parent.occupied ? Theme.ink : Theme.line)
                        }
                    }
                }

                Divider {}

                Label {
                    text: "Cursor — nixos-config"
                }
            }

            // --- Centre: date and time ---
            Row {
                y: Theme.barTextY
                // Rounded so the text lands on whole pixels and stays sharp.
                x: Math.round((parent.width - width) / 2)

                Key {
                    text: Qt.formatDateTime(bar.shell.now, "ddd d MMM") + "  "
                }

                Label {
                    text: Qt.formatDateTime(bar.shell.now, "hh:mm")
                    color: Theme.ink
                }
            }

            // --- Right: track, network, volume, battery ---
            Row {
                y: Theme.barTextY
                x: parent.width - width - Theme.cellWidth

                Key {
                    text: "♪ "
                }

                Label {
                    text: "Shelter"
                }

                Divider {}

                Key {
                    text: "net "
                }

                Label {
                    text: "Home-5G"
                }

                Key {
                    text: " via nixpc"
                }

                Divider {}

                Key {
                    text: "vol "
                }

                Level {
                    level: bar.shell.volume / 100
                    cells: 8
                }

                Label {
                    text: " " + bar.shell.volume + "%"
                    color: Theme.ink
                }

                Divider {}

                Key {
                    text: "bat "
                }

                Level {
                    level: 0.28
                    cells: 8
                }

                Label {
                    text: " 28%"
                    color: Theme.ink
                }
            }
        }
    }
}
