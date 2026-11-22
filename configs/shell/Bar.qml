import QtQuick
import Quickshell
import Quickshell.Wayland

// The bar: a terminal status line. One row of cells, segments separated by
// dim Powerline arrows that point away from the centre, levels drawn as
// framed progress bars.
// Left: this screen's workspaces, the focused window, the playing track.
// Centre: date and time. Right: the input method, network with its
// signal, volume, battery.
// A halftone shadow falls under it.
// One bar is made for each screen (shell.qml), and everything it shows is
// real: it comes from shell.qml.
//
// The left half has to fit in front of the clock. The window title gives
// way first: it is cut short to whatever room is left. If that leaves it
// too little, the playing track goes.
//
// Trouble is shown in the alert colour together with a word or mark: no
// network, muted sound, a low battery.
//
// With the mouse: a workspace switches to it, the track pauses it, the
// input method switches language, and the volume mutes on a click and
// moves with the wheel.
PanelWindow {
    id: bar

    // The shell root (shell.qml).
    required property var shell

    // This screen's workspaces, in order. See Niri.qml for what each holds.
    readonly property var workspaces: {
        const here = [];
        for (const workspace of shell.niri.workspaces) {
            if (bar.screen !== null && workspace.output === bar.screen.name)
                here.push(workspace);
        }
        return here;
    }
    readonly property bool batteryLow: shell.battery <= 0.2 && !shell.charging
    readonly property bool trackPlaying: shell.trackTitle !== ""

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
    WlrLayershell.namespace: "shell"
    WlrLayershell.layer: WlrLayer.Top

    // The divider between segments: a thin Powerline arrow. On the left
    // half of the bar it points right, on the right half it points left.
    component Divider: Label {
        property bool pointsLeft: false

        text: pointsLeft ? "  " : "  "
        color: Theme.line
    }

    // A dim key in front of a value, e.g. "vol", set in the font's small
    // capitals so it reads as a label and not as part of the value.
    component Key: Label {
        color: Theme.inkDim
        smallCaps: true
    }

    // --- Fitting the left half in front of the clock ---
    // Where the left half has to end, and what is left of that for the
    // window title once the workspaces have taken their place.
    readonly property real leftLimit: clockRow.x - 2 * Theme.cellWidth
    readonly property real titleRoom: leftLimit - leftRow.x - workspaceRow.width - firstDivider.width
    // The title is worth showing in this many cells or more.
    readonly property real titleEnough: 12 * Theme.cellWidth
    readonly property bool trackFits: titleRoom - trackRow.width >= titleEnough
    readonly property real titleWidth: Math.max(0, titleRoom - (trackPlaying && trackFits ? trackRow.width : 0))

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

        // The shadow: a strip under the bar with every other dot left out.
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
                id: leftRow

                x: Theme.cellWidth
                y: Theme.barTextY

                Row {
                    id: workspaceRow

                    Repeater {
                        // A count, not the list itself: the list is made
                        // afresh on every change, and a cell should live
                        // on so that it can flash when it takes focus.
                        model: bar.workspaces.length

                        // Focused: reverse video, flashing bright for a moment as
                        // it takes focus. Occupied: normal. Empty: dim.
                        Rectangle {
                            id: cell

                            required property int index

                            readonly property var workspace: bar.workspaces[index]
                            // The list can shrink a moment before this cell goes.
                            readonly property bool focused: workspace !== undefined && workspace.focused
                            readonly property bool occupied: workspace !== undefined && workspace.occupied

                            width: 3 * Theme.cellWidth
                            height: Theme.cellHeight
                            color: focusFlash.running ? Theme.ink : (focused ? Theme.accent : "transparent")

                            onFocusedChanged: {
                                if (focused)
                                    focusFlash.restart();
                            }

                            Label {
                                x: Theme.cellWidth
                                text: cell.workspace !== undefined ? cell.workspace.index : ""
                                color: cell.focused ? Theme.slab : (cell.occupied ? Theme.ink : Theme.line)
                            }

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: bar.shell.niri.focusWorkspace(cell.workspace.index)
                            }

                            Timer {
                                id: focusFlash

                                interval: Theme.flashMs
                            }
                        }
                    }
                }

                // Only there when a window has the keyboard.
                Divider {
                    id: firstDivider

                    visible: bar.shell.niri.focusedTitle !== ""
                }

                // The focused window, cut short to the room there is.
                Label {
                    width: Math.min(implicitWidth, bar.titleWidth)
                    text: bar.shell.niri.focusedTitle
                    elide: Text.ElideRight
                }

                // The playing track, while something plays and there is
                // room for it. A click pauses it.
                Passing {
                    id: trackRow

                    active: bar.trackPlaying && bar.trackFits

                    Divider {}

                    Segment {
                        onTapped: bar.shell.pausePlaying()

                        Key {
                            text: "♪ "
                        }

                        Label {
                            text: bar.shell.trackTitle
                        }
                    }
                }
            }

            // --- Centre: date and time ---
            Row {
                id: clockRow

                y: Theme.barTextY
                // On a whole cell, so the text stays sharp.
                x: Theme.snapX((parent.width - width) / 2)

                Label {
                    text: Qt.formatDateTime(bar.shell.now, "ddd d MMM") + "  "
                    color: Theme.inkDim
                }

                Label {
                    text: Qt.formatDateTime(bar.shell.now, "hh:mm")
                    color: Theme.ink
                }
            }

            // --- Right: input method, network, volume, battery ---
            Row {
                y: Theme.barTextY
                x: parent.width - width - Theme.cellWidth

                // The input method, when fcitx5 is running: English, or
                // Japanese in the accent colour. It flashes when it
                // changes, and a click switches it.
                Segment {
                    visible: bar.shell.inputAvailable
                    onTapped: bar.shell.toggleInput()

                    Value {
                        text: bar.shell.inputJapanese ? "ja" : "en"
                        smallCaps: true
                        restColor: bar.shell.inputJapanese ? Theme.accent : Theme.inkSoft
                    }

                    Divider {
                        pointsLeft: true
                    }
                }

                Key {
                    text: "net "
                }

                SignalBars {
                    level: bar.shell.networkSignal
                }

                Label {
                    text: " " + bar.shell.networkName
                    color: bar.shell.online ? Theme.inkSoft : Theme.alert
                }

                Divider {
                    pointsLeft: true
                }

                Segment {
                    onTapped: bar.shell.toggleMute()
                    onWheelTurned: step => bar.shell.changeVolume(step)

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
                }

                // The battery, on a machine that has one.
                Row {
                    visible: bar.shell.batteryPresent

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
}
