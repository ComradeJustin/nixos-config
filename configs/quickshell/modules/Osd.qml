import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import ".." as Root
import "../core" as Core

PanelWindow {
    id: osd

    // Self-wired via ServiceManager
    readonly property var audioService: Core.ServiceManager.audio
    readonly property var brightnessService: Core.ServiceManager.brightness

    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { bottom: true }
    margins.bottom: 120

    implicitWidth: Root.Theme.osdWidth
    implicitHeight: Root.Theme.osdHeight
    color: "transparent"
    visible: false

    property string activeMode: ""   // "volume" | "brightness" | "device"

    // Computed values from services
    readonly property int curVolume: audioService ? audioService.volume : 0
    readonly property bool curMuted: audioService ? audioService.muted : false
    readonly property int curBrightness: brightnessService ? brightnessService.brightness : 0
    readonly property string deviceLabel: audioService ? audioService.activeDeviceLabel : ""

    // Active accent color — changes per mode
    readonly property color activeAccent: {
        if (activeMode === "volume") return curMuted ? Root.Theme.textDimmed : Root.Theme.domainMedia;
        if (activeMode === "brightness") return Root.Theme.accentWarm;
        return Root.Theme.osdAccent;
    }

    // Connect to service signals
    Connections {
        target: osd.audioService
        function onVolumeUpdated(oldValue, newValue) { osd.show("volume"); }
        function onMuteToggled(oldMuted, newMuted) { osd.show("volume"); }
        function onDeviceSwitched(oldDevice, newDevice) { osd.show("device"); }
    }

    Connections {
        target: osd.brightnessService
        function onBrightnessUpdated(oldValue, newValue) { osd.show("brightness"); }
    }

    // Show / hide with slide + fade
    function show(mode) {
        activeMode = mode;
        hideTimer.restart();

        // Already fully visible — just reset the dismiss timer, skip animation
        if (visible && !fadeOut.running) return;

        // Either hidden or fading out — (re)play entrance
        visible = true;
        fadeOut.stop();
        showAnim.stop();
        showAnim.start();
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: content; property: "opacity"; from: content.opacity; to: 1; duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: content; property: "scale"; from: 0.92; to: 1; duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutBack; easing.overshoot: 0.3 }
        NumberAnimation { target: slideEffect; property: "y"; from: slideEffect.y !== 0 ? slideEffect.y : 12; to: 0; duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic }
    }

    Timer {
        id: hideTimer
        interval: Root.Theme.osdTimeout
        onTriggered: fadeOut.start()
    }

    ParallelAnimation {
        id: fadeOut
        NumberAnimation { target: content; property: "opacity"; to: 0; duration: Root.Theme.osdFadeMs; easing.type: Easing.InCubic }
        NumberAnimation { target: content; property: "scale"; to: 0.95; duration: Root.Theme.osdFadeMs; easing.type: Easing.InCubic }
        NumberAnimation { target: slideEffect; property: "y"; to: 8; duration: Root.Theme.osdFadeMs; easing.type: Easing.InCubic }
        onFinished: osd.visible = false
    }

    // Dismiss on hover (like end-4)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
            hideTimer.stop();
            fadeOut.start();
        }
    }

    // Visual display
    Rectangle {
        id: content
        anchors.fill: parent
        transform: Translate { id: slideEffect; y: 0 }
        radius: Root.Theme.osdRadius
        color: Root.Theme.osdBackground
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor
        opacity: 1

        layer.enabled: osd.visible
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 0.8
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 2
        }

        // Volume/Brightness display
        Row {
            anchors.centerIn: parent
            spacing: 14
            visible: osd.activeMode !== "device"

            // Icon with accent color
            Text {
                text: {
                    if (osd.activeMode === "brightness")
                        return Root.Icons.brightnessIcon(osd.curBrightness);
                    return Root.Icons.volumeIcon(osd.curVolume, osd.curMuted);
                }
                color: osd.activeAccent
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.osdIconSize }
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
            }

            // Progress bar (pill-shaped, thicker)
            Rectangle {
                width: 140
                height: 6
                radius: 3
                color: Root.Theme.osdBarBg
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: {
                        let pct = osd.activeMode === "brightness"
                                  ? osd.curBrightness : osd.curVolume;
                        return parent.width * Math.max(0, Math.min(100, pct)) / 100;
                    }
                    height: parent.height
                    radius: 3
                    color: osd.activeAccent

                    Behavior on width {
                        NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Root.Theme.anim.microDuration }
                    }
                }

                // Knob indicator at the end of the fill
                Rectangle {
                    visible: !(osd.activeMode === "volume" && osd.curMuted)
                    x: {
                        let pct = osd.activeMode === "brightness"
                                  ? osd.curBrightness : osd.curVolume;
                        return parent.width * Math.max(0, Math.min(100, pct)) / 100 - 4;
                    }
                    y: -1
                    width: 8; height: 8; radius: 4
                    color: Root.Theme.textPrimary
                    Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
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
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.osdFontSize; bold: true }
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Device switch display
        Row {
            anchors.centerIn: parent
            spacing: 10
            visible: osd.activeMode === "device"

            Text {
                text: {
                    let name = osd.deviceLabel.toLowerCase();
                    if (name.indexOf("headphone") !== -1 || name.indexOf("headset") !== -1)
                        return Root.Icons.headphone;
                    return Root.Icons.speaker;
                }
                color: Root.Theme.osdAccent
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.osdIconSize }
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: osd.deviceLabel || "Audio Device"
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.osdFontSize; bold: true }
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: Math.min(implicitWidth, Root.Theme.osdWidth - 80)
            }
        }
    }
}
