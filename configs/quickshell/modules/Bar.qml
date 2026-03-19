import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".." as Root
import "barmodules" as BarModules

Scope {
    id: barScope

    // Theme is now a singleton - access via Root.Theme.propertyName

    property bool isHidden: false
    property bool showCava: false
    property var notifRef: null
    property var playerService: null
    property var powerService: null
    property var audioService: null
    property var powerMenuRef: null
    property var wifiService: null
    property var bluetoothService: null

    onIsHiddenChanged: {
        if (isHidden) {
            // Start slide-out, then hide panel after animation
            zoneReleaseTimer.start();
        } else {
            // Show panel first, then slide in
            panel.visible = true;
            zoneRestoreTimer.start();
        }
    }

    Timer {
        id: zoneReleaseTimer
        interval: 220
        onTriggered: panel.visible = false
    }

    Timer {
        id: zoneRestoreTimer
        interval: 220
        onTriggered: {} // animation already playing from visible=true
    }

    // ══════════════════════════════════
    // ── Bar panel ──
    // ══════════════════════════════════
    PanelWindow {
        id: panel

        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Root.Theme.barHeight

        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: barScope.isHidden ? 0 : Root.Theme.barHeight

        color: "transparent"

        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                id: bg
                width: parent.width
                height: Root.Theme.barHeight
                color: Root.Theme.barBackground
                y: barScope.isHidden ? -Root.Theme.barHeight : 0

                Behavior on y {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
                }

                // ── Left ──
                Row {
                    id: leftSection
                    height: Root.Theme.barHeight
                    anchors {
                        left: parent.left
                        leftMargin: Root.Theme.barPadding
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Root.Theme.barSpacing
                    width: Math.min(implicitWidth, mediaModule.x - Root.Theme.barPadding - Root.Theme.barSpacing)
                    clip: true

                    BarModules.PowerIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: { if (barScope.powerMenuRef) barScope.powerMenuRef.toggle(); }
                    }
                    BarModules.WorkspaceModule { anchors.verticalCenter: parent.verticalCenter }
                    BarModules.TimeModule { anchors.verticalCenter: parent.verticalCenter }
                    BarModules.WeatherModule { anchors.verticalCenter: parent.verticalCenter }
                    BarModules.WindowModule { anchors.verticalCenter: parent.verticalCenter }
                }

                // ── Center (media) ──
                BarModules.MediaModule {
                    id: mediaModule
                    anchors.centerIn: parent
                    playerService: barScope.playerService
                    onCavaToggled: barScope.showCava = !barScope.showCava
                }

                // ── Right ──
                Row {
                    id: rightSection
                    height: Root.Theme.barHeight
                    anchors {
                        right: parent.right
                        rightMargin: Root.Theme.barPadding
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Root.Theme.barSpacing

                    BarModules.UtilsModule {
                        id: utilsModule
                        anchors.verticalCenter: parent.verticalCenter
                        audioService: barScope.audioService
                        wifiService: barScope.wifiService
                        bluetoothService: barScope.bluetoothService
                    }
                    BarModules.GearIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        isOpen: barScope.notifRef ? barScope.notifRef.showing : false
                        onClicked: { if (barScope.notifRef) barScope.notifRef.toggle(); }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════
    // ── Media popup (uses playerService) ──
    // ══════════════════════════════════
    BarModules.MediaPopup {
        playerService: barScope.playerService
        showCava: barScope.showCava
        barHidden: barScope.isHidden
    }

    // ══════════════════════════════════
    // ── Fullscreen detection ──
    // ── Only hides if the fullscreen window is on the same output as the bar ──
    // ══════════════════════════════════
    Process {
        id: fsProc
        command: [
            "bash", "-c",
            "command -v jq >/dev/null || { echo 0; exit; }; " +
            // Get focused window
            "w=$(niri msg -j focused-window 2>/dev/null) || { echo 0; exit; }; " +
            "ww=$(echo \"$w\" | jq '.layout.window_size[0] // 0'); " +
            "wh=$(echo \"$w\" | jq '.layout.window_size[1] // 0'); " +
            "wsid=$(echo \"$w\" | jq '.workspace_id // -1'); " +
            // Find which output this workspace is on
            "ws=$(niri msg -j workspaces 2>/dev/null) || { echo 0; exit; }; " +
            "output=$(echo \"$ws\" | jq -r --argjson id \"$wsid\" '.[] | select(.id == $id) | .output // \"\"'); " +
            "[ -z \"$output\" ] && { echo 0; exit; }; " +
            // Get that output's dimensions
            "o=$(niri msg -j outputs 2>/dev/null) || { echo 0; exit; }; " +
            "ow=$(echo \"$o\" | jq --arg n \"$output\" '.[$n].logical.width // 0'); " +
            "oh=$(echo \"$o\" | jq --arg n \"$output\" '.[$n].logical.height // 0'); " +
            // Output the result as "fullscreen output_name"
            "if [ \"${ww%.*}\" -ge \"${ow%.*}\" ] 2>/dev/null && [ \"${wh%.*}\" -ge \"${oh%.*}\" ] 2>/dev/null; then " +
            "  echo \"1 $output\"; " +
            "else " +
            "  echo 0; " +
            "fi"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(" ");
                if (parts[0] === "1") {
                    // Only hide if the fullscreen window is on the bar's screen
                    let fsOutput = parts.slice(1).join(" ");
                    let barScreen = panel.screen?.name ?? "";
                    barScope.isHidden = (barScreen === "" || fsOutput === barScreen);
                } else {
                    barScope.isHidden = false;
                }
            }
        }

        onExited: fsPollTimer.start()
    }

    Timer {
        id: fsPollTimer
        interval: 350  // Fullscreen detection doesn't need to be instant
        onTriggered: fsProc.running = true
    }
}
