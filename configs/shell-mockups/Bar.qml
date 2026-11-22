import QtQuick
import Quickshell
import Quickshell.Wayland

// The bar: a terminal status line. One row of cells, segments separated by
// dim Powerline arrows that point away from the centre, levels drawn as
// framed progress bars.
// Left: workspaces, the focused window, the playing track, the count of
// waiting notifications, and a system rebuild while one is running.
// Centre: date and time. Right: network with its signal, volume, battery.
// A halftone shadow falls under it.
// One bar is made for each screen (shell.qml).
//
// Trouble is shown in the alert colour together with a word or mark: no
// network, muted sound, a low battery.
// Sample values, except the clock and whatever the buttons at the bottom of
// the screen change.
PanelWindow {
    id: bar

    // The shell root (shell.qml).
    required property var shell

    anchors {
        top: true
        left: true
        right: true
    }
    // The window is taller than the bar by its shadow. Windows are kept
    // clear of the bar itself, and the shadow falls over their top edge.
    implicitHeight: Theme.barHeight + Theme.shadowOffset
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barHeight
    // Clicks on the shadow go to the window under it.
    mask: Region {
        item: slab
    }
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

    // A dim key in front of a value, e.g. "vol", set in the font's small
    // capitals so it reads as a label and not as part of the value.
    component Key: Label {
        color: Theme.inkDim
        smallCaps: true
    }

    readonly property bool batteryLow: shell.battery <= 0.2 && !shell.charging

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

    // The bar's surface: its shadow, its background and its line of text.
    Item {
        anchors.fill: parent
        visible: bar.shown > 0
        // Drawn through the dither only while it is changing; at rest the
        // text is drawn directly.
        layer.enabled: bar.shown < 1
        layer.effect: DitherFade {
            amount: bar.shown
        }

        // The shadow: a strip under the bar with every other dot left out,
        // like the one panels cast.
        Rectangle {
            y: Theme.barHeight
            width: parent.width
            height: Theme.shadowOffset
            color: Theme.shadow
            layer.enabled: true
            layer.effect: DitherFade {
                amount: 0.5
            }
        }

        Rectangle {
            id: slab

            width: parent.width
            height: Theme.barHeight
            color: Theme.slab

            // --- Left: workspaces, focused window, playing track ---
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

                Divider {}

                Key {
                    text: "♪ "
                }

                Label {
                    text: "Shelter"
                }

                // Notifications waiting in the Inbox.
                Divider {
                    visible: bar.shell.unreadCount > 0
                }

                Key {
                    visible: bar.shell.unreadCount > 0
                    text: "✦ "
                }

                Value {
                    visible: bar.shell.unreadCount > 0
                    text: bar.shell.unreadCount
                }

                // A system rebuild, only while one is running: wiped in
                // when it starts and away when it finishes.
                Row {
                    id: rebuild

                    property real shown: bar.shell.rebuilding ? 1 : 0

                    Behavior on shown {
                        NumberAnimation {
                            duration: Theme.wipeMs
                        }
                    }

                    visible: shown > 0
                    layer.enabled: shown < 1
                    layer.effect: DitherFade {
                        amount: rebuild.shown
                        spread: Theme.wipeFront
                    }

                    Divider {}

                    Spinner {}

                    Key {
                        text: " nh "
                    }

                    Level {
                        level: bar.shell.rebuildProgress
                        cells: 6
                    }

                    Label {
                        text: " " + Math.round(bar.shell.rebuildProgress * 100) + "%"
                        color: Theme.ink
                    }
                }
            }

            // --- Centre: date and time ---
            Row {
                y: Theme.barTextY
                // Rounded so the text lands on whole pixels and stays sharp.
                x: Math.round((parent.width - width) / 2)

                Label {
                    text: Qt.formatDateTime(bar.shell.now, "ddd d MMM") + "  "
                    color: Theme.inkDim
                }

                Label {
                    text: Qt.formatDateTime(bar.shell.now, "hh:mm")
                    color: Theme.ink
                }
            }

            // --- Right: network, volume, battery ---
            Row {
                y: Theme.barTextY
                x: parent.width - width - Theme.cellWidth

                Key {
                    text: "net "
                }

                SignalBars {
                    level: bar.shell.online ? 0.75 : 0
                }

                Label {
                    text: bar.shell.online ? " Home-5G" : " offline"
                    color: bar.shell.online ? Theme.inkSoft : Theme.alert
                }

                Label {
                    visible: bar.shell.online
                    text: " → nixpc"
                    color: Theme.inkDim
                }

                Divider {
                    pointsLeft: true
                }

                Key {
                    text: "vol "
                }

                Level {
                    level: bar.shell.muted ? 0 : bar.shell.volume / 100
                    cells: 10
                }

                Label {
                    text: " "
                }

                Value {
                    text: bar.shell.muted ? "mute" : bar.shell.volume + "%"
                    restColor: bar.shell.muted ? Theme.alert : Theme.ink
                }

                Divider {
                    pointsLeft: true
                }

                Key {
                    text: "bat "
                }

                Level {
                    level: bar.shell.battery
                    cells: 10
                    fillColor: bar.batteryLow ? Theme.alert : Theme.accent
                }

                // An arrow while charging.
                Label {
                    text: bar.shell.charging ? " ↑" : " "
                    color: Theme.accent
                }

                Value {
                    text: Math.round(bar.shell.battery * 100) + "%" + (bar.batteryLow ? " !" : "")
                    restColor: bar.batteryLow ? Theme.alert : Theme.ink
                }
            }
        }
    }
}
