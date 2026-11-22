import QtQuick
import Quickshell
import Quickshell.Wayland

// What a volume, brightness or microphone-mute key press looks like: a
// small panel is wiped in at the right end of the bar with a long bar and
// the number, then wiped away. The number flashes each time it changes.
// Muted sound or a muted microphone shows an empty bar and the word in the
// alert colour.
PanelWindow {
    id: readout

    // The shell root (shell.qml).
    required property var shell

    readonly property string kind: shell.readoutKind
    readonly property bool muted: (kind === "volume" && shell.muted) || (kind === "microphone" && shell.microphoneMuted)
    readonly property int amount: {
        if (kind === "volume")
            return shell.volume;
        if (kind === "microphone")
            return shell.microphoneLevel;
        return shell.brightness;
    }

    // 0 = nothing showing, 1 = the whole panel.
    property real shown: shell.readoutShown ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    // Stay mapped until the panel has been wiped away.
    visible: shell.readoutShown || shown > 0
    anchors {
        top: true
        right: true
    }
    margins.right: Theme.cellWidth
    // Directly under the bar, or against the top of the screen when a
    // fullscreen window has covered the bar.
    margins.top: shell.fullscreen ? 0 : Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Overlay

    Box {
        id: panel

        columns: 36
        rows: 1
        title: readout.shell.readoutKind
        shown: readout.shown

        Level {
            level: readout.muted ? 0 : readout.amount / 100
            // Leaves room for the longest value, "mute", and a space.
            cells: panel.contentColumns - 5
        }

        Value {
            anchors.right: parent.right
            text: readout.muted ? "mute" : readout.amount
            restColor: readout.muted ? Theme.alert : Theme.ink
        }
    }
}
