import QtQuick
import Quickshell
import Quickshell.Wayland

// What a volume key press looks like: a slab drops out of the right end of
// the bar with the number and a long level, then slides back up.
PanelWindow {
    id: readout

    // The shell root (shell.qml).
    required property var shell

    readonly property int slabWidth: 264
    readonly property int slabHeight: 76

    // 0 = tucked into the bar, 1 = fully dropped.
    property real drop: shell.volumeShown ? 1 : 0

    Behavior on drop {
        SpringAnimation {
            spring: Theme.dropSpring
            damping: Theme.dropDamping
            epsilon: 0.002
        }
    }

    // Stay mapped while the closing spring is still settling.
    visible: shell.volumeShown || drop > 0.02
    anchors {
        top: true
        right: true
    }
    // Zone 0 in normal mode places this directly under the bar.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: slabWidth
    implicitHeight: slabHeight
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Overlay

    // The window clips the slab, so it appears to slide out from under the bar.
    Rectangle {
        y: -readout.slabHeight * (1 - readout.drop)
        width: readout.slabWidth
        height: readout.slabHeight
        color: Theme.slab
        border.width: 1
        border.color: Theme.rule

        Label {
            x: 16
            y: 12
            text: "volume"
            caps: true
            color: Theme.inkDim
            font.pixelSize: 8
        }

        Label {
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 6
            text: readout.shell.volume
            weight: 850
            color: Theme.ink
            font.pixelSize: 30
        }

        LevelBar {
            x: 16
            y: 52
            width: readout.slabWidth - 32
            height: 8
            level: readout.shell.volume / 100
        }
    }
}
