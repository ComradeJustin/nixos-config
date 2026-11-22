import QtQuick
import Quickshell
import Quickshell.Wayland

// The ambient layer: what is on screen when nothing is summoned.
// Three small readouts sit inside niri's top gap, so they take no space from
// windows. There are no icons: every value is a labelled meter or number,
// like markings on equipment. Sample values, except the clock.
PanelWindow {
    id: strip

    // The shell root (shell.qml).
    required property var shell

    // Matches `gaps 16` in configs/niri/layout.kdl.
    readonly property int gapHeight: 16

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: gapHeight
    // Sit on top of the gap without pushing windows down.
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Top

    // One readout pill.
    component Pill: Rectangle {
        default property alias content: row.data

        height: strip.gapHeight
        width: row.implicitWidth + 18
        radius: height / 2
        color: Theme.surface

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 6
        }
    }

    // --- Workspaces: one tick each, the focused one lit ---
    Pill {
        anchors.left: parent.left
        anchors.leftMargin: 16

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "ws"
            caps: true
            mono: true
            color: Theme.textDim
            font.pixelSize: 9
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Repeater {
                model: 5

                Rectangle {
                    required property int index

                    readonly property bool focused: index === 1
                    readonly property bool occupied: index < 3

                    anchors.verticalCenter: parent.verticalCenter
                    width: focused ? 10 : 3
                    height: 8
                    radius: 1
                    color: focused ? Theme.accent : (occupied ? Theme.textDim : Theme.stroke)
                }
            }
        }
    }

    // --- Date and time ---
    Pill {
        anchors.horizontalCenter: parent.horizontalCenter

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(strip.shell.now, "ddd d MMM")
            caps: true
            mono: true
            color: Theme.textDim
            font.pixelSize: 9
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(strip.shell.now, "hh:mm")
            mono: true
            weight: 750
            color: Theme.textStrong
            font.pixelSize: 11
        }
    }

    // --- Status: network, volume, battery ---
    Pill {
        anchors.right: parent.right
        anchors.rightMargin: 16

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "net"
            caps: true
            mono: true
            color: Theme.textDim
            font.pixelSize: 9
        }

        Meter {
            anchors.verticalCenter: parent.verticalCenter
            level: 0.75
            segments: 4
            segmentWidth: 2
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: " vol"
            caps: true
            mono: true
            color: Theme.textDim
            font.pixelSize: 9
        }

        Meter {
            anchors.verticalCenter: parent.verticalCenter
            level: strip.shell.volume / 100
            segments: 6
            segmentWidth: 2
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: " bat"
            caps: true
            mono: true
            color: Theme.textDim
            font.pixelSize: 9
        }

        Meter {
            anchors.verticalCenter: parent.verticalCenter
            level: 0.28
            segments: 10
            segmentWidth: 2
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "28"
            mono: true
            weight: 750
            color: Theme.textStrong
            font.pixelSize: 10
        }
    }
}
