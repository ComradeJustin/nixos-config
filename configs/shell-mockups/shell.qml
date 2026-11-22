import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Design mockups for the shell redesign. Entry point.
//
// These are static pictures of three possible layouts, drawn as real panels
// so they can be judged on the actual desktop. Only the clock is live;
// everything else is sample content and nothing is wired to the system.
//
// Start:   systemd-run --user --unit=shell-mockup --collect quickshell -p ~/nixos-config/configs/shell-mockups
// Stop:    systemctl --user stop shell-mockup
// Switch:  click the control strip at the bottom of the screen, or
//          qs -p ~/nixos-config/configs/shell-mockups ipc call shell-mockup layout <bar|rail|strip>
//          qs -p ~/nixos-config/configs/shell-mockups ipc call shell-mockup panel
//          qs -p ~/nixos-config/configs/shell-mockups ipc call shell-mockup toast
// Files reload on save.
ShellRoot {
    id: root

    // Which layout is on screen: "bar", "rail" or "strip".
    property string layout: "bar"
    // Whether the sample status panel and the sample toast are showing.
    property bool panelOpen: false
    property bool toastOpen: false

    readonly property var now: clock.date

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    BarLayout {
        shell: root
    }

    RailLayout {
        shell: root
    }

    StripLayout {
        shell: root
    }

    IpcHandler {
        target: "shell-mockup"

        function layout(name: string): void {
            root.layout = name;
        }

        function panel(): void {
            root.panelOpen = !root.panelOpen;
        }

        function toast(): void {
            root.toastOpen = !root.toastOpen;
        }
    }

    // Control strip for reviewing the mockups. Not part of any design.
    PanelWindow {
        anchors.bottom: true
        margins.bottom: 10
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: controls.implicitWidth + 12
        implicitHeight: 32
        color: "transparent"
        WlrLayershell.namespace: "shell-mockup"
        WlrLayershell.layer: WlrLayer.Overlay

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusControl
            color: Theme.surface
            border.width: 1
            border.color: Theme.stroke

            Row {
                id: controls

                anchors.centerIn: parent
                spacing: 4

                Choice {
                    label: "A · Top bar"
                    selected: root.layout === "bar"
                    onChosen: root.layout = "bar"
                }

                Choice {
                    label: "B · Side rail"
                    selected: root.layout === "rail"
                    onChosen: root.layout = "rail"
                }

                Choice {
                    label: "C · Gap strip"
                    selected: root.layout === "strip"
                    onChosen: root.layout = "strip"
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 14
                    color: Theme.stroke
                }

                Choice {
                    label: "Panel"
                    selected: root.panelOpen
                    onChosen: root.panelOpen = !root.panelOpen
                }

                Choice {
                    label: "Toast"
                    selected: root.toastOpen
                    onChosen: root.toastOpen = !root.toastOpen
                }
            }
        }
    }

    // One clickable choice in the control strip.
    component Choice: Rectangle {
        id: choice

        property string label
        property bool selected: false
        signal chosen

        width: choiceLabel.implicitWidth + 20
        height: 22
        radius: 6
        color: selected ? Theme.accentSoft : "transparent"

        Text {
            id: choiceLabel

            anchors.centerIn: parent
            text: choice.label
            color: choice.selected ? Theme.accent : Theme.textDim
            font.family: Theme.fontUi
            font.pixelSize: 11
        }

        MouseArea {
            anchors.fill: parent
            onClicked: choice.chosen()
        }
    }
}
