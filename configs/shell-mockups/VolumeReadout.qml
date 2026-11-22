import QtQuick
import Quickshell
import Quickshell.Wayland

// What a volume key press looks like. The status pill in the top-right gap
// grows downward into a larger readout, then shrinks back into the pill:
// the same object changing size, not a separate popup.
PanelWindow {
    id: readout

    // The shell root (shell.qml).
    required property var shell

    // 0 = the resting pill, 1 = the full readout.
    property real growth: shell.volumeShown ? 1 : 0
    readonly property real shown: Math.max(0, Math.min(1, growth))

    Behavior on growth {
        SpringAnimation {
            spring: Theme.panelSpring
            damping: Theme.panelDamping
            epsilon: 0.002
        }
    }

    // Stay mapped while the closing spring is still settling.
    visible: shell.volumeShown || growth > 0.02
    anchors {
        top: true
        right: true
    }
    margins.right: 16
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300
    implicitHeight: 96
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Overlay

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        // From the size of the status pill to the full readout.
        width: 190 + 100 * readout.growth
        height: 16 + 60 * readout.growth
        radius: 8 + 4 * readout.shown
        color: Theme.surface
        border.width: 1
        border.color: Theme.stroke
        clip: true

        Item {
            anchors.fill: parent
            anchors.margins: 14
            // The contents arrive in the second half of the growth.
            opacity: Math.max(0, (readout.shown - 0.5) * 2)

            Label {
                anchors.left: parent.left
                anchors.top: parent.top
                text: "volume"
                caps: true
                mono: true
                color: Theme.textDim
                font.pixelSize: 10
            }

            Label {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: -8
                text: readout.shell.volume
                mono: true
                weight: 850
                color: Theme.textStrong
                font.pixelSize: 26
            }

            Meter {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                level: readout.shell.volume / 100
                segments: 32
                segmentWidth: 6
                segmentHeight: 14
            }
        }
    }
}
