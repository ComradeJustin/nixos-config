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
                RowLayout {
                    anchors {
                        left: parent.left
                        leftMargin: theme.barPadding
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: theme.barSpacing

                    BarModules.NixosIcon {}
                    BarModules.WorkspaceModule {}
                    BarModules.TimeModule {}
                    BarModules.WindowModule {}
                }

                // ── Center (media) — absolute center, independent of sides ──
                BarModules.MediaModule {
                    id: mediaModule
                    anchors.centerIn: parent
                    onCavaToggled: barScope.showCava = !barScope.showCava
                }

                // ── Right ──
                RowLayout {
                    anchors {
                        right: parent.right
                        rightMargin: theme.barPadding
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: theme.barSpacing

                    BarModules.UtilsModule {}
                    BarModules.NotifIcon { notifRef: barScope.notifRef }
                }
            }
        }
    }

    // ══════════════════════════════════
    // ── Cava visualizer popup ──
    // ══════════════════════════════════
    property bool cavaWanted: barScope.showCava && !barScope.isHidden

    onCavaWantedChanged: {
        if (cavaWanted) {
            cavaSlideOut.stop();
            cavaPanel.visible = true;
            cavaSlideIn.start();
        } else {
            cavaSlideIn.stop();
            cavaSlideOut.start();
        }
    }

    NumberAnimation {
        id: cavaSlideIn
        target: cavaRect
        property: "y"
        from: -theme.cavaHeight
        to: 0
        duration: 200
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: cavaSlideOut
        target: cavaRect
        property: "y"
        from: 0
        to: -theme.cavaHeight
        duration: 200
        easing.type: Easing.InCubic
        onFinished: cavaPanel.visible = false
    }

    PanelWindow {
        id: cavaPanel

        visible: false

        anchors {
            top: true
        }
        implicitWidth: theme.cavaWidth
        margins.top: theme.barHeight + 6
        implicitHeight: theme.cavaHeight

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
                y: -theme.cavaHeight
                radius: theme.cavaRadius
                color: theme.cavaBackground

                property var bars: []

                Row {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2

                    Repeater {
                        model: theme.cavaBars

                        Rectangle {
                            width: Math.max(2, (theme.cavaWidth - (theme.cavaBars - 1) * 2 - 16) / theme.cavaBars)
                            height: {
                                let vals = cavaRect.bars;
                                let maxH = theme.cavaHeight - 16;
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
                    onClicked: barScope.showCava = false
                }
            }
        }
    }

    // ══════════════════════════════════
    // ── Fullscreen detection ──
    // ══════════════════════════════════
    Process {
        id: fsProc
        command: [
            "bash", "-c",
            "command -v jq >/dev/null || { echo 0; exit; }; " +
            "w=$(niri msg -j focused-window 2>/dev/null) || { echo 0; exit; }; " +
            "ww=$(echo \"$w\" | jq '.layout.window_size[0] // 0' 2>/dev/null); " +
            "wh=$(echo \"$w\" | jq '.layout.window_size[1] // 0' 2>/dev/null); " +
            "o=$(niri msg -j outputs 2>/dev/null) || { echo 0; exit; }; " +
            "ow=$(echo \"$o\" | jq '[.[]][0].logical.width // 0' 2>/dev/null); " +
            "oh=$(echo \"$o\" | jq '[.[]][0].logical.height // 0' 2>/dev/null); " +
            "if [ \"${ww%.*}\" -ge \"${ow%.*}\" ] 2>/dev/null && [ \"${wh%.*}\" -ge \"${oh%.*}\" ] 2>/dev/null; then echo 1; else echo 0; fi"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                barScope.isHidden = (data.trim() === "1");
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
