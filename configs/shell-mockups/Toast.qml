import QtQuick
import Quickshell
import Quickshell.Wayland

// What a notification looks like: a panel titled with the app is wiped in
// under the clock, then wiped away.
PanelWindow {
    id: toast

    // The shell root (shell.qml).
    required property var shell

    // 0 = nothing showing, 1 = the whole panel.
    property real shown: shell.toastShown ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    // Stay mapped until the panel has been wiped away.
    visible: shell.toastShown || shown > 0
    anchors.top: true
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

        columns: 52
        rows: 2
        title: "✦ Vesktop"
        footer: "now"
        shown: toast.shown

        Label {
            text: "Mara"
            color: Theme.ink
        }

        Label {
            y: Theme.cellHeight
            text: "are you still coming tonight?"
        }
    }
}
