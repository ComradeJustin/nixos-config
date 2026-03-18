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
    property string curDevice: ""
    property string activeMode: ""   // "volume" | "brightness" | "device"
    property string deviceLabel: ""

    // ── Show / hide with fade ──
    function show(mode) {
        activeMode = mode;
        visible = true;
        content.opacity = 1;
        fadeOut.stop();
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: theme.osdTimeout
        onTriggered: fadeOut.start()
    }

    NumberAnimation {
        id: fadeOut
        target: content
        property: "opacity"
        from: 1
        to: 0
        duration: theme.osdFadeMs
        easing.type: Easing.InCubic

        onFinished: osd.visible = false
    }

    // ── Visual ──
    Rectangle {
        id: content
        anchors.fill: parent
        radius: 0  // Brutalist: square
        color: theme.osdBackground
        border.width: theme.borderWidth
        border.color: theme.borderColor
        opacity: 1

        Row {
            anchors.centerIn: parent
            spacing: 14
            visible: osd.activeMode !== "device"

            // Icon
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

            // Progress bar (brutalist: square)
            Rectangle {
                width: 140
                height: 4
                radius: 0
                color: theme.osdBarBg
                border.width: 1
                border.color: theme.borderColor
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
                    radius: 0
                    color: theme.osdAccent

                    Behavior on width {
                        NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                    }
                }
            }

            // Percentage
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

        // ── Device switch display ──
        Row {
            anchors.centerIn: parent
            spacing: 10
            visible: osd.activeMode === "device"

            Text {
                text: {
                    let name = osd.deviceLabel.toLowerCase();
                    if (name.indexOf("headphone") !== -1 || name.indexOf("headset") !== -1)
                        return theme.iconHeadphone;
                    return theme.iconSpeaker;
                }
                color: theme.osdAccent
                font { family: theme.fontFamily; pixelSize: theme.osdIconSize }
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: osd.deviceLabel || "Audio Device"
                color: theme.textPrimary
                font { family: theme.fontFamily; pixelSize: theme.osdFontSize }
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: Math.min(implicitWidth, theme.osdWidth - 80)
            }
        }
    }

    // ── Adaptive polling: fast when OSD visible, slow when idle ──
    property int fastPollInterval: 100
    property int slowPollInterval: 500
    property bool recentlyActive: false

    Timer {
        id: activityCooldown
        interval: 2000
        onTriggered: osd.recentlyActive = false
    }

    function markActive() {
        recentlyActive = true;
        activityCooldown.restart();
    }

    function getPollInterval() {
        return (osd.visible || osd.recentlyActive) ? fastPollInterval : slowPollInterval;
    }

    // ── Volume poll ──
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

                if (wasVol >= 0 && (osd.curVolume !== wasVol || osd.curMuted !== wasMuted)) {
                    osd.markActive();
                    osd.show("volume");
                }
            }
        }

        onExited: volPollTimer.start()
    }

    Timer {
        id: volPollTimer
        interval: osd.getPollInterval()
        onTriggered: volProc.running = true
    }

    // ── Device name poll ──
    Process {
        id: devProc
        command: [
            "bash", "-c",
            "wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | " +
            "grep -oP 'node\\.description\\s*=\\s*\"\\K[^\"]+' || echo ''"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let name = data.trim();
                if (name.length === 0) return;

                let wasDevice = osd.curDevice;
                osd.curDevice = name;
                osd.deviceLabel = name;

                // Show OSD on device change (skip initial read)
                if (wasDevice.length > 0 && wasDevice !== name)
                    osd.show("device");
            }
        }

        onExited: devPollTimer.start()
    }

    Timer {
        id: devPollTimer
        interval: 800  // Device changes are rare, poll slowly
        onTriggered: devProc.running = true
    }

    // ── Brightness poll ──
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

                if (wasBri >= 0 && osd.curBrightness !== wasBri) {
                    osd.markActive();
                    osd.show("brightness");
                }
            }
        }

        onExited: briPollTimer.start()
    }

    Timer {
        id: briPollTimer
        interval: osd.getPollInterval()
        onTriggered: briProc.running = true
    }
}
