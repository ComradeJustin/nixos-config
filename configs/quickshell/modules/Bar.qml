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

    onIsHiddenChanged: {
        if (isHidden) {
            // Slide out first, then release zone after animation
            zoneRestoreTimer.stop();
            zoneReleaseTimer.start();
        } else {
            // Slide in first, then restore zone after animation
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

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: theme.barPadding
                    anchors.rightMargin: theme.barPadding
                    spacing: 0

                    RowLayout {
                        Layout.alignment: Qt.AlignLeft
                        spacing: theme.barSpacing

                        BarModules.WorkspaceModule {}
                        BarModules.TimeModule {}
                        BarModules.WindowModule {}
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: theme.barSpacing

                        BarModules.UtilsModule {}
                    }
                }
            }
        }
    }

    // ── Fullscreen detection ──
    // Compares focused window size to output size.
    // If the window covers the full output, treat as fullscreen.
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
