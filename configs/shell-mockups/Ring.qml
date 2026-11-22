import QtQuick
import Quickshell
import Quickshell.Wayland

// The summoned layer: the rotation ring, now carrying the whole shell.
//
// Six station names travel on a dotted orbit around a large clock. h and l
// turn the ring, and the name on the right is the focused one, shown in
// reverse video. Enter opens it: the ring's names are erased and a bordered
// panel is printed where the focused name was, listing that station's
// settings. Esc backs out.
//
// It moves the way a terminal redraws: at a steady rate, in whole steps,
// with positions on the character grid. Nothing fades and nothing is cut.
// Text is typed in and erased a character at a time, the orbit is plotted
// and un-plotted dot by dot, panels are printed line by line, and the
// dimming behind it all changes in steps. Everything that appears leaves
// the same way, in reverse.
PanelWindow {
    id: ring

    // The shell root (shell.qml), which holds the state and the sample data.
    required property var shell

    readonly property var stations: shell.stations
    readonly property int stationCount: stations.length
    readonly property real stepDegrees: 360 / stationCount
    // shell.turns counts presses and never wraps, so the ring keeps turning
    // the same way when it passes the last station.
    readonly property int focusedIndex: ((shell.turns % stationCount) + stationCount) % stationCount
    readonly property int focusedRowCount: stations[focusedIndex].controls.length

    // --- The four animated values ---
    // Each runs at a steady rate with no easing. They are chained so that
    // things happen in order: opening a station erases the names and then
    // prints the panel; leaving it erases the panel and then retypes the
    // names; closing erases whatever is showing and then shuts the ring.

    // How far the ring has opened: 0 = closed, 1 = open. It stays open until
    // an open panel has been erased.
    property real openness: shell.ringOpen || panelOpen ? 1 : 0
    // Rotation of the ring, in degrees.
    property real angle: -stepDegrees * shell.turns
    // 0 = the names, orbit and hints are printed. 1 = they are erased, to
    // make room for a panel or because the ring is closing.
    property real aside: !shell.ringOpen || shell.dived || panelOpen ? 1 : 0
    // How much of the focused station's panel is printed. It starts only
    // once the names have been erased.
    property real dive: shell.dived && aside === 1 ? 1 : 0

    // --- What is drawn from them ---
    // The orbit's size jumps outward in a few steps as the ring opens.
    readonly property real drawnOpenness: Math.round(openness * Theme.ringOpenSteps) / Theme.ringOpenSteps
    // One turn is drawn as a few equal jumps round the orbit.
    readonly property real angleJump: stepDegrees / Theme.turnSteps
    readonly property real drawnAngle: Math.round(angle / angleJump) * angleJump
    // How much of the ring's own text and orbit is printed, from 0 to 1.
    readonly property real ringPrinted: Math.min(openness, 1 - aside)
    // True from the first printed line of a panel until the last one is erased.
    readonly property bool panelOpen: dive > 0

    Behavior on openness {
        NumberAnimation {
            duration: Theme.ringOpenMs
        }
    }
    Behavior on angle {
        NumberAnimation {
            duration: Theme.turnMs
        }
    }
    Behavior on aside {
        NumberAnimation {
            duration: Theme.typeMs
        }
    }
    Behavior on dive {
        NumberAnimation {
            duration: (ring.focusedRowCount + 2) * Theme.lineMs
        }
    }

    // --- Geometry, all on the character grid ---
    readonly property real orbitRadius: 280
    readonly property int orbitDots: 60
    // Width of an opened station's panel, in character cells.
    readonly property int panelColumns: 52
    // Where the value column starts inside a panel row, in cells.
    readonly property int valueColumn: 18
    readonly property real centerX: Theme.snapX(width / 2)
    readonly property real centerY: Theme.snapY(height / 2)

    // Stay mapped until the ring has closed all the way.
    visible: shell.ringOpen || openness > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shell.ringOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible)
            stage.forceActiveFocus();
    }

    // Dim everything behind the ring, darker in steps as the ring opens and
    // lighter in the same steps as it closes.
    Rectangle {
        anchors.fill: parent
        color: Theme.slab
        opacity: 0.9 * ring.drawnOpenness
    }

    Item {
        id: stage

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const shell = ring.shell;
            const forward = event.key === Qt.Key_L || event.key === Qt.Key_Right;
            const backward = event.key === Qt.Key_H || event.key === Qt.Key_Left;
            const down = event.key === Qt.Key_J || event.key === Qt.Key_Down;
            const up = event.key === Qt.Key_K || event.key === Qt.Key_Up;
            const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space;

            if (event.key === Qt.Key_Escape)
                shell.back();
            else if (!shell.dived && forward)
                shell.rotate(1);
            else if (!shell.dived && backward)
                shell.rotate(-1);
            else if (!shell.dived && enter)
                shell.diveIn();
            else if (shell.dived && backward)
                shell.back();
            else if (shell.dived && down)
                shell.moveSelection(1);
            else if (shell.dived && up)
                shell.moveSelection(-1);
            event.accepted = true;
        }

        // --- The orbit: a circle plotted in dot characters, one after another ---
        Repeater {
            model: ring.orbitDots

            Label {
                required property int index

                readonly property real theta: index * (360 / ring.orbitDots) * Math.PI / 180

                x: ring.centerX + Theme.snapX(ring.orbitRadius * ring.drawnOpenness * Math.cos(theta))
                y: ring.centerY + Theme.snapY(ring.orbitRadius * ring.drawnOpenness * Math.sin(theta)) - Theme.cellHeight / 2
                // Dots are plotted clockwise from the right, and un-plotted in reverse.
                visible: index < Math.round(ring.ringPrinted * ring.orbitDots)
                text: "·"
                color: Theme.line
            }
        }

        // --- The clock at the centre: the time at four times size, the date under it ---
        // Both are typed in as the ring opens and erased as it closes.
        Item {
            x: ring.centerX
            y: ring.centerY

            Label {
                x: -Theme.snapX(implicitWidth / 2)
                y: -3 * Theme.cellHeight
                text: Qt.formatDateTime(ring.shell.now, "hh:mm")
                scaleFactor: 4
                typed: ring.openness
                // Steps back to the border colour while a station is open.
                color: ring.shell.dived || ring.panelOpen ? Theme.line : Theme.ink
            }

            Label {
                x: -Theme.snapX(implicitWidth / 2)
                y: Theme.cellHeight
                text: Qt.formatDateTime(ring.shell.now, "dddd d MMMM")
                typed: ring.openness
                color: ring.shell.dived || ring.panelOpen ? Theme.line : Theme.inkDim
            }
        }

        // --- Stations ---
        Repeater {
            model: ring.stations

            // Zero-sized, sitting on its point of the orbit, snapped to the
            // grid; the name and the panel are placed around that point.
            Item {
                id: station

                required property var modelData
                required property int index

                readonly property bool focused: index === ring.focusedIndex
                readonly property real theta: (ring.stepDegrees * index + ring.drawnAngle) * Math.PI / 180
                readonly property real distance: ring.orbitRadius * ring.drawnOpenness

                z: focused ? 1 : 0
                x: ring.centerX + Theme.snapX(distance * Math.cos(theta))
                y: ring.centerY + Theme.snapY(distance * Math.sin(theta))

                // The reverse-video block behind the focused name. It is as
                // wide as the part of the name that is printed.
                Rectangle {
                    id: block

                    x: name.x - 2 * Theme.cellWidth
                    y: name.y
                    width: name.width + 4 * Theme.cellWidth
                    height: name.height
                    visible: station.focused && name.typedCharacters > 0
                    color: Theme.accent
                }

                // The name, at double size, typed in and erased with the ring.
                Label {
                    id: name

                    x: -Theme.snapX(implicitWidth / 2)
                    y: -Theme.cellHeight
                    text: station.modelData.name
                    scaleFactor: 2
                    typed: ring.ringPrinted
                    color: station.focused ? Theme.slab : Theme.inkSoft
                }

                // The panel, printed a line at a time from where the name was.
                Box {
                    id: panel

                    x: block.x
                    y: -Theme.cellHeight
                    visible: station.focused && ring.panelOpen
                    columns: ring.panelColumns
                    rows: station.modelData.controls.length
                    title: station.modelData.name
                    footer: "j/k select  enter act  esc back"
                    reveal: station.focused ? ring.dive : 0

                    Repeater {
                        model: station.modelData.controls

                        // One setting. The selected one has its name in reverse video.
                        Item {
                            id: row

                            required property var modelData
                            required property int index

                            readonly property bool selected: station.focused && index === ring.shell.fanIndex
                            readonly property color nameColor: selected ? Theme.slab : Theme.ink

                            y: index * Theme.cellHeight
                            width: panel.contentColumns * Theme.cellWidth
                            height: Theme.cellHeight

                            Rectangle {
                                width: (ring.valueColumn - 1) * Theme.cellWidth
                                height: parent.height
                                visible: row.selected
                                color: Theme.accent
                            }

                            Label {
                                text: row.selected ? ">" : " "
                                color: row.nameColor
                            }

                            Label {
                                x: 2 * Theme.cellWidth
                                text: row.modelData.label
                                color: row.nameColor
                            }

                            // A level: a bar, then its number at the right edge.
                            Level {
                                x: ring.valueColumn * Theme.cellWidth
                                visible: row.modelData.kind === "level"
                                level: row.modelData.kind === "level" ? row.modelData.level : 0
                                cells: 22
                            }

                            Label {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.cellWidth
                                visible: row.modelData.kind === "level"
                                text: row.modelData.value
                                color: Theme.ink
                            }

                            // A switch: a checkbox, then its state. Anything else: just its value.
                            Label {
                                x: ring.valueColumn * Theme.cellWidth
                                width: (panel.contentColumns - ring.valueColumn - 1) * Theme.cellWidth
                                visible: row.modelData.kind !== "level"
                                text: row.modelData.kind === "switch" ? (row.modelData.on ? "[x] " : "[ ] ") + row.modelData.value : row.modelData.value
                                color: Theme.inkSoft
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // --- Key hints for the ring view; an open panel carries its own ---
        // The whole line is typed in and erased by widening and narrowing
        // this window onto it, one character at a time.
        Item {
            x: Theme.snapX((parent.width - hints.width) / 2)
            y: Theme.snapY(parent.height - 80)
            width: Theme.snapX(ring.ringPrinted * hints.width)
            height: hints.height
            clip: true

            Row {
                id: hints

                Repeater {
                    model: [["h/l", " turn    "], ["enter", " open    "], ["esc", " close"]]

                    Row {
                        required property var modelData

                        Label {
                            text: parent.modelData[0]
                            color: Theme.ink
                        }

                        Label {
                            text: parent.modelData[1]
                            color: Theme.inkDim
                        }
                    }
                }
            }
        }
    }
}
