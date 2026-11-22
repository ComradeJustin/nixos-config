import QtQuick
import Quickshell
import Quickshell.Wayland

// The summoned layer: the rotation ring, now carrying the whole shell.
//
// Six stations travel on an orbit around a clock. h and l turn the ring, and
// the station on the right is the focused one, drawn as an inverted block.
// Enter opens it: the block itself grows into a table of that station's
// controls while the other stations move away. Esc backs out.
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
    // 0 = ring view, 1 = the focused station opened into its table.
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
    readonly property real orbitRadius: 270
    readonly property real hubDiameter: 152
    // A closed station.
    readonly property real ticketWidth: 212
    readonly property real ticketHeight: 56
    // An opened station: the same block, wider, with one row per control.
    readonly property real tableWidth: 440
    readonly property real rowHeight: 32
    // How much further the other stations move out when one opens.
    readonly property real divePush: 120
    // The whole figure slides left when a station opens, to keep it centred.
    readonly property real centerX: width / 2 - 110 * dive
    readonly property real centerY: height / 2

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
        opacity: 0.86 * ring.clamp01(ring.openness)
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

        // --- The orbit the stations travel on ---
        Rectangle {
            width: ring.orbitRadius * 2 * ring.openness
            height: width
            x: ring.centerX - width / 2
            y: ring.centerY - height / 2
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Theme.rule
            opacity: 1 - ring.clamp01(ring.dive)
        }

        // Line from the clock to the focused position on the right.
        Rectangle {
            x: ring.centerX + ring.hubDiameter / 2 + 10
            y: ring.centerY
            width: Math.max(0, ring.orbitRadius * ring.openness - ring.ticketWidth / 2 - ring.hubDiameter / 2 - 20)
            height: 1
            color: Theme.inkDim
        }

        // --- The clock at the centre ---
        Rectangle {
            width: ring.hubDiameter
            height: width
            x: ring.centerX - width / 2
            y: ring.centerY - height / 2
            radius: width / 2
            scale: 0.7 + 0.3 * ring.openness
            color: Theme.slab
            border.width: 1
            border.color: Theme.inkDim

            // Four short marks at 12, 3, 6 and 9 o'clock.
            Repeater {
                model: 4

                Item {
                    required property int index

                    anchors.fill: parent
                    rotation: index * 90

                    Rectangle {
                        x: parent.width / 2
                        y: 8
                        width: 1
                        height: 8
                        color: Theme.inkDim
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(ring.shell.now, "ddd d MMM")
                    caps: true
                    color: Theme.inkDim
                    font.pixelSize: 8
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(ring.shell.now, "hh:mm")
                    weight: 850
                    color: Theme.ink
                    font.pixelSize: 32
                }
            }
        }

        // --- Stations ---
        Repeater {
            model: ring.stations

            Rectangle {
                id: station

                required property var modelData
                required property int index

                readonly property bool focused: index === ring.focusedIndex
                // 0 = resting, 1 = focused. Blends every colour towards the inverted block.
                property real emphasis: focused ? 1 : 0
                // How far this station has opened into its table. Only the focused one opens.
                readonly property real opening: focused ? Math.max(0, ring.dive) : 0
                // How inverted the header is: fully when focused on the ring, not at all once opened.
                readonly property real inversion: emphasis * (1 - ring.clamp01(opening))
                readonly property int rowCount: modelData.controls.length
                readonly property real theta: (ring.stepDegrees * index + ring.angle) * Math.PI / 180
                readonly property real distance: ring.orbitRadius * ring.openness + (focused ? 0 : ring.divePush * ring.dive)

                Behavior on emphasis {
                    NumberAnimation {
                        duration: 90
                    }
                }

                z: focused ? 1 : 0
                width: ring.ticketWidth + (ring.tableWidth - ring.ticketWidth) * opening
                height: ring.ticketHeight + rowCount * ring.rowHeight * opening
                // The left edge stays put, so an opening station grows to the right.
                x: ring.centerX + distance * Math.cos(theta) - ring.ticketWidth / 2
                y: ring.centerY + distance * Math.sin(theta) - height / 2
                opacity: focused ? 1 : 1 - ring.clamp01(ring.dive)
                clip: true
                color: Theme.slab
                border.width: 1
                border.color: Theme.mix(Theme.rule, Theme.accent, emphasis)

                // Header: a small readout line over the station's name.
                Rectangle {
                    width: parent.width
                    height: ring.ticketHeight
                    color: Theme.mix(Theme.slab, Theme.accent, station.inversion)

                    Label {
                        x: 14
                        y: 10
                        width: parent.width - 52
                        text: station.modelData.readout
                        caps: true
                        color: Theme.mix(Theme.inkDim, Theme.onAccent, station.inversion)
                        elide: Text.ElideRight
                        font.pixelSize: 8
                    }

                    Label {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        y: 10
                        text: "0" + (station.index + 1)
                        color: Theme.mix(Theme.inkDim, Theme.onAccent, station.inversion)
                        font.pixelSize: 8
                    }

                    Label {
                        x: 14
                        y: 24
                        text: station.modelData.name
                        caps: true
                        weight: 600 + 250 * station.emphasis
                        color: Theme.mix(Theme.ink, Theme.onAccent, station.inversion)
                        font.pixelSize: 17
                    }
                }

                // Heavy rule under the header of an opened station, as on a departure board.
                Rectangle {
                    y: ring.ticketHeight - 2
                    width: parent.width
                    height: 2
                    color: Theme.ink
                    opacity: ring.clamp01(station.opening)
                }

                // Table: one row per control, label on the left, value on the right.
                Column {
                    y: ring.ticketHeight
                    width: parent.width
                    visible: station.opening > 0.01

                    Repeater {
                        model: station.modelData.controls

                        Item {
                            id: row

                            required property var modelData
                            required property int index

                            readonly property bool selected: station.focused && index === ring.shell.fanIndex
                            readonly property color inkColor: selected ? Theme.onAccent : Theme.ink
                            readonly property color dimColor: selected ? Theme.onAccent : Theme.inkDim

                            width: station.width
                            height: ring.rowHeight
                            // Rows appear one after another as the table opens.
                            opacity: ring.clamp01(station.opening * (station.rowCount + 1) - index)

                            // The selected row is an inverted block.
                            Rectangle {
                                x: 1
                                width: parent.width - 2
                                height: parent.height - 1
                                visible: row.selected
                                color: Theme.accent
                            }

                            Label {
                                id: rowLabel

                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.label
                                caps: true
                                color: row.dimColor
                                font.pixelSize: 9
                            }

                            Label {
                                id: rowValue

                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.value
                                weight: row.selected ? 800 : 600
                                color: row.inkColor
                                font.pixelSize: 12
                            }

                            LevelBar {
                                id: rowLevel

                                anchors.right: rowValue.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 56
                                visible: row.modelData.level >= 0
                                level: row.modelData.level
                                fillColor: row.inkColor
                                emptyColor: row.selected ? Theme.mix(Theme.accent, Theme.onAccent, 0.35) : Theme.rule
                            }

                            // Dotted leader between the label and the value, as on a receipt.
                            Item {
                                anchors.left: rowLabel.right
                                anchors.leftMargin: 10
                                anchors.right: rowLevel.visible ? rowLevel.left : rowValue.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 12
                                clip: true

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . ."
                                    color: row.selected ? Theme.mix(Theme.accent, Theme.onAccent, 0.45) : Theme.rule
                                    font.pixelSize: 9
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- Key hints ---
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 72
            spacing: 28

            KeyHint {
                keys: ring.shell.dived ? "j k" : "h l"
                action: ring.shell.dived ? "select" : "turn"
            }

            KeyHint {
                keys: "enter"
                action: ring.shell.dived ? "act" : "open"
            }

            KeyHint {
                keys: "esc"
                action: ring.shell.dived ? "back" : "close"
            }
        }
    }
}
