import Quickshell
import Quickshell.Wayland
import QtQuick
import ".." as Root

PanelWindow {
    id: osd

    // Service references (injected from Shell.qml)
    property var audioService: null
    property var brightnessService: null

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

    // Show / hide with fade
    function show(mode) {
        activeMode = mode;
        visible = true;
        content.opacity = 1;
        fadeOut.stop();
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: Root.Theme.osdTimeout
        onTriggered: fadeOut.start()
    }

    NumberAnimation {
        id: fadeOut
        target: content
        property: "opacity"
        from: 1
        to: 0
        duration: Root.Theme.osdFadeMs
        easing.type: Easing.InCubic
        onFinished: osd.visible = false
    }

    // Visual display
    Rectangle {
        id: content
        anchors.fill: parent
        radius: 0
        color: Root.Theme.osdBackground
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor
        opacity: 1

        // Volume/Brightness display
        Row {
            anchors.centerIn: parent
            spacing: 14
            visible: osd.activeMode !== "device"

            // Icon
            Text {
                text: {
                    if (osd.activeMode === "brightness") {
                        if (osd.curBrightness > 66) return Root.Theme.iconBriHigh;
                        if (osd.curBrightness > 33) return Root.Theme.iconBriMid;
                        if (osd.curBrightness > 0)  return Root.Theme.iconBriLow;
                        return Root.Theme.iconBriOff;
                    }
                    if (osd.curMuted)              return Root.Theme.iconVolMute;
                    if (osd.curVolume > 60)        return Root.Theme.iconVolHigh;
                    if (osd.curVolume > 30)        return Root.Theme.iconVolMid;
                    if (osd.curVolume > 0)         return Root.Theme.iconVolLow;
                    return Root.Theme.iconVolMute;
                }
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.osdIconSize }
                anchors.verticalCenter: parent.verticalCenter
            }

            // Progress bar
            Rectangle {
                width: 140
                height: 4
                radius: 0
                color: Root.Theme.osdBarBg
                border.width: 1
                border.color: Root.Theme.borderColor
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: {
                        let pct = osd.activeMode === "brightness"
                                  ? osd.curBrightness : osd.curVolume;
                        return parent.width * Math.max(0, Math.min(100, pct)) / 100;
                    }
                    height: parent.height
                    radius: 0
                    color: Root.Theme.osdAccent

                    Behavior on width {
                        NumberAnimation { duration: 50; easing.type: Easing.OutCubic }
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
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.osdFontSize }
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
                        return Root.Theme.iconHeadphone;
                    return Root.Theme.iconSpeaker;
                }
                color: Root.Theme.osdAccent
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.osdIconSize }
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: osd.deviceLabel || "Audio Device"
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.osdFontSize }
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: Math.min(implicitWidth, Root.Theme.osdWidth - 80)
            }
        }
    }
}
