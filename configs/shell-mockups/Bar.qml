import QtQuick
import Quickshell
import Quickshell.Wayland

// The bar: a terminal status line. One row of cells, segments separated by
// dim Powerline arrows that point away from the centre, levels drawn as
// framed progress bars.
// Left: workspaces and the focused window. Centre: date and time.
// Right: the playing track, network, volume, battery.
// Sample values, except the clock, and the volume and the focused workspace,
// which the buttons at the bottom of the screen change.
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
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Top

    // The divider between segments: a thin Powerline arrow. On the left
    // half of the bar it points right, on the right half it points left.
    component Divider: Label {
        property bool pointsLeft: false

        text: pointsLeft ? " \ue0b3 " : " \ue0b1 "
        color: Theme.line
    }

    // A dim key in front of a value, e.g. "vol".
    component Key: Label {
        color: Theme.inkDim
    }

    // How much of the bar is showing: 1 normally, 0 while the focused window
    // is fullscreen. niri keeps the bar drawn on top of a window for about a
    // second while it goes fullscreen, so the bar gets out of the way
    // itself: the whole bar, background included, dithers away, and dithers
    // back when the window leaves fullscreen.
    property real shown: shell.fullscreen ? 0 : 1

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    // The bar's surface: its background and its line of text.
    Rectangle {
        anchors.fill: parent
        visible: bar.shown > 0
        color: Theme.slab
        // Drawn through the dither only while it is changing; at rest the
        // text is drawn directly.
        layer.enabled: bar.shown < 1
        layer.effect: DitherFade {
            amount: bar.shown
        }

        // --- Left: workspaces, focused window ---
        Row {
            x: Theme.cellWidth
            y: Theme.barTextY

            Repeater {
                model: 5

                // Focused: reverse video, flashing bright for a moment as
                // it takes focus. Occupied: normal. Empty: dim.
                Rectangle {
                    required property int index

                    readonly property bool focused: index === bar.shell.workspace
                    readonly property bool occupied: index < 3

                    width: 3 * Theme.cellWidth
                    height: Theme.cellHeight
                    color: focusFlash.running ? Theme.ink : (focused ? Theme.accent : "transparent")

                    onFocusedChanged: {
                        if (focused)
                            focusFlash.restart();
                    }

                    Label {
                        x: Theme.cellWidth
                        text: parent.index + 1
                        color: parent.focused ? Theme.slab : (parent.occupied ? Theme.ink : Theme.line)
                    }

                    Timer {
                        id: focusFlash

                        interval: Theme.flashMs
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

            Divider {
                pointsLeft: true
            }

            Key {
                text: "net "
            }

            Label {
                text: "Home-5G"
            }

            Key {
                text: " → nixpc"
            }

            Divider {
                pointsLeft: true
            }

            Key {
                text: "vol "
            }

            Level {
                level: bar.shell.volume / 100
                cells: 8
            }

            Label {
                text: " "
            }

            Value {
                text: bar.shell.volume + "%"
            }

            Divider {
                pointsLeft: true
            }

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
