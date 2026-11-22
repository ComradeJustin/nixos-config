import QtQuick
import Quickshell
import Quickshell.Wayland

// Desktop widgets: a clock in the bottom left corner of the desktop, and
// under it what is playing, when something is. Both are panels, so they
// read over any wallpaper.
//
// They show only while the focused workspace has no windows. When a window
// appears they are wiped away, and when the last one goes they are wiped
// back in. They sit on the layer above the windows, which niri keeps still:
// on the layer under the windows niri would slide them along with the
// workspace every time it changed, and a window would just cover them.
// Clicks go straight through them.
PanelWindow {
    id: desktop

    // The shell root (shell.qml).
    required property var shell

    // The media player to show: the one playing, or else the first one.
    readonly property var player: shell.mediaPlayer
    // The tile for it, in the shape Tile.qml takes, or null for no player.
    readonly property var playingTile: player === null ? null : ({
            title: player.isPlaying ? "Now playing" : "Paused",
            alert: false,
            summary: [
                {
                    label: "Track",
                    kind: "text",
                    value: player.trackTitle
                },
                {
                    label: "Artist",
                    kind: "text",
                    value: player.trackArtist
                },
                {
                    label: "Player",
                    kind: "text",
                    value: player.identity
                }
            ]
        })

    readonly property int tileColumns: 40
    // The clock's panel: five rows inside its border, and with the border
    // and the gap under it, eight.
    readonly property int clockRows: 8
    // A tile of three rows, its border and its shadow.
    readonly property int tileHeight: 5 * Theme.cellHeight + Theme.shadowOffset

    // 0 = nothing showing, 1 = everything.
    property real shown: shell.workspaceEmpty ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    // Stay mapped until everything has been wiped away.
    visible: shown > 0
    anchors {
        bottom: true
        left: true
    }
    margins.left: 4 * Theme.cellWidth
    margins.bottom: 4 * Theme.cellHeight
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: tileColumns * Theme.cellWidth + Theme.shadowOffset
    implicitHeight: clockRows * Theme.cellHeight + tileHeight
    color: "transparent"
    WlrLayershell.namespace: "shell"
    WlrLayershell.layer: WlrLayer.Top
    // An empty region: no part of the widgets takes clicks.
    mask: Region {}

    // The time at four times size, the date under it.
    Box {
        columns: desktop.tileColumns
        rows: 5
        shown: desktop.shown

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

    Tile {
        y: desktop.clockRows * Theme.cellHeight
        visible: desktop.playingTile !== null && shown > 0
        columns: desktop.tileColumns
        applet: desktop.playingTile
        shown: desktop.shown
    }
}
