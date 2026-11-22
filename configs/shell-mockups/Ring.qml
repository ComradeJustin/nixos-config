import QtQuick
import Quickshell
import Quickshell.Wayland

// The summoned layer: the rotation ring, now carrying the whole shell.
//
// Six words travel on an orbit around the time. h and l turn the ring, and
// the word on the right is the focused one: it gets heavy and takes the
// accent colour. Enter opens it: the word becomes a title and its settings
// list out beneath it while the other words move away. Esc backs out.
//
// It is type only. Everything on screen is positioned from three animated
// numbers below (openness, angle, dive), so the motion is one system.
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
    // 0 = ring view, 1 = the focused station opened into its list.
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
    readonly property real orbitRadius: 290
    // An opened station's list of settings.
    readonly property real listWidth: 340
    readonly property real rowHeight: 34
    // How much further the other words move out when one opens.
    readonly property real divePush: 120
    // The whole figure slides left when a station opens, to keep it centred.
    readonly property real centerX: width / 2 - 120 * dive
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

    // Dim everything behind the ring so the type reads cleanly.
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

        // The orbit, drawn very faintly: the one line in the design, so the
        // turning reads as turning.
        Rectangle {
            width: ring.orbitRadius * 2 * ring.openness
            height: width
            x: ring.centerX - width / 2
            y: ring.centerY - height / 2
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Theme.mix(Theme.slab, Theme.inkDim, 0.3)
            opacity: 1 - ring.clamp01(ring.dive)
        }

        // The time at the centre. It steps back when a station is open.
        Label {
            x: ring.centerX - width / 2
            y: ring.centerY - height / 2
            scale: 0.8 + 0.2 * ring.openness
            opacity: 1 - 0.65 * ring.clamp01(ring.dive)
            text: Qt.formatDateTime(ring.shell.now, "hh:mm")
            mono: true
            weight: 800
            color: Theme.ink
            font.pixelSize: 60
        }

        // --- Stations ---
        Repeater {
            model: ring.stations

            // Zero-sized, sitting exactly on its point of the orbit; the word
            // and the list are placed around that point.
            Item {
                id: station

                required property var modelData
                required property int index

                readonly property bool focused: index === ring.focusedIndex
                // 0 = resting, 1 = focused. Drives the word's weight and colour.
                property real emphasis: focused ? 1 : 0
                // How far this station has opened into its list. Only the focused one opens.
                readonly property real opening: focused ? Math.max(0, ring.dive) : 0
                readonly property int rowCount: modelData.controls.length
                readonly property real theta: (ring.stepDegrees * index + ring.angle) * Math.PI / 180
                readonly property real distance: ring.orbitRadius * ring.openness + (focused ? 0 : ring.divePush * ring.dive)

                Behavior on emphasis {
                    NumberAnimation {
                        duration: 110
                    }
                }

                x: ring.centerX + distance * Math.cos(theta)
                y: ring.centerY + distance * Math.sin(theta)
                opacity: focused ? 1 : 1 - ring.clamp01(ring.dive)

                // The word. Centred on the orbit point; when the station
                // opens it moves to the top left of the list as its title.
                Label {
                    id: word

                    x: -width / 2 + station.opening * (width / 2 - ring.listWidth / 2)
                    y: -height / 2 - station.opening * station.rowCount * ring.rowHeight / 2
                    text: station.modelData.name
                    weight: 360 + 540 * station.emphasis
                    color: Theme.mix(Theme.inkDim, Theme.accent, station.emphasis)
                    font.pixelSize: 24
                }

                // The list: one line per setting, name on the left, state on the right.
                Column {
                    x: -ring.listWidth / 2
                    y: word.y + word.height + 10
                    width: ring.listWidth
                    visible: station.opening > 0.01

                    Repeater {
                        model: station.modelData.controls

                        Item {
                            id: row

                            required property var modelData
                            required property int index

                            readonly property bool selected: station.focused && index === ring.shell.fanIndex

                            width: ring.listWidth
                            height: ring.rowHeight
                            // Lines appear one after another as the list opens.
                            opacity: ring.clamp01(station.opening * (station.rowCount + 1) - index)

                            // The selected line is marked the way the reference marks links: with ">".
                            Label {
                                x: -20
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.selected
                                text: ">"
                                mono: true
                                weight: 800
                                color: Theme.accent
                                font.pixelSize: 15
                            }

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.label
                                weight: row.selected ? 800 : 420
                                color: row.selected ? Theme.accent : Theme.inkSoft
                                font.pixelSize: 15
                            }

                            Label {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.value
                                weight: row.selected ? 800 : 420
                                color: row.selected ? Theme.accent : Theme.inkDim
                                font.pixelSize: 15
                            }
                        }
                    }
                }
            }
        }

        // --- Key hints: the key heavy, what it does light ---
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 72
            spacing: 30

            Repeater {
                model: ring.shell.dived ? [["j k", "select"], ["enter", "act"], ["esc", "back"]] : [["h l", "turn"], ["enter", "open"], ["esc", "close"]]

                Row {
                    required property var modelData

                    spacing: 8

                    Label {
                        text: parent.modelData[0]
                        mono: true
                        weight: 800
                        color: Theme.inkSoft
                        font.pixelSize: 12
                    }

                    Label {
                        text: parent.modelData[1]
                        color: Theme.inkDim
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
