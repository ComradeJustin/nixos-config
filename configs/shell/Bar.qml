import QtQuick
import Quickshell
import Quickshell.Wayland

// The bar: a terminal status line. One row of cells, segments separated by
// dim Powerline arrows that point away from the centre, levels drawn as
// framed progress bars.
// Left: this screen's workspaces, the focused window, the playing track,
// then how many notifications are waiting, how far a rebuild has got,
// whether do not disturb is on,
// whether the microphone or camera is in use or the screen is being
// shared, whether a Tailscale exit node is in use, whether sleep is
// switched off, and whether keep awake is on.
// Each segment can be switched off (the Bar page in System).
// Centre: date and time. Right: the tray, the input method, network with
// its signal, volume, battery.
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
// With the mouse: a workspace switches to it, the track pauses it, and the
// input method switches language. Everything else drops a panel out of the
// bar under itself (Drop.qml): the bell the inbox (a right click dismisses
// every notification), the clock the calendar, the tray its apps, the
// network the networks in range, the volume the sound controls (the wheel
// moves the volume, a right click mutes), and the battery power.
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

    // While "keep awake" is on, this window asks the compositor not to
    // count the machine as idle, so nothing dims or locks.
    IdleInhibitor {
        window: bar
        enabled: bar.shell.keepAwake
    }

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
    readonly property real titleRoom: leftLimit - leftRow.x - (workspaceRow.visible ? workspaceRow.width : 0) - firstDivider.width - passingRow.width
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

                    visible: bar.shell.barShows("workspaces")

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

                    visible: bar.shell.niri.focusedTitle !== "" && bar.shell.barShows("title")
                }

                // The focused window, cut short to the room there is.
                Label {
                    visible: bar.shell.barShows("title")
                    width: Math.min(implicitWidth, bar.titleWidth)
                    text: bar.shell.niri.focusedTitle
                    elide: Text.ElideRight
                }

                // The playing track, while something plays and there is
                // room for it. A click pauses it.
                Passing {
                    id: trackRow

                    active: bar.trackPlaying && bar.trackFits && bar.shell.barShows("track")

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

                // Whatever is going on right now.
                Row {
                    id: passingRow

                    // Notifications that have not been dismissed. A click
                    // drops the inbox; a right click dismisses them all.
                    Passing {
                        active: bar.shell.unreadCount > 0 && bar.shell.barShows("notifications")

                        Divider {}

                        Segment {
                            id: bellTab

                            onTapped: bar.shell.openDrop("inbox", bellTab.mapToItem(slab, 0, 0).x, bar.screen)
                            onRightTapped: bar.shell.dismissAll()

                            // The font's bell icon.
                            Key {
                                text: "\uf0f3 "
                            }

                            Value {
                                text: bar.shell.unreadCount
                            }
                        }
                    }

                    // A rebuild of the system is running: how far it has
                    // got. A click opens the monitor, which says more.
                    Passing {
                        active: bar.shell.building

                        Divider {}

                        Segment {
                            onTapped: bar.shell.toggleMonitor()

                            Spinner {}

                            Key {
                                text: " build "
                            }

                            // The count once there is one; until then,
                            // what the rebuild is doing.
                            Value {
                                text: bar.shell.buildTotal > 0 ? bar.shell.buildMade + "/" + bar.shell.buildTotal : bar.shell.buildPhase
                            }
                        }
                    }

                    // Do not disturb: notifications are counted, not shown.
                    Passing {
                        active: bar.shell.quiet

                        Flag {
                            word: "quiet"
                            blockColor: Theme.inkDim
                        }
                    }

                    // Something is listening, or recording or sharing the screen.
                    Passing {
                        active: bar.shell.microphoneInUse

                        Flag {
                            word: "mic"
                        }
                    }

                    Passing {
                        active: bar.shell.cameraInUse

                        Flag {
                            word: "camera"
                        }
                    }

                    Passing {
                        active: bar.shell.niri.screenShared

                        Flag {
                            word: "screen"
                        }
                    }

                    // All traffic is going out through another machine.
                    Passing {
                        active: bar.shell.exitNodeInUse

                        Flag {
                            word: "exit node"
                            blockColor: Theme.inkDim
                        }
                    }

                    // The machine does not go to sleep when it sits idle.
                    Passing {
                        active: !bar.shell.sleepsItself

                        Flag {
                            word: "no sleep"
                            blockColor: Theme.inkDim
                        }
                    }

                    // It keeps running with the lid shut.
                    Passing {
                        active: !bar.shell.sleepsOnLid

                        Flag {
                            word: "lid stays on"
                            blockColor: Theme.inkDim
                        }
                    }

                    // Kept awake: nothing dims or locks by itself.
                    Passing {
                        active: bar.shell.keepAwake

                        Flag {
                            word: "awake"
                            blockColor: Theme.inkDim
                        }
                    }
                }
            }

            // --- Centre: date and time. A click opens the calendar. ---
            Segment {
                id: clockRow

                visible: bar.shell.barShows("clock")
                y: Theme.barTextY
                // On a whole cell, so the text stays sharp.
                x: Theme.snapX((parent.width - width) / 2)
                onTapped: bar.shell.toggleCalendar(bar.screen)

                Label {
                    text: Qt.formatDateTime(bar.shell.now, "ddd d MMM") + "  "
                    color: Theme.inkDim
                }

                Label {
                    text: Qt.formatDateTime(bar.shell.now, "hh:mm")
                    color: Theme.ink
                }
            }

            // Tell the shell where the tray is, so that its panel drops
            // under it when a key opens it, too.
            Binding {
                target: bar.shell
                property: "trayTabX"
                value: rightRow.x + trayTab.x
            }

            // --- Right: tray, input method, network, volume, battery ---
            Row {
                id: rightRow

                y: Theme.barTextY
                x: parent.width - width - Theme.cellWidth

                // The tray: how many apps are running in the background.
                Segment {
                    id: trayTab

                    visible: bar.shell.trayCount > 0 && bar.shell.barShows("tray")
                    onTapped: bar.shell.openDrop("tray", bar.shell.trayTabX, bar.screen)

                    Key {
                        text: "tray "
                    }

                    Value {
                        text: bar.shell.trayCount
                    }

                    Divider {
                        pointsLeft: true
                    }
                }

                // The input method, when fcitx5 is running: English, or
                // Japanese in the accent colour. It flashes when it
                // changes, and a click switches it.
                Segment {
                    visible: bar.shell.inputAvailable && bar.shell.barShows("input")
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

                Segment {
                    id: networkTab

                    visible: bar.shell.barShows("network")
                    onTapped: bar.shell.openDrop("network", networkTab.mapToItem(slab, 0, 0).x, bar.screen)

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
                }

                Segment {
                    id: soundTab

                    visible: bar.shell.barShows("volume")
                    onTapped: bar.shell.openDrop("sound", soundTab.mapToItem(slab, 0, 0).x, bar.screen)
                    onRightTapped: bar.shell.toggleMute()
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
                Segment {
                    id: powerTab

                    visible: bar.shell.batteryPresent && bar.shell.barShows("battery")
                    onTapped: bar.shell.openDrop("power", powerTab.mapToItem(slab, 0, 0).x, bar.screen)

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
