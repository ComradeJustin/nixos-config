import QtQuick
import Quickshell
import Quickshell.Wayland
import "sample-data.js" as SampleData

// Desktop widgets: a clock and a few tiles in the bottom left corner of the
// desktop, on top of the wallpaper and under every window. The tiles are
// the same ones the monitor uses: what is playing, today, and the system
// rebuild, which follows a rebuild while one runs.
PanelWindow {
    id: desktop

    // The shell root (shell.qml).
    required property var shell

    // What the tiles show, top to bottom.
    readonly property var widgets: [SampleData.desktopWidgets[0], SampleData.desktopWidgets[1], shell.applets[0]]
    // The height one tile takes, with the gap to the next.
    readonly property int tilePitch: 7 * Theme.cellHeight
    readonly property int tileColumns: 40
    // The clock above the tiles is this many rows tall, with its gap.
    readonly property int clockRows: 6

    // 0 = nothing showing, 1 = everything.
    property real shown: shell.desktopShown ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    // Stay mapped until everything has been wiped away.
    visible: shell.desktopShown || shown > 0
    anchors {
        bottom: true
        left: true
    }
    margins.left: 4 * Theme.cellWidth
    margins.bottom: 6 * Theme.cellHeight
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: tileColumns * Theme.cellWidth + Theme.shadowOffset
    implicitHeight: clockRows * Theme.cellHeight + widgets.length * tilePitch
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Bottom

    // The time at four times size, the date under it.
    Item {
        width: parent.width
        height: 5 * Theme.cellHeight
        visible: desktop.shown > 0
        // Drawn through the dither only while it is changing.
        layer.enabled: desktop.shown < 1
        layer.effect: DitherFade {
            amount: desktop.shown
            spread: Theme.wipeFront
        }

        Label {
            text: Qt.formatDateTime(desktop.shell.now, "hh:mm")
            scaleFactor: 4
            color: Theme.ink
        }

        Label {
            y: 4 * Theme.cellHeight
            text: Qt.formatDateTime(desktop.shell.now, "dddd d MMMM")
            color: Theme.inkSoft
            smallCaps: true
        }
    }

    Repeater {
        model: desktop.widgets.length

        Tile {
            required property int index

            y: desktop.clockRows * Theme.cellHeight + index * desktop.tilePitch
            columns: desktop.tileColumns
            applet: desktop.widgets[index]
            shown: desktop.shown
            visible: shown > 0
        }
    }
}
