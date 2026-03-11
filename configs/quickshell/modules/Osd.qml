import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import ".." as Root

PanelWindow {
    id: osd

    Root.Theme { id: theme }

    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
    }
    margins.bottom: 120

    implicitWidth: theme.osdWidth
    implicitHeight: theme.osdHeight
    color: "transparent"
    visible: false

    property int    curVolume: -1
    property bool   curMuted: false
    property int    curBrightness: -1
    property string activeMode: ""

    function show(mode) {
        activeMode = mode;
        visible = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: theme.osdTimeout
        onTriggered: osd.visible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: theme.osdRadius
        color: theme.osdBackground

        Row {
            anchors.centerIn: parent
            spacing: 14

            Text {
                text: {
                    if (osd.activeMode === "brightness") {
                        if (osd.curBrightness > 66)  return theme.iconBriHigh;
                        if (osd.curBrightness > 33)  return theme.iconBriMid;
                        if (osd.curBrightness > 0)   return theme.iconBriLow;
                        return theme.iconBriOff;
                    }
                    if (osd.curMuted)                 return theme.iconVolMute;
                    if (osd.curVolume > 60)           return theme.iconVolHigh;
                    if (osd.curVolume > 30)           return theme.iconVolMid;
                    if (osd.curVolume > 0)            return theme.iconVolLow;
                    return theme.iconVolMute;
                }
                color: theme.textPrimary
                font { family: theme.fontFamily; pixelSize: theme.osdIconSize }
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: 140
                height: 8
                radius: 4
                color: theme.osdBarBg
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: {
                        let pct = osd.activeMode === "brightness"
                                  ? osd.curBrightness : osd.curVolume;
                        if (pct < 0) pct = 0;
                        if (pct > 100) pct = 100;
                        return parent.width * pct / 100;
                    }
                    height: parent.height
                    radius: parent.radius
                    color: theme.osdAccent

                    Behavior on width {
                        NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                    }
                }
            }

            Text {
                text: {
                    let pct = osd.activeMode === "brightness"
                              ? osd.curBrightness : osd.curVolume;
                    if (osd.activeMode === "volume" && osd.curMuted) return "M";
                    return pct >= 0 ? pct + "%" : "--";
                }
                width: 36
                color: theme.textPrimary
                font { family: theme.fontFamily; pixelSize: theme.osdFontSize }
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ── Volume: fast poll via wpctl ──
    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let wasMuted = osd.curMuted;
                let wasVol = osd.curVolume;

                osd.curMuted = data.indexOf("[MUTED]") !== -1;
                let parts = data.split(" ");
                if (parts.length >= 2) {
                    let frac = parseFloat(parts[1]);
                    if (!isNaN(frac)) osd.curVolume = Math.round(frac * 100);
                }

                if (wasVol >= 0 && (osd.curVolume !== wasVol || osd.curMuted !== wasMuted))
                    osd.show("volume");
            }
        }

        onExited: volPollTimer.start()
    }

    Timer {
        id: volPollTimer
        interval: 50
        onTriggered: volProc.running = true
    }

    // ── Brightness: fast poll (no event API for brightnessctl) ──
    Process {
        id: briProc
        command: [
            "bash", "-c",
            "cur=$(brightnessctl get 2>/dev/null) && max=$(brightnessctl max 2>/dev/null) && " +
            "echo $((cur * 100 / max)) || echo -1"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let wasBri = osd.curBrightness;
                let val = parseInt(data);
                if (!isNaN(val)) osd.curBrightness = val;

                if (wasBri >= 0 && osd.curBrightness !== wasBri)
                    osd.show("brightness");
            }
        }

        onExited: briPollTimer.start()
    }

    Timer {
        id: briPollTimer
        interval: 80
        onTriggered: briProc.running = true
    }
}
