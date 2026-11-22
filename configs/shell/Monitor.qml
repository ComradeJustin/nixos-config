import QtQuick
import Quickshell
import Quickshell.Wayland

// The monitor: the other summoned layer, beside the ring. It is one
// dashboard in the middle of the screen: bands of panels (a rebuild of the
// system across the top, then the machine's readings), with every
// reading showing at once and graphs several rows tall for what changes
// over time. There is nothing to select or expand: esc, or a click beside
// it, closes it.
//
// Each panel is a Panel, so it is made of the same rows as the ring's
// pages. What the panels hold, and which sit side by side in a band, comes
// from MonitorData.qml. A panel in trouble, such as a nearly full disk or a
// failed service, is drawn in the alert colour.
//
// It moves the way the ring does. The panels are wiped in one after
// another, in reading order, and leave the way they came.
PanelWindow {
    id: monitor

    // The shell root (shell.qml), which holds the state.
    required property var shell

    // The bands, top to bottom: each a list of panels { title, alert, rows }.
    readonly property var bands: shell.monitorBands
    readonly property int panelCount: panelsBefore(bands.length)

    // How much of the monitor is showing: 0 = closed, 1 = open.
    property real openness: shell.monitorOpen ? 1 : 0
    // The last panel starts to wipe in when the monitor is this far shown.
    readonly property real sweepShare: 0.7

    Behavior on openness {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    // --- Geometry, in cells ---
    // Every band is this wide. Its panels share that, two cells apart.
    readonly property int totalColumns: 130
    readonly property int totalRows: rowsAbove(bands.length) - 1
    readonly property real gridX: Theme.snapX((width - totalColumns * Theme.cellWidth) / 2)
    readonly property real gridY: Theme.snapY((height - totalRows * Theme.cellHeight) / 2)

    // How many panels come before this band, for wiping them in in order.
    function panelsBefore(bandIndex: int): int {
        let count = 0;
        for (let index = 0; index < bandIndex; index++)
            count += monitor.bands[index].length;
        return count;
    }

    // How many rows of cells lie above this band. Each band above takes
    // its rows, its two border lines and a line of space. The panels of a
    // band are all the same height (MonitorData.qml).
    function rowsAbove(bandIndex: int): int {
        let rows = 0;
        for (let index = 0; index < bandIndex; index++)
            rows += monitor.bands[index][0].rows.length + 3;
        return rows;
    }

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
            event.accepted = true;
            if (event.key === Qt.Key_Escape)
                monitor.shell.closeMonitor();
        }

        // A click beside the panels closes the monitor.
        MouseArea {
            anchors.fill: parent
            onClicked: monitor.shell.closeMonitor()
        }

        // --- The bands, and the panels of each ---
        // The models are counts, not the lists themselves: the lists are
        // made afresh with every reading, and a panel should live on.
        Repeater {
            model: monitor.bands.length

            Item {
                id: band

                required property int index

                readonly property var panels: monitor.bands[index]
                // One or two panels in a band are wide ones, with longer
                // bars and graphs; three are narrow.
                readonly property bool wide: panels.length <= 2
                readonly property int panelColumns: (monitor.totalColumns - 2 * (panels.length - 1)) / panels.length

                Repeater {
                    model: band.panels.length

                    Panel {
                        required property int index

                        readonly property var panel: band.panels[index]
                        readonly property bool inTrouble: panel.alert === true
                        // Where this panel comes in reading order.
                        readonly property int order: monitor.panelsBefore(band.index) + index

                        x: monitor.gridX + index * (band.panelColumns + 2) * Theme.cellWidth
                        y: monitor.gridY + monitor.rowsAbove(band.index) * Theme.cellHeight
                        columns: band.panelColumns
                        // A panel can ask for more room for its labels.
                        valueColumn: panel.valueColumn !== undefined ? panel.valueColumn : (band.wide ? 12 : 10)
                        levelCells: panel.levelCells !== undefined ? panel.levelCells : (band.wide ? 34 : 14)
                        // Every row shows; nothing scrolls.
                        maxListRows: panel.rows.length
                        page: panel
                        entries: panel.rows
                        // Nothing here is selected.
                        selectedIndex: -1
                        footer: ""
                        titleColor: inTrouble ? Theme.alert : Theme.ink
                        lineColor: inTrouble ? Theme.alert : Theme.line
                        // Panels wipe in one after another, in reading order.
                        shown: monitor.clamp01((monitor.openness - monitor.sweepShare * order / monitor.panelCount) / (1 - monitor.sweepShare))
                        visible: shown > 0

                        // A click on a panel must not reach the empty part
                        // of the monitor and close it.
                        MouseArea {
                            anchors.fill: parent
                        }
                    }
                }
            }
        }

        // --- The key hint ---
        Row {
            x: Theme.snapX((parent.width - width) / 2)
            y: Theme.snapY(parent.height - 2 * Theme.cellHeight)
            visible: monitor.openness > 0
            // Drawn through the dither only while it is changing.
            layer.enabled: monitor.openness < 1
            layer.effect: DitherFade {
                amount: monitor.openness
                spread: Theme.wipeFront
            }

            Label {
                text: "esc"
                color: Theme.ink
            }

            Label {
                text: " close"
                color: Theme.inkDim
            }
        }
    }
}
