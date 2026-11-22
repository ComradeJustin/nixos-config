import QtQuick
import Quickshell
import Quickshell.Wayland

// The summoned layer: the rotation ring, now carrying the whole shell.
//
// Six station names travel on a dotted orbit around a large clock. h and l
// turn the ring, and the name on the right is the focused one, shown in
// reverse video. Enter opens it: a bordered panel is printed in its place,
// listing that station's settings. Esc backs out.
//
// It moves the way a terminal redraws. Three numbers below (openness, angle,
// dive) run at a steady rate with no easing, and each is rounded to a few
// whole steps before anything is drawn from it. Positions snap to the
// character grid and nothing fades, so every frame is a clean redraw.
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

    // --- The three animated values, and the stepped versions that are drawn ---
    // 0 = hidden, 1 = open.
    // It stays open until any open panel has been erased, so closing runs
    // in order: the panel first, then the ring.
    property real openness: shell.ringOpen || panelOpen ? 1 : 0
    // Rotation of the ring, in degrees.
    property real angle: -stepDegrees * shell.turns
    // 0 = ring view, 1 = the focused station's panel fully printed.
    property real dive: shell.dived ? 1 : 0

    // The orbit's size jumps outward in a few steps as the ring opens.
    readonly property real drawnOpenness: Math.round(openness * Theme.ringOpenSteps) / Theme.ringOpenSteps
    // One turn is drawn as a few equal jumps round the orbit.
    readonly property real angleJump: stepDegrees / Theme.turnSteps
    readonly property real drawnAngle: Math.round(angle / angleJump) * angleJump
    // True from the first printed row of a panel until the last one is erased.
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
    Behavior on dive {
        NumberAnimation {
            duration: (ring.focusedRowCount + 2) * Theme.lineMs
        }
    }

    // --- Geometry, all on the character grid ---
    readonly property real orbitRadius: 280
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

    // Dim everything behind the ring. It cuts in and out; nothing fades.
    Rectangle {
        anchors.fill: parent
        color: Theme.slab
        opacity: 0.9
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

        // --- The orbit: a circle plotted in dot characters, as a terminal would ---
        Repeater {
            model: 60

            Label {
                required property int index

                readonly property real theta: index * 6 * Math.PI / 180

                x: ring.centerX + Theme.snapX(ring.orbitRadius * ring.drawnOpenness * Math.cos(theta))
                y: ring.centerY + Theme.snapY(ring.orbitRadius * ring.drawnOpenness * Math.sin(theta)) - Theme.cellHeight / 2
                visible: !ring.panelOpen && ring.drawnOpenness > 0
                text: "·"
                color: Theme.line
            }
        }

        // --- The clock at the centre: the time at four times size, the date under it ---
        Item {
            x: ring.centerX
            y: ring.centerY

            Label {
                id: time

                x: -Theme.snapX(width / 2)
                y: -3 * Theme.cellHeight
                text: Qt.formatDateTime(ring.shell.now, "hh:mm")
                scaleFactor: 4
                // Steps back to the border colour while a panel is open.
                color: ring.panelOpen ? Theme.line : Theme.ink
            }

            Label {
                x: -Theme.snapX(width / 2)
                y: Theme.cellHeight
                text: Qt.formatDateTime(ring.shell.now, "dddd d MMMM")
                color: ring.panelOpen ? Theme.line : Theme.inkDim
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
                // Hidden while the orbit has no size. While a panel is open
                // only the focused station is drawn.
                visible: ring.drawnOpenness > 0 && (focused || !ring.panelOpen)

                // The reverse-video block behind the focused name.
                Rectangle {
                    id: block

                    x: name.x - 2 * Theme.cellWidth
                    y: name.y
                    width: name.width + 4 * Theme.cellWidth
                    height: name.height
                    visible: station.focused && !ring.panelOpen
                    color: Theme.accent
                }

                // The name, at double size.
                Label {
                    id: name

                    x: -Theme.snapX(width / 2)
                    y: -Theme.cellHeight
                    visible: !ring.panelOpen
                    text: station.modelData.name
                    scaleFactor: 2
                    color: station.focused ? Theme.slab : Theme.inkSoft
                }

                // The panel, printed a row at a time from where the name was.
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
        Row {
            x: Theme.snapX((parent.width - width) / 2)
            y: Theme.snapY(parent.height - 80)
            visible: !ring.panelOpen

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
