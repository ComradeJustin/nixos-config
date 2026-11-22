import QtQuick
import Quickshell
import Quickshell.Wayland

// The summoned layer: the rotation ring, now carrying the whole shell.
//
// Six station names travel on a dotted orbit around a large clock. h and l
// turn the ring, and the name on the right is the focused one, shown in
// reverse video. Enter opens it: the ring's names are wiped away and a
// bordered panel is wiped in where the focused name was, listing that station's
// settings. Esc backs out.
//
// There is one way for anything here to appear or disappear: a dithered
// front wipes across it from the left, and wipes back to take it away. The
// orbit is plotted dot by dot clockwise from the right, and each name is
// wiped in as the plot reaches it, so the ring draws itself round in a
// sweep. The dimming behind it dithers in and out. The only movement is the
// ring turning, in whole jumps on the character grid; the name that takes
// focus flashes bright for a moment.
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
    // things happen in order: opening a station wipes the names away and
    // then wipes the panel in; leaving it wipes the panel away and then
    // brings the names back; closing wipes away whatever is showing and
    // then shuts the ring.

    // How much of the ring is showing: 0 = closed, 1 = open. It stays open
    // until an open panel has been wiped away.
    property real openness: shell.ringOpen || panelOpen ? 1 : 0
    // Rotation of the ring, in degrees.
    property real angle: -stepDegrees * shell.turns
    // 0 = the names, orbit and hints are showing. 1 = they are wiped away,
    // to make room for a panel or because the ring is closing.
    property real aside: !shell.ringOpen || shell.dived || panelOpen ? 1 : 0
    // How much of the focused station's panel is showing. It starts only
    // once the names have been wiped away.
    property real dive: shell.dived && aside === 1 ? 1 : 0

    // --- What is drawn from them ---
    // One turn is drawn as a few equal jumps round the orbit.
    readonly property real angleJump: stepDegrees / Theme.turnSteps
    readonly property real drawnAngle: Math.round(angle / angleJump) * angleJump
    // How much of the ring's own names, orbit and hints is showing, from 0 to 1.
    readonly property real ringShown: Math.min(openness, 1 - aside)
    // The orbit is fully plotted when the ring is this far shown; the rest
    // of the time lets the last name finish wiping in.
    readonly property real sweepShare: 0.7
    // True from when a panel starts to wipe in until it has been wiped away.
    readonly property bool panelOpen: dive > 0

    Behavior on openness {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }
    Behavior on angle {
        NumberAnimation {
            duration: Theme.turnMs
        }
    }
    Behavior on aside {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }
    Behavior on dive {
        NumberAnimation {
            duration: Theme.wipeMs
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
                visible: index < Math.round(ring.clamp01(ring.ringShown / ring.sweepShare) * ring.orbitDots)
                text: "·"
                // Brighter than a border, so it reads over the dimming's dots.
                color: Theme.inkDim
            }
        }

        // --- The clock at the centre: the time at four times size, the date under it ---
        // Wiped in as the ring opens and away as it closes.
        Item {
            id: clock

            readonly property string timeText: Qt.formatDateTime(ring.shell.now, "hh:mm")
            readonly property string dateText: Qt.formatDateTime(ring.shell.now, "dddd d MMMM")
            // Steps back to the border colour while a station is open.
            readonly property bool steppedBack: ring.shell.dived || ring.panelOpen
            // As wide as the wider of its two lines, in cells.
            readonly property int columns: Math.max(timeText.length * 4, dateText.length)

            x: ring.centerX - Theme.snapX(width / 2)
            y: ring.centerY - 3 * Theme.cellHeight
            width: columns * Theme.cellWidth
            height: 5 * Theme.cellHeight
            visible: ring.openness > 0
            // Drawn through the dither only while it is changing.
            layer.enabled: ring.openness < 1
            layer.effect: DitherFade {
                amount: ring.openness
                spread: Theme.wipeFront
            }

            Label {
                x: Theme.snapX((clock.width - width) / 2)
                text: clock.timeText
                scaleFactor: 4
                color: clock.steppedBack ? Theme.line : Theme.ink
            }

            Label {
                x: Theme.snapX((clock.width - width) / 2)
                y: 4 * Theme.cellHeight
                text: clock.dateText
                color: clock.steppedBack ? Theme.line : Theme.inkDim
                smallCaps: true
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
                // How much of the name is showing. It starts when the plotted
                // orbit reaches this station, so the names appear in a sweep.
                readonly property real shown: ring.clamp01((ring.ringShown - ring.sweepShare * orbitShare) / (1 - ring.sweepShare))
                readonly property int nameWidth: nameText.length * Theme.cellWidth * 2

                z: focused ? 1 : 0
                x: ring.centerX + Theme.snapX(ring.orbitRadius * Math.cos(theta))
                y: ring.centerY + Theme.snapY(ring.orbitRadius * Math.sin(theta))

                onFocusedChanged: {
                    if (focused)
                        focusFlash.restart();
                }

                Timer {
                    id: focusFlash

                    interval: Theme.flashMs
                }

                // The name at double size, with two cells of margin each
                // side. The focused one is in reverse video.
                Item {
                    id: plate

                    x: -Theme.snapX(station.nameWidth / 2) - 2 * Theme.cellWidth
                    y: -Theme.cellHeight
                    width: station.nameWidth + 4 * Theme.cellWidth
                    height: 2 * Theme.cellHeight
                    visible: station.shown > 0
                    // Drawn through the dither only while it is changing.
                    layer.enabled: station.shown < 1
                    layer.effect: DitherFade {
                        amount: station.shown
                        spread: Theme.wipeFront
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: station.focused
                        color: focusFlash.running ? Theme.ink : Theme.accent
                    }

                    Label {
                        x: 2 * Theme.cellWidth
                        text: station.nameText
                        scaleFactor: 2
                        color: station.focused ? Theme.slab : Theme.inkSoft
                    }
                }

                // The panel, wiped in where the name was.
                Box {
                    id: panel

                    x: plate.x
                    y: -Theme.cellHeight
                    visible: station.focused && ring.panelOpen
                    columns: ring.panelColumns
                    rows: station.modelData.controls.length
                    title: station.nameText
                    footer: "↑↓ jk select  ↵ act  esc back"
                    shown: station.focused ? ring.dive : 0

                    Repeater {
                        model: station.modelData.controls

                        // One setting. The selected one has its name in reverse video.
                        Item {
                            id: row

                            required property var modelData
                            required property int index

                            readonly property bool selected: station.focused && index === ring.shell.fanIndex
                            readonly property color nameColor: selected ? Theme.slab : Theme.ink
                            readonly property string kind: modelData.kind
                            // A level and a graph both end with a number at the right edge.
                            readonly property bool endsWithNumber: kind === "level" || kind === "graph"
                            // Where the value's text starts, in cells. A busy line has its spinner first.
                            readonly property int textColumn: ring.valueColumn + (kind === "busy" ? 2 : 0)

                            y: index * Theme.cellHeight
                            width: panel.contentColumns * Theme.cellWidth
                            height: Theme.cellHeight

                            onSelectedChanged: {
                                if (selected)
                                    selectFlash.restart();
                            }

                            Timer {
                                id: selectFlash

                                interval: Theme.flashMs
                            }

                            // Reverse video behind the name. It flashes
                            // bright for a moment as the line is selected.
                            Rectangle {
                                width: (ring.valueColumn - 1) * Theme.cellWidth
                                height: parent.height
                                visible: row.selected
                                color: selectFlash.running ? Theme.ink : Theme.accent
                            }

                            Label {
                                text: row.selected ? "►" : " "
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
                                visible: row.kind === "level"
                                level: row.kind === "level" ? row.modelData.level : 0
                                cells: 22
                            }

                            // A graph: its history, then its number at the right edge.
                            Graph {
                                x: ring.valueColumn * Theme.cellWidth
                                visible: row.kind === "graph"
                                samples: row.kind === "graph" ? row.modelData.samples : []
                                cells: 22
                            }

                            Label {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.cellWidth
                                visible: row.endsWithNumber
                                text: row.modelData.value
                                color: Theme.ink
                            }

                            // Something in progress: a spinner in front of its text.
                            Spinner {
                                x: ring.valueColumn * Theme.cellWidth
                                visible: row.kind === "busy"
                            }

                            // A switch: a filled or empty square, then its state. Anything else: just its value.
                            Label {
                                x: row.textColumn * Theme.cellWidth
                                width: (panel.contentColumns - row.textColumn - 1) * Theme.cellWidth
                                visible: !row.endsWithNumber
                                text: row.kind === "switch" ? (row.modelData.on ? "■ " : "□ ") + row.modelData.value : row.modelData.value
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
            visible: ring.ringShown > 0
            // Drawn through the dither only while it is changing.
            layer.enabled: ring.ringShown < 1
            layer.effect: DitherFade {
                amount: ring.ringShown
                spread: Theme.wipeFront
            }

            Repeater {
                model: [["←→ hl", " turn    "], ["↵", " open    "], ["esc", " close"]]

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
