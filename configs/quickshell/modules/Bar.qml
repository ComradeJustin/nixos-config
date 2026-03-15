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
    property bool zoneReleased: false
    property bool showCava: false
    property var notifRef: null

    onIsHiddenChanged: {
        if (isHidden) {
            zoneRestoreTimer.stop();
            zoneReleaseTimer.start();
        } else {
            zoneReleaseTimer.stop();
            zoneRestoreTimer.start();
        }
    }

    Timer {
        id: zoneReleaseTimer
        interval: 220
        onTriggered: barScope.zoneReleased = true
    }

    Timer {
        id: zoneRestoreTimer
        interval: 220
        onTriggered: barScope.zoneReleased = false
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
        exclusiveZone: barScope.zoneReleased ? 0 : theme.barHeight

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

                    BarModules.NixosIcon { anchors.verticalCenter: parent.verticalCenter }
                    BarModules.WorkspaceModule { anchors.verticalCenter: parent.verticalCenter }
                    BarModules.TimeModule { anchors.verticalCenter: parent.verticalCenter }
                    BarModules.WindowModule { anchors.verticalCenter: parent.verticalCenter }
                }

                // ── Center (media) ──
                BarModules.MediaModule {
                    id: mediaModule
                    anchors.centerIn: parent
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
                        onWifiClicked: {
                            if (barScope.notifRef) barScope.notifRef.toggle();
                        }
                    }
                    BarModules.NotifIcon { notifRef: barScope.notifRef; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

    // ══════════════════════════════════
    // ── Media popup (album art + controls + progress + cava bg) ──
    // ══════════════════════════════════
    property bool cavaWanted: barScope.showCava && !barScope.isHidden
    property real trackPos: 0
    property real trackLen: 0

    // position and length are in SECONDS with ms precision
    function formatTime(secs) {
        if (secs <= 0) return "0:00";
        let s = Math.floor(secs);
        let m = Math.floor(s / 60);
        s = s % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Timer {
        interval: 1000; repeat: true; running: barScope.cavaWanted && mediaModule.player != null
        onTriggered: {
            if (mediaModule.player) {
                // Must call positionChanged() to force position update
                mediaModule.player.positionChanged();
                barScope.trackPos = mediaModule.player.position ?? 0;
                barScope.trackLen = mediaModule.player.length ?? 0;
            }
        }
    }

    onCavaWantedChanged: {
        if (cavaWanted) {
            cavaPanel.visible = true;
        }
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

                // ── Cava bars as background ──
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
                                let vals = cavaRect.bars;
                                if (!vals || index >= vals.length) return 1;
                                return Math.max(1, vals[index] * (theme.cavaHeight - 10));
                            }
                            radius: width / 2
                            anchors.bottom: parent.bottom
                            color: cavaRect.bars && index < cavaRect.bars.length && cavaRect.bars[index] > 0.7 ? theme.cavaBarPeak : theme.cavaBarColor
                            Behavior on height { NumberAnimation { duration: 50 } }
                        }
                    }
                }

                property var bars: []

                // ── Content on top of cava ──
                Column {
                    id: mediaContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 6

                    // Art + info
                    Row {
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            width: theme.cavaArtSize; height: theme.cavaArtSize
                            radius: 10; clip: true
                            color: Qt.rgba(theme.textDimmed.r, theme.textDimmed.g, theme.textDimmed.b, 0.2)

                            Image {
                                id: artImg
                                anchors.fill: parent
                                source: mediaModule.player?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                smooth: true; asynchronous: true
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                text: theme.iconMediaPlay; color: theme.textDimmed
                                font { family: theme.fontFamily; pixelSize: 24 }
                                visible: artImg.status !== Image.Ready
                            }
                        }

                        Column {
                            width: parent.width - theme.cavaArtSize - 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: mediaModule.player?.trackTitle ?? ""
                                color: theme.textPrimary
                                font { family: theme.fontFamily; pixelSize: 13; bold: true }
                                width: parent.width; elide: Text.ElideRight
                            }
                            Text {
                                text: mediaModule.player?.trackArtist ?? ""
                                color: theme.textDimmed
                                font { family: theme.fontFamily; pixelSize: 11 }
                                width: parent.width; elide: Text.ElideRight
                                visible: (mediaModule.player?.trackArtist ?? "").length > 0
                            }
                        }
                    }

                    // Progress bar
                    Item {
                        width: parent.width; height: 14
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            height: 3; radius: 2; color: theme.textDimmed; opacity: 0.3
                        }
                        Rectangle {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            height: 3; radius: 2; color: theme.textAccent
                            width: barScope.trackLen > 0 ? parent.width * (barScope.trackPos / barScope.trackLen) : 0
                        }
                        Rectangle {
                            width: 8; height: 8; radius: 4; color: theme.textAccent
                            y: (parent.height - 8) / 2
                            x: barScope.trackLen > 0 ? (parent.width - 8) * (barScope.trackPos / barScope.trackLen) : 0
                        }
                    }

                    // Time labels
                    Item {
                        width: parent.width; height: 12
                        Text {
                            anchors.left: parent.left
                            text: barScope.formatTime(barScope.trackPos)
                            color: theme.textDimmed
                            font { family: theme.fontFamily; pixelSize: 10 }
                        }
                        Text {
                            anchors.right: parent.right
                            text: barScope.formatTime(barScope.trackLen)
                            color: theme.textDimmed
                            font { family: theme.fontFamily; pixelSize: 10 }
                        }
                    }

                    // Controls: prev — play/pause circle — next
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 20
                        height: 36

                        Text {
                            text: theme.iconPrev
                            color: theme.textPrimary
                            font { family: theme.fontFamily; pixelSize: 18 }
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (mediaModule.player?.canGoPrevious) mediaModule.player.previous(); }
                            }
                        }

                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: theme.textAccent
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: mediaModule.isPlaying ? theme.iconMediaPause : theme.iconMediaPlay
                                color: theme.barBackground
                                font { family: theme.fontFamily; pixelSize: 18 }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (mediaModule.player?.canTogglePlaying) mediaModule.player.isPlaying = !mediaModule.player.isPlaying; }
                            }
                        }

                        Text {
                            text: theme.iconNext
                            color: theme.textPrimary
                            font { family: theme.fontFamily; pixelSize: 18 }
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (mediaModule.player?.canGoNext) mediaModule.player.next(); }
                            }
                        }
                    }
                }

                Process {
                    id: cavaProc
                    command: [
                        "bash", "-c",
                        "cava -p /dev/stdin <<'CAVAEOF'\n" +
                        "[general]\n" +
                        "bars = " + theme.cavaBars + "\n" +
                        "framerate = 30\n" +
                        "[output]\n" +
                        "method = raw\n" +
                        "raw_target = /dev/stdout\n" +
                        "data_format = ascii\n" +
                        "ascii_max_range = 100\n" +
                        "CAVAEOF"
                    ]
                    running: true

                    stdout: SplitParser {
                        splitMarker: "\n"
                        onRead: data => {
                            let parts = data.trim().split(";").filter(s => s.length > 0);
                            let vals = [];
                            for (let i = 0; i < parts.length; i++) {
                                let v = parseInt(parts[i]);
                                vals.push(isNaN(v) ? 0 : v / 100);
                            }
                            if (vals.length > 0)
                                cavaRect.bars = vals;
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent; z: -1
                    onClicked: barScope.showCava = false
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
        interval: 200
        onTriggered: fsProc.running = true
    }
}
