import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.." as Root
import "../../components" as Components

// Volume/Audio tab content for ControlCenter
Components.SmoothFlickable {
    id: root

    property var audioService: null

    contentHeight: volCol.implicitHeight
    clip: true

    Column {
        id: volCol
        width: parent.width
        spacing: Root.Theme.spacingS

        Item { width: 1; height: 2 }

        // ── Per-App Audio Mixer ──
        Text {
            text: "App Mixer"
            color: Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM; bold: true }
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
                                // Use Quickshell.iconPath for proper icon theme support
                                if (model.appIcon && model.appIcon !== "")
                                    return Quickshell.iconPath(model.appIcon, true);
                                if (model.appName && model.appName !== "")
                                    return Quickshell.iconPath(model.appName.toLowerCase(), true);
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
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS; bold: true }
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
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM }
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Row {
                            width: parent.width
                            spacing: Root.Theme.spacingS

                            Components.SliderBar {
                                id: appSlider
                                width: parent.width - 44
                                height: 14
                                handleSize: 10
                                accentColor: Root.Theme.domainMedia
                                onValueUpdated: function(newValue) {
                                    if (root.audioService) root.audioService.setAppVolume(model.appIdx, Math.round(newValue));
                                }
                                Binding {
                                    target: appSlider
                                    property: "value"
                                    value: model.appVol || 0
                                    when: !appSlider.dragging
                                }
                            }

                            Text {
                                text: (model.appVol || 0) + "%"
                                color: Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
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
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM; bold: true }
            leftPadding: 4
            visible: root.audioService ? root.audioService.sinks.count > 0 : false
        }

        Repeater {
            model: root.audioService ? root.audioService.sinks : null
            Components.DeviceListItem {
                width: volCol.width
                icon: Root.Icons.speaker
                label: model.devDesc
                isActive: model.devActive
                showActiveBackground: true
                accentColor: Root.Theme.domainMedia
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
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM; bold: true }
            leftPadding: 4
            visible: root.audioService ? root.audioService.sources.count > 0 : false
        }

        Repeater {
            model: root.audioService ? root.audioService.sources : null
            Components.DeviceListItem {
                width: volCol.width
                icon: Root.Icons.headphone
                label: model.devDesc
                isActive: model.devActive
                showActiveBackground: true
                accentColor: Root.Theme.domainMedia
                onClicked: { if (root.audioService) root.audioService.setSource(model.devName); }
            }
        }
    }
}
