import QtQuick
import Quickshell
import Quickshell.Wayland

// What a volume key press looks like: the word and the number drop out of
// the right end of the bar, then slide back up.
PanelWindow {
    id: readout

    // The shell root (shell.qml).
    required property var shell

    readonly property int slabWidth: 230
    readonly property int slabHeight: 62

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

        // The same size for both; only the weight tells the word from the number.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Label {
                anchors.baseline: number.baseline
                text: "Volume"
                weight: 320
                color: Theme.inkDim
                font.pixelSize: 28
            }

            Label {
                id: number

                text: readout.shell.volume
                mono: true
                weight: 900
                color: Theme.ink
                font.pixelSize: 28
            }
        }
    }
}
