import QtQuick
import Quickshell
import Quickshell.Wayland

// Layout C — "Gap strip".
// No bar at all. niri already leaves a 16-pixel gap around the windows, so
// three small pills sit inside the top gap: workspaces, the time, and the
// status cluster. They reserve no space, so windows keep the full screen.
// The status panel opens in the middle of the screen as a "glance" card.
Scope {
    id: layout

    // The shell root (shell.qml), which holds which layout and panels are shown.
    required property var shell
    readonly property bool shown: shell.layout === "strip"

    // Matches `gaps 16` in configs/niri/layout.kdl.
    readonly property int gapHeight: 16

    // One pill in the strip.
    component Pill: Rectangle {
        default property alias content: slot.data

        height: layout.gapHeight
        width: slot.childrenRect.width + 16
        radius: height / 2
        color: Theme.surface

        Item {
            id: slot

            anchors.centerIn: parent
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    PanelWindow {
        visible: layout.shown
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: layout.gapHeight
        // Sit on top of the gap without pushing windows down.
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "shell-mockup"
        WlrLayershell.layer: WlrLayer.Top

        Pill {
            anchors.left: parent.left
            anchors.leftMargin: 16

            Workspaces {
                dotSize: 4
            }
        }

        Pill {
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                text: Qt.formatDateTime(layout.shell.now, "ddd d MMM  hh:mm")
                color: Theme.textStrong
                font.family: Theme.fontMono
                font.pixelSize: 10
            }
        }

        Pill {
            anchors.right: parent.right
            anchors.rightMargin: 16

            StatusIcons {
                iconSize: 10
                labelSize: 10
                spacing: 10
                onClicked: layout.shell.panelOpen = !layout.shell.panelOpen
            }
        }
    }

    // The status panel as a glance card in the middle of the screen.
    PanelWindow {
        visible: layout.shown && layout.shell.panelOpen
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight
        color: "transparent"
        WlrLayershell.namespace: "shell-mockup"
        WlrLayershell.layer: WlrLayer.Overlay

        StatusPanel {
            id: panel

            now: layout.shell.now
        }
    }

    // Notification toast, top right, just below the gap.
    PanelWindow {
        visible: layout.shown && layout.shell.toastOpen
        anchors {
            top: true
            right: true
        }
        margins {
            top: layout.gapHeight + 8
            right: 16
        }
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: toast.implicitWidth
        implicitHeight: toast.implicitHeight
        color: "transparent"
        WlrLayershell.namespace: "shell-mockup"
        WlrLayershell.layer: WlrLayer.Overlay

        NotificationCard {
            id: toast

            floating: true
        }
    }
}
