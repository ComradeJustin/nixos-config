import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets

Scope {
    id: root

    // Bind the pipewire node so its volume will be tracked
    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio

        function onVolumeChanged() {
            root.shouldShowOsd = true
            hideTimer.restart()
        }
    }

    property bool shouldShowOsd: false

    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: root.shouldShowOsd = false
    }

    // LazyLoader for the OSD
    LazyLoader {
        active: root.shouldShowOsd

        PanelWindow {
            anchors.bottom: true
            margins.bottom: screen.height / 5
            exclusiveZone: 0

            implicitWidth: 400
            implicitHeight: 50
            color: "transparent"

            mask: Region {}



            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "#80000000"

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 15
                    }

                    Rectangle {
                        // Background track
                        Layout.fillWidth: true
                        implicitHeight: 10
                        radius: 20
                        color: "#50ffffff"

                        Rectangle {
                            id: volumeBar
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            // Animate the width when volume changes
                            width: parent.width * (Pipewire.defaultAudioSink?.audio.volume ?? 0)
                            radius: parent.radius
                            color: "#ffffff"

                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        }
                    }
                }
            }
        }
    }
}
