import Quickshell
import Quickshell.Wayland
import QtQuick
import Qt5Compat.GraphicalEffects
import ".." as Root

// Centered power menu overlay.
// Toggle via IPC: qs ipc call quickshell-bar power
Scope {
    id: pm

    // Theme is now a singleton - access via Root.Theme.propertyName

    property bool showing: false
    property var powerService: null
    property int selectedIndex: 0

    property var actions: [
        { icon: Root.Theme.iconLock, label: "Lock", action: "lock", color: Root.Theme.domainSettings },
        { icon: Root.Theme.iconSuspend, label: "Suspend", action: "suspend", color: Root.Theme.accentWarning },
        { icon: Root.Theme.iconLogout, label: "Logout", action: "logout", color: Root.Theme.domainNetwork },
        { icon: Root.Theme.iconReboot, label: "Reboot", action: "reboot", color: Root.Theme.accentWarm },
        { icon: Root.Theme.iconShutdown, label: "Shutdown", action: "shutdown", color: Root.Theme.accentDanger }
    ]

    function toggle() {
        showing = !showing;
        if (showing) {
            pmPanel.visible = true;
            selectedIndex = 0;
        }
    }

    signal lockRequested()

    function execute(action) {
        showing = false;
        if (action === "lock") { lockRequested(); return }
        if (!powerService) return;
        if (action === "suspend") powerService.suspend();
        else if (action === "logout") powerService.logout();
        else if (action === "reboot") powerService.reboot();
        else if (action === "shutdown") powerService.shutdown();
    }

    PanelWindow {
        id: pmPanel
        visible: false

        anchors { top: true; bottom: true; left: true; right: true }

        WlrLayershell.namespace: "quickshell-powermenu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        // Scrim
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            opacity: pm.showing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            MouseArea { anchors.fill: parent; onClicked: pm.showing = false }
        }

        // Center content
        Column {
            anchors.centerIn: parent
            spacing: 20
            scale: pm.showing ? 1 : 0.9
            opacity: pm.showing ? 1 : 0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            onOpacityChanged: {
                if (!pm.showing && opacity <= 0.01) pmPanel.visible = false;
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Session"
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: 22; bold: true }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Arrow keys to navigate, Enter to select\nEsc or click anywhere to cancel"
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 12 }
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.3
            }

            // Icon grid
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Repeater {
                    model: pm.actions

                    Rectangle {
                        id: pmItem
                        width: 90; height: 90
                        radius: pm.selectedIndex === index ? 45 : 16
                        color: pm.selectedIndex === index
                            ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.8)
                            : Root.Theme.ccSectionBg

                        Behavior on radius { NumberAnimation { duration: 150 } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        layer.enabled: pm.selectedIndex === index
                        layer.effect: Glow {
                            color: Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.5)
                            radius: 16
                            samples: 33
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: pm.selectedIndex === index ? Root.Theme.barBackground : modelData.color
                            font { family: Root.Theme.fontFamily; pixelSize: 28 }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: pm.selectedIndex = index
                            onClicked: pm.execute(modelData.action)
                        }
                    }
                }
            }

            // Label for selected
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pm.actions[pm.selectedIndex].label
                color: pm.actions[pm.selectedIndex].color
                font { family: Root.Theme.fontFamily; pixelSize: 14; bold: true }
            }
        }

        // Keyboard
        Item {
            anchors.fill: parent
            focus: pm.showing

            Keys.onEscapePressed: pm.showing = false
            Keys.onReturnPressed: pm.execute(pm.actions[pm.selectedIndex].action)
            Keys.onLeftPressed: { if (pm.selectedIndex > 0) pm.selectedIndex--; }
            Keys.onRightPressed: { if (pm.selectedIndex < pm.actions.length - 1) pm.selectedIndex++; }
        }
    }
}
