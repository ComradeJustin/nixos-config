import QtQuick
import QtQuick.Layouts
import "../.." as Root
import "../../components" as Components

// Volume/Audio tab content for ControlCenter
Flickable {
    id: root

    property var audioService: null

    contentHeight: volCol.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: volCol
        width: parent.width
        spacing: 8

        Item { width: 1; height: 2 }

        // ── Master Volume ──
        Rectangle {
            width: parent.width
            height: 56
            radius: Root.Theme.ccSectionRadius
            color: Root.Theme.ccSectionBg

            Row {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 10

                Rectangle {
                    width: 28; height: 28
                    radius: Root.Theme.radiusSmall
                    color: volMuteMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: (root.audioService && root.audioService.muted) ? Root.Theme.iconVolMute : Root.Theme.iconVolHigh
                        color: (root.audioService && root.audioService.muted) ? Root.Theme.textDimmed : Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: 20 }
                    }
                    MouseArea {
                        id: volMuteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.audioService) root.audioService.toggleMute(); }
                    }
                }

                Components.SliderBar {
                    width: parent.width - 20 - 50 - 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    value: root.audioService ? root.audioService.volume : 0
                    onValueUpdated: function(newValue) {
                        if (root.audioService) root.audioService.setVolume(Math.round(newValue));
                    }
                }

                Text {
                    text: (root.audioService ? root.audioService.volume : 0) + "%"
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: 14; bold: true }
                    width: 44
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // ── Per-App Audio Mixer ──
        Components.Separator {
            visible: root.audioService ? root.audioService.appStreams.count > 0 : false
        }

        Text {
            text: "App Mixer"
            color: Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: 12; bold: true }
            leftPadding: 4
            visible: root.audioService ? root.audioService.appStreams.count > 0 : false
        }

        Repeater {
            model: root.audioService ? root.audioService.appStreams : null
            Rectangle {
                width: volCol.width
                height: 52
                radius: Root.Theme.ccSectionRadius
                color: Root.Theme.ccSectionBg

                Row {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 10

                    Item {
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter

                        // Try icon from PipeWire, then app name as icon, then fallback
                        Image {
                            id: appIcn
                            anchors.fill: parent
                            source: {
                                if (model.appIcon && model.appIcon !== "")
                                    return "image://icon/" + model.appIcon;
                                if (model.appName && model.appName !== "")
                                    return "image://icon/" + model.appName.toLowerCase();
                                return "";
                            }
                            sourceSize.width: 24
                            sourceSize.height: 24
                            visible: status === Image.Ready
                            smooth: true
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Root.Theme.radiusSmall
                            color: Root.Theme.ccIconBg  // Muted icon placeholder
                            visible: appIcn.status !== Image.Ready

                            Text {
                                anchors.centerIn: parent
                                text: (model.appName || "?").charAt(0).toUpperCase()
                                color: Root.Theme.textSubtle
                                font { family: Root.Theme.fontFamily; pixelSize: 11; bold: true }
                            }
                        }
                    }

                    Column {
                        width: parent.width - 22 - 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: model.appName
                            color: Root.Theme.textPrimary
                            font { family: Root.Theme.fontFamily; pixelSize: 12 }
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            Components.SliderBar {
                                width: parent.width - 44
                                height: 14
                                handleSize: 10
                                value: model.appVol || 0
                                onValueUpdated: function(newValue) {
                                    if (root.audioService) root.audioService.setAppVolume(model.appIdx, Math.round(newValue));
                                }
                            }

                            Text {
                                text: (model.appVol || 0) + "%"
                                color: Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: 11 }
                                width: 36
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }

        Components.EmptyState {
            visible: root.audioService ? root.audioService.appStreams.count === 0 : true
            message: "No streams"
            preferredHeight: 40
        }

        // ── Output Devices ──
        Components.Separator {
            visible: root.audioService ? root.audioService.sinks.count > 0 : false
        }

        Text {
            text: "Output"
            color: Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: 12; bold: true }
            leftPadding: 4
            visible: root.audioService ? root.audioService.sinks.count > 0 : false
        }

        Repeater {
            model: root.audioService ? root.audioService.sinks : null
            Components.DeviceListItem {
                width: volCol.width
                icon: Root.Theme.iconSpeaker
                label: model.devDesc
                isActive: model.devActive
                showActiveBackground: true
                onClicked: { if (root.audioService) root.audioService.setSink(model.devName); }
            }
        }

        // ── Input Devices ──
        Components.Separator {
            visible: root.audioService ? root.audioService.sources.count > 0 : false
        }

        Text {
            text: "Input"
            color: Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: 12; bold: true }
            leftPadding: 4
            visible: root.audioService ? root.audioService.sources.count > 0 : false
        }

        Repeater {
            model: root.audioService ? root.audioService.sources : null
            Components.DeviceListItem {
                width: volCol.width
                icon: Root.Theme.iconHeadphone
                label: model.devDesc
                isActive: model.devActive
                showActiveBackground: true
                onClicked: { if (root.audioService) root.audioService.setSource(model.devName); }
            }
        }
    }
}
