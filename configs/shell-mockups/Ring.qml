import QtQuick
import Quickshell
import Quickshell.Wayland

// The summoned layer: the rotation ring, now carrying the whole shell.
//
// Six station names travel on a dotted orbit around a large clock. h and l
// turn the ring, and the name on the right is the focused one, shown in
// reverse video. Enter opens it: the ring's names are erased and a bordered
// panel is typed in where the focused name was, listing that station's
// settings. Esc backs out.
//
// There is one way for anything here to appear or disappear: it is typed in
// from the left a character at a time behind a dithered edge, and erased in
// reverse. The orbit is plotted dot by dot clockwise from the right, and
// each name is typed as the plot reaches it, so the ring draws itself round
// in a sweep. The dimming behind it dithers in and out. The only movement
// is the ring turning, in whole jumps on the character grid.
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

    // --- The four animated values ---
    // Each runs at a steady rate with no easing. They are chained so that
    // things happen in order: opening a station erases the names and then
    // types the panel; leaving it erases the panel and then retypes the
    // names; closing erases whatever is showing and then shuts the ring.

    // How much of the ring is typed in: 0 = closed, 1 = open. It stays open
    // until an open panel has been erased.
    property real openness: shell.ringOpen || panelOpen ? 1 : 0
    // Rotation of the ring, in degrees.
    property real angle: -stepDegrees * shell.turns
    // 0 = the names, orbit and hints are printed. 1 = they are erased, to
    // make room for a panel or because the ring is closing.
    property real aside: !shell.ringOpen || shell.dived || panelOpen ? 1 : 0
    // How much of the focused station's panel is typed in. It starts only
    // once the names have been erased.
    property real dive: shell.dived && aside === 1 ? 1 : 0

    // --- What is drawn from them ---
    // One turn is drawn as a few equal jumps round the orbit.
    readonly property real angleJump: stepDegrees / Theme.turnSteps
    readonly property real drawnAngle: Math.round(angle / angleJump) * angleJump
    // How much of the ring's own text and orbit is printed, from 0 to 1.
    readonly property real ringPrinted: Math.min(openness, 1 - aside)
    // The orbit is fully plotted when the ring is this far printed; the rest
    // of the time lets the last name finish typing.
    readonly property real sweepShare: 0.7
    // True from the first typed character of a panel until the last one is erased.
    readonly property bool panelOpen: dive > 0

    Behavior on openness {
        NumberAnimation {
            duration: Theme.typeMs
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
            duration: Theme.typeMs
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

    function clamp01(value: real): real {
        return Math.max(0, Math.min(1, value));
    }

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

    // Dim everything behind the ring. It dithers in as the ring opens and
    // out as it closes.
    Dim {
        level: ring.openness
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

                x: ring.centerX + Theme.snapX(ring.orbitRadius * Math.cos(theta))
                y: ring.centerY + Theme.snapY(ring.orbitRadius * Math.sin(theta)) - Theme.cellHeight / 2
                // Plotted clockwise from the right, and un-plotted in reverse.
                visible: index < Math.round(ring.clamp01(ring.ringPrinted / ring.sweepShare) * ring.orbitDots)
                text: "·"
                color: Theme.line
            }
        }

        // --- The clock at the centre: the time at four times size, the date under it ---
        // Both are typed in as the ring opens and erased as it closes.
        Item {
            id: clock

            readonly property string timeText: Qt.formatDateTime(ring.shell.now, "hh:mm")
            readonly property string dateText: Qt.formatDateTime(ring.shell.now, "dddd d MMMM")
            // Steps back to the border colour while a station is open.
            readonly property bool steppedBack: ring.shell.dived || ring.panelOpen

            x: ring.centerX
            y: ring.centerY

            Label {
                x: -Theme.snapX(clock.timeText.length * Theme.cellWidth * scaleFactor / 2)
                y: -3 * Theme.cellHeight
                text: Theme.typedText(clock.timeText, ring.openness)
                scaleFactor: 4
                color: clock.steppedBack ? Theme.line : Theme.ink
            }

            Label {
                x: -Theme.snapX(clock.dateText.length * Theme.cellWidth / 2)
                y: Theme.cellHeight
                text: Theme.typedText(clock.dateText, ring.openness)
                color: clock.steppedBack ? Theme.line : Theme.inkDim
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
                readonly property string nameText: modelData.name
                readonly property real degrees: ring.stepDegrees * index + ring.drawnAngle
                readonly property real theta: degrees * Math.PI / 180
                // Where this station sits on the orbit, as a share of the way
                // round clockwise from the right: 0 on the right, 0.5 on the left.
                readonly property real orbitShare: ((degrees % 360) + 360) % 360 / 360
                // How much of the name is typed. It starts when the plotted
                // orbit reaches this station, so the names appear in a sweep.
                readonly property real typed: ring.clamp01((ring.ringPrinted - ring.sweepShare * orbitShare) / (1 - ring.sweepShare))
                readonly property int nameWidth: nameText.length * Theme.cellWidth * 2

                z: focused ? 1 : 0
                x: ring.centerX + Theme.snapX(ring.orbitRadius * Math.cos(theta))
                y: ring.centerY + Theme.snapY(ring.orbitRadius * Math.sin(theta))

                // The reverse-video block behind the focused name. It is as
                // wide as the part of the name that is typed.
                Rectangle {
                    id: block

                    readonly property int typedCharacters: Theme.typedLength(station.nameText.length, station.typed)

                    x: name.x - 2 * Theme.cellWidth
                    y: name.y
                    width: typedCharacters * Theme.cellWidth * 2 + 4 * Theme.cellWidth
                    height: name.height
                    visible: station.focused && typedCharacters > 0
                    color: Theme.accent
                }

                // The name, at double size.
                Label {
                    id: name

                    x: -Theme.snapX(station.nameWidth / 2)
                    y: -Theme.cellHeight
                    text: Theme.typedText(station.nameText, station.typed)
                    scaleFactor: 2
                    color: station.focused ? Theme.slab : Theme.inkSoft
                }

                // The panel, typed in where the name was.
                Box {
                    id: panel

                    x: block.x
                    y: -Theme.cellHeight
                    visible: station.focused && ring.panelOpen
                    columns: ring.panelColumns
                    rows: station.modelData.controls.length
                    title: station.nameText
                    footer: "j/k select  enter act  esc back"
                    typed: station.focused ? ring.dive : 0

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

            Repeater {
                model: [["h/l", " turn    "], ["enter", " open    "], ["esc", " close"]]

                Row {
                    required property var modelData

                    Label {
                        text: Theme.typedText(parent.modelData[0], ring.ringPrinted)
                        color: Theme.ink
                    }

                    Label {
                        text: Theme.typedText(parent.modelData[1], ring.ringPrinted)
                        color: Theme.inkDim
                    }
                }
            }
        }
    }
}
