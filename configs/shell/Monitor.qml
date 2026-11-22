import QtQuick
import Quickshell
import Quickshell.Wayland

// The monitor: a second summoned layer, beside the ring. A grid of applets
// sits in the middle of the screen, each a small panel with four lines of
// summary: the system rebuild, processor, memory, network and so on. h j k
// l move between them, and enter expands the focused one into a full view
// in the same place. Esc collapses it, then closes the monitor.
//
// An applet's tile (Tile.qml) and its expanded view are both a Panel, at
// two sizes, so they use the same rows as the ring's pages. What they hold
// comes from MonitorData.qml. An applet in trouble, such as a failed
// service or a nearly full disk, is drawn in the alert colour.
//
// It moves the way the ring does. The tiles are wiped in one after another,
// in reading order; expanding wipes them away and then wipes the full view
// in; and everything leaves the way it came.
PanelWindow {
    id: monitor

    // The shell root (shell.qml), which holds the state.
    required property var shell

    readonly property var applets: shell.applets
    readonly property int appletCount: applets.length

    // --- The three animated values, chained as in Ring.qml ---
    // How much of the monitor is showing: 0 = closed, 1 = open. It stays
    // open until an expanded view has been wiped away.
    property real openness: shell.monitorOpen || viewOpen ? 1 : 0
    // 0 = the tiles are showing. 1 = they are wiped away, to make room for
    // an expanded view or because the monitor is closing.
    property real aside: !shell.monitorOpen || shell.monitorExpanded || viewOpen ? 1 : 0
    // How much of the expanded view is showing. It starts only once the
    // tiles have been wiped away.
    property real dive: shell.monitorExpanded && aside === 1 ? 1 : 0

    // How much of the tiles is showing, from 0 to 1.
    readonly property real tilesShown: Math.min(openness, 1 - aside)
    // The last tile starts to wipe in when the tiles are this far shown.
    readonly property real sweepShare: 0.7
    // True from when a view starts to wipe in until it has been wiped away.
    readonly property bool viewOpen: dive > 0

    Behavior on openness {
        NumberAnimation {
            duration: Theme.wipeMs
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

    // --- Geometry, in cells ---
    // A tile, and the space each one takes with the gap to the next.
    readonly property int tileColumns: 40
    readonly property int tileRows: 4
    readonly property int tilePitchX: (tileColumns + 2) * Theme.cellWidth
    readonly property int tilePitchY: (tileRows + 3) * Theme.cellHeight
    // The grid is this many tiles wide.
    readonly property int gridColumns: shell.monitorColumns
    readonly property int gridRows: Math.ceil(appletCount / gridColumns)
    readonly property real gridX: Theme.snapX((width - gridColumns * tilePitchX) / 2) + Theme.cellWidth
    readonly property real gridY: Theme.snapY((height - gridRows * tilePitchY) / 2)
    // The expanded view.
    readonly property int viewColumns: 76

    function clamp01(value: real): real {
        return Math.max(0, Math.min(1, value));
    }

    // Stay mapped until the monitor has closed all the way.
    visible: shell.monitorOpen || openness > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "shell"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shell.monitorOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible)
            stage.forceActiveFocus();
    }

    // Dim everything behind the monitor.
    Dim {
        level: monitor.openness
    }

    Item {
        id: stage

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const shell = monitor.shell;
            const key = event.key;
            const left = key === Qt.Key_H || key === Qt.Key_Left;
            const right = key === Qt.Key_L || key === Qt.Key_Right;
            const down = key === Qt.Key_J || key === Qt.Key_Down;
            const up = key === Qt.Key_K || key === Qt.Key_Up;
            event.accepted = true;

            if (key === Qt.Key_Escape) {
                shell.monitorBack();
                return;
            }

            // An applet is expanded: scroll its rows, or go back.
            if (shell.monitorExpanded) {
                if (down)
                    shell.monitorScroll(1);
                else if (up)
                    shell.monitorScroll(-1);
                else if (left)
                    shell.monitorBack();
                return;
            }

            // The tiles are showing: move between them, or expand one.
            if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space)
                shell.expandApplet();
            else if (left)
                shell.moveApplet(-1);
            else if (right)
                shell.moveApplet(1);
            else if (down)
                shell.moveApplet(shell.monitorColumns);
            else if (up)
                shell.moveApplet(-shell.monitorColumns);
        }

        // --- The mouse on the empty part of the monitor ---
        // A click beside everything goes back one step, like esc.
        MouseArea {
            anchors.fill: parent
            onClicked: monitor.shell.monitorBack()
        }

        // --- The tiles ---
        Repeater {
            model: monitor.appletCount

            Tile {
                id: tile

                required property int index

                readonly property bool focused: index === monitor.shell.monitorIndex

                x: monitor.gridX + (index % monitor.gridColumns) * monitor.tilePitchX
                y: monitor.gridY + Math.floor(index / monitor.gridColumns) * monitor.tilePitchY
                columns: monitor.tileColumns
                applet: monitor.applets[index]
                footer: focused ? "↵ expand" : ""
                // The focused tile has its border in the accent colour, and
                // flashes bright for a moment as it takes focus. An applet
                // in trouble keeps the alert colour unless it is focused.
                lineColor: focusFlash.running ? Theme.ink : (focused ? Theme.accent : (inTrouble ? Theme.alert : Theme.line))
                titleColor: inTrouble ? Theme.alert : (focused ? Theme.accent : Theme.ink)
                // Tiles wipe in one after another, in reading order.
                shown: monitor.clamp01((monitor.tilesShown - monitor.sweepShare * index / monitor.appletCount) / (1 - monitor.sweepShare))
                visible: shown > 0

                onFocusedChanged: {
                    if (focused)
                        focusFlash.restart();
                }

                Timer {
                    id: focusFlash

                    interval: Theme.flashMs
                }

                // The mouse focuses the tile it moves over; a click expands it.
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: monitor.shell.moveApplet(tile.index - monitor.shell.monitorIndex)
                    onClicked: {
                        monitor.shell.moveApplet(tile.index - monitor.shell.monitorIndex);
                        monitor.shell.expandApplet();
                    }
                }
            }
        }

        // A click on the expanded view itself must not reach the empty
        // part of the monitor and go back.
        MouseArea {
            anchors.fill: view
            visible: view.visible
        }

        // --- The expanded view of the focused applet ---
        Panel {
            id: view

            readonly property var applet: monitor.applets[monitor.shell.monitorIndex]

            x: Theme.snapX((parent.width - panelWidth) / 2)
            y: Theme.snapY((parent.height - panelHeight) / 2)
            columns: monitor.viewColumns
            valueColumn: 30
            levelCells: 28
            maxListRows: 14
            page: applet
            entries: applet.rows
            selectedIndex: monitor.shell.monitorSelected
            footer: "↑↓ scroll  esc back"
            titleColor: applet.alert === true ? Theme.alert : Theme.ink
            lineColor: applet.alert === true ? Theme.alert : Theme.line
            shown: monitor.dive
            visible: monitor.viewOpen
            // The mouse selects the row it is over; the wheel scrolls.
            interactive: true
            onRowEntered: entryIndex => monitor.shell.monitorScroll(entryIndex - monitor.shell.monitorSelected)
            onWheelTurned: step => monitor.shell.monitorScroll(step)
        }

        // --- Key hints for the tiles; an expanded view carries its own ---
        Row {
            x: Theme.snapX((parent.width - width) / 2)
            y: Theme.snapY(parent.height - 2 * Theme.cellHeight)
            visible: monitor.tilesShown > 0
            // Drawn through the dither only while it is changing.
            layer.enabled: monitor.tilesShown < 1
            layer.effect: DitherFade {
                amount: monitor.tilesShown
                spread: Theme.wipeFront
            }

            Repeater {
                model: [["←↓↑→", " move    "], ["↵", " expand    "], ["esc", " close"]]

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
