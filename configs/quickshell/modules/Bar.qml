import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".." as Root
import "barmodules" as BarModules

Scope {
    id: barScope

    Root.Theme { id: theme }

    property bool isHidden: false
    property bool showCava: false
    property var notifRef: null
    property var playerService: null
    property var powerService: null
    property var audioService: null
    property var powerMenuRef: null
    property var wifiService: null

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
        implicitHeight: theme.barHeight

        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: barScope.isHidden ? 0 : theme.barHeight

        color: "transparent"

        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                id: bg
                width: parent.width
                height: theme.barHeight
                color: theme.barBackground
                y: barScope.isHidden ? -theme.barHeight : 0

                Behavior on y {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
                }

                // ── Left ──
                Row {
                    id: leftSection
                    height: theme.barHeight
                    anchors {
                        left: parent.left
                        leftMargin: theme.barPadding
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: theme.barSpacing
                    width: Math.min(implicitWidth, mediaModule.x - theme.barPadding - theme.barSpacing)
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
                    height: theme.barHeight
                    anchors {
                        right: parent.right
                        rightMargin: theme.barPadding
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: theme.barSpacing

                    BarModules.UtilsModule {
                        id: utilsModule
                        anchors.verticalCenter: parent.verticalCenter
                        audioService: barScope.audioService
                        wifiService: barScope.wifiService
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
    property bool cavaWanted: barScope.showCava && !barScope.isHidden
    property var ps: barScope.playerService

    onCavaWantedChanged: {
        if (cavaWanted) cavaPanel.visible = true;
    }

    PanelWindow {
        id: cavaPanel

        visible: false

        anchors { top: true }
        implicitWidth: theme.cavaWidth
        margins.top: theme.barHeight
        implicitHeight: theme.cavaHeight + 6

        WlrLayershell.namespace: "quickshell-cava"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"

        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                id: cavaRect
                width: parent.width
                height: theme.cavaHeight
                radius: theme.cavaRadius
                color: theme.cavaBackground

                y: barScope.cavaWanted ? 6 : -(theme.cavaHeight + 6)

                Behavior on y {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
                }

                onYChanged: {
                    if (!barScope.cavaWanted && y <= -(theme.cavaHeight + 5))
                        cavaPanel.visible = false;
                }

                // Block all clicks from falling through to compositor
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                // ── Cava bars as background (from playerService) ──
                Row {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 1
                    opacity: 0.15

                    Repeater {
                        model: theme.cavaBars
                        Rectangle {
                            width: Math.max(1, (theme.cavaWidth - theme.cavaBars - 20) / theme.cavaBars)
                            height: {
                                let vals = barScope.ps ? barScope.ps.cavaBars : [];
                                if (!vals || index >= vals.length) return 1;
                                return Math.max(1, vals[index] * (theme.cavaHeight - 10));
                            }
                            radius: width / 2
                            anchors.bottom: parent.bottom
                            color: {
                                let vals = barScope.ps ? barScope.ps.cavaBars : [];
                                return (vals && index < vals.length && vals[index] > 0.7) ? theme.cavaBarPeak : theme.cavaBarColor;
                            }
                            Behavior on height { NumberAnimation { duration: 50 } }
                        }
                    }
                }

                // ── Content ──
                Column {
                    id: mediaContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 6

                    Row {
                        width: parent.width; spacing: 10

                        Rectangle {
                            width: theme.cavaArtSize; height: theme.cavaArtSize
                            radius: 10; clip: true
                            color: Qt.rgba(theme.textDimmed.r, theme.textDimmed.g, theme.textDimmed.b, 0.2)

                            Image {
                                id: artImg; anchors.fill: parent
                                source: barScope.ps ? barScope.ps.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop; smooth: true; asynchronous: true
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent; text: theme.iconMediaPlay; color: theme.textDimmed
                                font { family: theme.fontFamily; pixelSize: 24 }
                                visible: artImg.status !== Image.Ready
                            }
                        }

                        Column {
                            width: parent.width - theme.cavaArtSize - 10
                            anchors.verticalCenter: parent.verticalCenter; spacing: 2

                            Text {
                                text: barScope.ps ? barScope.ps.trackTitle : ""
                                color: theme.textPrimary
                                font { family: theme.fontFamily; pixelSize: 13; bold: true }
                                width: parent.width; elide: Text.ElideRight
                            }
                            Text {
                                text: barScope.ps ? barScope.ps.trackArtist : ""
                                color: theme.textDimmed
                                font { family: theme.fontFamily; pixelSize: 11 }
                                width: parent.width; elide: Text.ElideRight
                                visible: barScope.ps ? barScope.ps.trackArtist.length > 0 : false
                            }
                        }
                    }

                    // Seekable progress bar
                    Item {
                        id: seekBar
                        width: parent.width; height: 18
                        property real pos: barScope.ps ? barScope.ps.position : 0
                        property real len: barScope.ps ? barScope.ps.length : 0
                        property real ratio: len > 0 ? pos / len : 0
                        property bool dragging: false
                        property real dragRatio: 0

                        Rectangle {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            height: 4; radius: 2; color: theme.textDimmed; opacity: 0.3
                        }
                        Rectangle {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            height: 4; radius: 2; color: theme.textAccent
                            width: parent.width * (seekBar.dragging ? seekBar.dragRatio : seekBar.ratio)
                        }
                        Rectangle {
                            width: 12; height: 12; radius: 6; color: theme.textAccent
                            y: (parent.height - 12) / 2
                            x: (parent.width - 12) * (seekBar.dragging ? seekBar.dragRatio : seekBar.ratio)
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onPressed: function(mouse) {
                                seekBar.dragging = true;
                                seekBar.dragRatio = Math.max(0, Math.min(1, mouse.x / seekBar.width));
                            }
                            onPositionChanged: function(mouse) {
                                if (pressed)
                                    seekBar.dragRatio = Math.max(0, Math.min(1, mouse.x / seekBar.width));
                            }
                            onReleased: {
                                if (barScope.ps && seekBar.len > 0)
                                    barScope.ps.seek(seekBar.dragRatio * seekBar.len);
                                seekBar.dragging = false;
                            }
                        }
                    }

                    // Time labels
                    Item {
                        width: parent.width; height: 12
                        Text {
                            anchors.left: parent.left
                            text: barScope.ps ? barScope.ps.formatTime(seekBar.dragging ? seekBar.dragRatio * seekBar.len : seekBar.pos) : "0:00"
                            color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 10 }
                        }
                        Text {
                            anchors.right: parent.right
                            text: barScope.ps ? barScope.ps.formatTime(seekBar.len) : "0:00"
                            color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 10 }
                        }
                    }

                    // Controls
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 20; height: 36

                        Text {
                            text: theme.iconPrev; color: theme.textPrimary
                            font { family: theme.fontFamily; pixelSize: 18 }
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (barScope.ps) barScope.ps.previous(); } }
                        }

                        Rectangle {
                            width: 36; height: 36; radius: 18; color: theme.textAccent
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: (barScope.ps && barScope.ps.isPlaying) ? theme.iconMediaPause : theme.iconMediaPlay
                                color: theme.barBackground
                                font { family: theme.fontFamily; pixelSize: 18 }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (barScope.ps) barScope.ps.togglePlaying(); } }
                        }

                        Text {
                            text: theme.iconNext; color: theme.textPrimary
                            font { family: theme.fontFamily; pixelSize: 18 }
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (barScope.ps) barScope.ps.next(); } }
                        }
                    }
                }
            }
        }
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
