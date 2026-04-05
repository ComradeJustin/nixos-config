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

    // Show / hide with slide + fade
    function show(mode) {
        activeMode = mode;
        visible = true;
        showAnim.stop();
        fadeOut.stop();
        showAnim.start();
        hideTimer.restart();
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: content; property: "opacity"; from: content.opacity; to: 1; duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: slideEffect; property: "y"; from: slideEffect.y !== 0 ? slideEffect.y : 8; to: 0; duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic }
    }

    Timer {
        id: hideTimer
        interval: Root.Theme.osdTimeout
        onTriggered: fadeOut.start()
    }

    ParallelAnimation {
        id: fadeOut
        NumberAnimation { target: content; property: "opacity"; to: 0; duration: Root.Theme.osdFadeMs; easing.type: Easing.InCubic }
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
        radius: Root.Theme.radiusMedium
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
                    if (osd.activeMode === "brightness")
                        return Root.Icons.brightnessIcon(osd.curBrightness);
                    return Root.Icons.volumeIcon(osd.curVolume, osd.curMuted);
                }
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.osdIconSize }
                anchors.verticalCenter: parent.verticalCenter
            }

            // Progress bar (rounded)
            Rectangle {
                width: 140
                height: 4
                radius: 2
                color: Root.Theme.osdBarBg
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: {
                        let pct = osd.activeMode === "brightness"
                                  ? osd.curBrightness : osd.curVolume;
                        return parent.width * Math.max(0, Math.min(100, pct)) / 100;
                    }
                    height: parent.height
                    radius: 2
                    color: osd.activeMode === "volume" && osd.curMuted
                        ? Root.Theme.textDimmed : Root.Theme.osdAccent

                    Behavior on width {
                        NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Root.Theme.anim.microDuration }
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
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.osdFontSize }
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: Math.min(implicitWidth, Root.Theme.osdWidth - 80)
            }
        }
    }
}
