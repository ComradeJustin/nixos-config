import QtQuick
import Quickshell
import Quickshell.Wayland

// What a notification looks like: two lines of type drop out of the bar
// under the clock, then slide back up.
PanelWindow {
    id: toast

    // The shell root (shell.qml).
    required property var shell

    readonly property int slabWidth: 420
    readonly property int slabHeight: 66

    // 0 = tucked into the bar, 1 = fully dropped.
    property real drop: shell.toastShown ? 1 : 0

    Behavior on drop {
        SpringAnimation {
            spring: Theme.dropSpring
            damping: Theme.dropDamping
            epsilon: 0.002
        }
    }

    // Stay mapped while the closing spring is still settling.
    visible: shell.toastShown || drop > 0.02
    anchors.top: true
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
        y: -toast.slabHeight * (1 - toast.drop)
        width: toast.slabWidth
        height: toast.slabHeight
        color: Theme.slab

        Column {
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 40
            spacing: 4

            // Who it is from, heavy; which app, light.
            Row {
                spacing: 10

                Label {
                    text: "Mara"
                    weight: 850
                    color: Theme.ink
                    font.pixelSize: 15
                }

                Label {
                    text: "Vesktop"
                    weight: 320
                    color: Theme.inkDim
                    font.pixelSize: 15
                }
            }

            Label {
                width: parent.width
                text: "are you still coming tonight?"
                elide: Text.ElideRight
            }
        }
    }
}
