import QtQuick
import Quickshell
import Quickshell.Wayland

// The summoned layer: the rotation ring, now carrying the whole shell.
//
// Six station names travel on a dotted orbit around a large clock. h and l
// turn the ring, and the name on the right is the focused one, shown in
// reverse video. Enter opens it: a bordered panel unrolls from the name and
// lists that station's settings, while the other names move away. Esc backs
// out.
//
// Everything on screen is positioned from three animated numbers below
// (openness, angle, dive), so the motion is one continuous system.
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

    // --- The three animated values ---
    // 0 = hidden, 1 = open.
    property real openness: shell.ringOpen ? 1 : 0
    // Rotation of the ring, in degrees.
    property real angle: -stepDegrees * shell.turns
    // 0 = ring view, 1 = the focused station opened into its panel.
    property real dive: shell.dived ? 1 : 0

    Behavior on openness {
        SpringAnimation {
            spring: Theme.openSpring
            damping: Theme.openDamping
            epsilon: 0.002
        }
    }
    Behavior on angle {
        SpringAnimation {
            spring: Theme.turnSpring
            damping: Theme.turnDamping
            epsilon: 0.02
        }
    }
    Behavior on dive {
        SpringAnimation {
            spring: Theme.openSpring
            damping: Theme.openDamping
            epsilon: 0.002
        }
    }

    // --- Geometry ---
    readonly property real orbitRadius: 280
    // Width of an opened station's panel, in character cells.
    readonly property int panelColumns: 52
    // Where the value column starts inside a panel row, in cells.
    readonly property int valueColumn: 18
    // How much further the other names move out when one opens.
    readonly property real divePush: 120
    // The whole figure slides left when a station opens, to keep it centred.
    readonly property real centerX: Math.round(width / 2 - 150 * dive)
    readonly property real centerY: Math.round(height / 2)

    function clamp01(value: real): real {
        return Math.max(0, Math.min(1, value));
    }

    // Stay mapped while the closing spring is still settling.
    visible: shell.ringOpen || openness > 0.02
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

    // Dim everything behind the ring.
    Rectangle {
        anchors.fill: parent
        color: Theme.slab
        opacity: 0.9 * ring.clamp01(ring.openness)
    }

    Item {
        id: stage

        anchors.fill: parent
        focus: true
        opacity: ring.clamp01(ring.openness)

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

        // --- The orbit: a circle of dots, as a terminal would draw it ---
        Repeater {
            model: 72

            Rectangle {
                required property int index

                readonly property real theta: index * 5 * Math.PI / 180

                x: Math.round(ring.centerX + ring.orbitRadius * ring.openness * Math.cos(theta)) - 1
                y: Math.round(ring.centerY + ring.orbitRadius * ring.openness * Math.sin(theta)) - 1
                width: 2
                height: 2
                color: Theme.line
                opacity: 1 - ring.clamp01(ring.dive)
            }
        }

        // --- The clock at the centre: the time at four times size, the date under it ---
        Item {
            x: ring.centerX
            y: ring.centerY
            opacity: 1 - 0.65 * ring.clamp01(ring.dive)

            Label {
                id: time

                x: -Math.round(width / 2)
                y: -Math.round(height / 2) - Theme.cellHeight
                text: Qt.formatDateTime(ring.shell.now, "hh:mm")
                scaleFactor: 4
                color: Theme.ink
            }

            Label {
                x: -Math.round(width / 2)
                y: time.y + time.height + 4
                text: Qt.formatDateTime(ring.shell.now, "dddd d MMMM")
                color: Theme.inkDim
            }
        }

        // --- Stations ---
        Repeater {
            model: ring.stations

            // Zero-sized, sitting exactly on its point of the orbit; the name
            // and the panel are placed around that point.
            Item {
                id: station

                required property var modelData
                required property int index

                readonly property bool focused: index === ring.focusedIndex
                // 0 = resting, 1 = focused. Fades the reverse-video block in.
                property real emphasis: focused ? 1 : 0
                // How far this station has opened into its panel. Only the focused one opens.
                readonly property real opening: focused ? ring.clamp01(ring.dive) : 0
                readonly property int rowCount: modelData.controls.length
                readonly property real theta: (ring.stepDegrees * index + ring.angle) * Math.PI / 180
                readonly property real distance: ring.orbitRadius * ring.openness + (focused ? 0 : ring.divePush * ring.dive)

                Behavior on emphasis {
                    NumberAnimation {
                        duration: 90
                    }
                }

                z: focused ? 1 : 0
                x: Math.round(ring.centerX + distance * Math.cos(theta))
                y: Math.round(ring.centerY + distance * Math.sin(theta))
                opacity: focused ? 1 : 1 - ring.clamp01(ring.dive)

                // The reverse-video block behind the focused name.
                Rectangle {
                    id: block

                    x: -Math.round(width / 2)
                    y: -Math.round(height / 2)
                    width: name.width + 4 * Theme.cellWidth
                    height: name.height + 4
                    color: Theme.accent
                    opacity: station.emphasis * (1 - station.opening)
                }

                // The name, at double size.
                Label {
                    id: name

                    x: -Math.round(width / 2)
                    y: -Math.round(height / 2)
                    text: station.modelData.name
                    scaleFactor: 2
                    color: Theme.mix(Theme.inkSoft, Theme.slab, station.emphasis)
                    opacity: 1 - station.opening
                }

                // The panel. It unrolls from its middle row, starting where the name was.
                Item {
                    id: reveal

                    x: block.x
                    y: -Math.round(height / 2)
                    width: panel.implicitWidth
                    height: Math.round(panel.implicitHeight * station.opening)
                    visible: station.opening > 0.01
                    clip: true

                    Box {
                        id: panel

                        y: -Math.round((implicitHeight - reveal.height) / 2)
                        columns: ring.panelColumns
                        rows: station.rowCount
                        title: station.modelData.name
                        footer: "j/k select  enter act  esc back"

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
        }

        // --- Key hints for the ring view; an open panel carries its own ---
        Row {
            x: Math.round((parent.width - width) / 2)
            y: parent.height - 80
            opacity: 1 - ring.clamp01(ring.dive)

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
