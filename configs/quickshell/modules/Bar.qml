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

                    BarModules.UtilsModule { anchors.verticalCenter: parent.verticalCenter }
                    BarModules.NotifIcon { notifRef: barScope.notifRef; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

    // ══════════════════════════════════
    // ── Media popup (album art + controls + cava) ──
    // ══════════════════════════════════
    property bool cavaWanted: barScope.showCava && !barScope.isHidden

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

                // ── Top section: album art + info + controls ──
                Row {
                    id: mediaInfo
                    anchors {
                        top: parent.top
                        topMargin: 10
                        left: parent.left
                        leftMargin: 12
                        right: parent.right
                        rightMargin: 12
                    }
                    spacing: 10

                    // ── Album art ──
                    Rectangle {
                        width: theme.cavaArtSize
                        height: theme.cavaArtSize
                        radius: 8
                        color: artImg.status === Image.Ready ? "transparent" : Qt.rgba(theme.textDimmed.r, theme.textDimmed.g, theme.textDimmed.b, 0.2)
                        clip: true

                        Image {
                            id: artImg
                            anchors.fill: parent
                            source: {
                                let url = mediaModule.player?.trackArtUrl ?? "";
                                if (url.length === 0) return "";
                                // trackArtUrl is already a valid URL (file:// or https://)
                                return url;
                            }
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            visible: status === Image.Ready
                        }

                        // Fallback icon
                        Text {
                            anchors.centerIn: parent
                            text: theme.iconMediaPlay
                            color: theme.textDimmed
                            font { family: theme.fontFamily; pixelSize: 24 }
                            visible: artImg.status !== Image.Ready
                        }
                    }

                    // ── Track info + controls ──
                    Column {
                        width: parent.width - theme.cavaArtSize - 22
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: mediaModule.player?.trackTitle ?? ""
                            color: theme.textPrimary
                            font { family: theme.fontFamily; pixelSize: theme.notifTitleSize; bold: true }
                            width: parent.width
                            elide: Text.ElideRight
                        }

                        Text {
                            text: mediaModule.player?.trackArtist ?? ""
                            color: theme.textDimmed
                            font { family: theme.fontFamily; pixelSize: theme.notifBodySize }
                            width: parent.width
                            elide: Text.ElideRight
                            visible: (mediaModule.player?.trackArtist ?? "").length > 0
                        }

                        // ── Playback controls ──
                        Row {
                            spacing: 16

                            Text {
                                text: theme.iconPrev
                                color: theme.textPrimary
                                font { family: theme.fontFamily; pixelSize: 18 }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (mediaModule.player?.canGoPrevious) mediaModule.player.previous(); }
                                }
                            }

                            Text {
                                text: mediaModule.isPlaying ? theme.iconMediaPause : theme.iconMediaPlay
                                color: theme.textAccent
                                font { family: theme.fontFamily; pixelSize: 22 }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (mediaModule.player?.canTogglePlaying) mediaModule.player.isPlaying = !mediaModule.player.isPlaying; }
                                }
                            }

                            Text {
                                text: theme.iconNext
                                color: theme.textPrimary
                                font { family: theme.fontFamily; pixelSize: 18 }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (mediaModule.player?.canGoNext) mediaModule.player.next(); }
                                }
                            }
                        }
                    }
                }

                // ── Cava bars at the bottom ──
                Row {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2

                    Repeater {
                        model: theme.cavaBars

                        Rectangle {
                            width: Math.max(2, (theme.cavaWidth - (theme.cavaBars - 1) * 2 - 24) / theme.cavaBars)
                            height: {
                                let vals = cavaRect.bars;
                                let maxH = theme.cavaHeight - mediaInfo.height - 26;
                                if (maxH < 10) maxH = 10;
                                if (!vals || index >= vals.length) return 2;
                                return Math.max(2, vals[index] * maxH);
                            }
                            radius: width / 2
                            anchors.bottom: parent.bottom
                            color: {
                                let vals = cavaRect.bars;
                                if (vals && index < vals.length && vals[index] > 0.7)
                                    return theme.cavaBarPeak;
                                return theme.cavaBarColor;
                            }

                            Behavior on height {
                                NumberAnimation { duration: 50; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }

                property var bars: []

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
                    anchors.fill: parent
                    anchors.topMargin: mediaInfo.height + 16
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
