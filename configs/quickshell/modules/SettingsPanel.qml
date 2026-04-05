import Quickshell
import Quickshell.Wayland
import QtQuick
import Qt5Compat.GraphicalEffects
import ".." as Root
import "../components" as Components
import "../core" as Core

Scope {
    id: sp

    property bool showing: false
    property var barRef: null

    function toggle() {
        showing = !showing;
        if (showing) spPanel.visible = true;
    }

    PanelWindow {
        id: spPanel
        visible: false
        anchors { top: true; left: true; bottom: true }
        margins.top: Root.Theme.barHeight + 6
        margins.bottom: 6
        margins.left: 6
        implicitWidth: 320
        WlrLayershell.namespace: "quickshell-settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                id: spRect
                width: 320
                height: parent.height
                radius: Root.Theme.radiusMedium
                color: Root.Theme.barBackground
                x: sp.showing ? 0 : -320
                Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }
                onXChanged: { if (!sp.showing && x <= -319) spPanel.visible = false; }

                layer.enabled: sp.showing
                layer.effect: DropShadow {
                    transparentBorder: true
                    color: Qt.rgba(0, 0, 0, 0.45)
                    radius: 20; samples: 41; horizontalOffset: 4
                }

                Components.SmoothFlickable {
                    anchors { fill: parent; margins: Root.Theme.ccPadding }
                    contentHeight: contentCol.height
                    clip: true

                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: 16

                        // ── Header ──
                        Item {
                            width: parent.width; height: 28

                            Text {
                                text: "Settings"
                                color: Root.Theme.textPrimary
                                font { family: Root.Theme.fontFamily; pixelSize: 12; bold: true; letterSpacing: 2 }
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            }

                            Components.IconButton {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                icon: Root.Icons.cancel
                                iconColor: Root.Theme.textDimmed
                                onClicked: sp.showing = false
                            }
                        }

                        // ── Bar Modules ──
                        Components.SettingSection {
                            title: "BAR MODULES"
                            width: parent.width

                            Repeater {
                                model: Core.Registry.barModules
                                Components.SettingToggle {
                                    required property var modelData
                                    label: modelData.label
                                    isOn: Root.Config.isBarModuleEnabled(modelData.key)
                                    onToggled: Root.Config.toggleBarModule(modelData.key, modelData.section)
                                }
                            }

                            Item { width: 1; height: 4 }

                            Rectangle {
                                width: parent.width; height: 28
                                radius: Root.Theme.radiusSmall
                                color: reorderMouse.containsMouse ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.15) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: Root.Icons.drag + "  Reorder Bar"
                                    color: reorderMouse.containsMouse ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                                }
                                MouseArea {
                                    id: reorderMouse
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { sp.showing = false; if (sp.barRef) sp.barRef.toggleBarEdit(); }
                                }
                            }
                        }

                        // ── Widgets ──
                        Components.SettingSection {
                            title: "WIDGETS"
                            width: parent.width

                            Repeater {
                                model: Core.Registry.widgets
                                Components.SettingToggle {
                                    required property var modelData
                                    label: modelData.label
                                    isOn: Root.Config.widgets[modelData.configKey] || false
                                    onToggled: Root.Config.toggleWidget(modelData.configKey)
                                }
                            }
                        }

                        // ── Clock ──
                        Components.SettingSection {
                            title: "CLOCK"
                            width: parent.width

                            Components.SettingSlider {
                                label: "Font size"
                                value: Root.Config.clockConfig.fontSize
                                minValue: 12; maxValue: 72; suffix: "px"
                                onSliderUpdated: newValue => { Root.Config.clockConfig.fontSize = Math.round(newValue); Root.Config.save(); }
                            }
                            Components.SettingToggle {
                                label: "Show seconds"
                                isOn: Root.Config.clockConfig.showSeconds
                                onToggled: { Root.Config.clockConfig.showSeconds = !Root.Config.clockConfig.showSeconds; Root.Config.save(); }
                            }
                            Components.SettingToggle {
                                label: "Show date"
                                isOn: Root.Config.clockConfig.showDate
                                onToggled: { Root.Config.clockConfig.showDate = !Root.Config.clockConfig.showDate; Root.Config.save(); }
                            }
                        }

                        // ── Weather ──
                        Components.SettingSection {
                            title: "WEATHER"
                            width: parent.width

                            Components.SettingToggle {
                                label: "Use metric"
                                isOn: Root.Config.weatherConfig.useMetric
                                onToggled: { Root.Config.weatherConfig.useMetric = !Root.Config.weatherConfig.useMetric; Root.Config.save(); }
                            }
                            Components.SettingSlider {
                                label: "Font size"
                                value: Root.Config.weatherConfig.fontSize
                                minValue: 12; maxValue: 48; suffix: "px"
                                onSliderUpdated: newValue => { Root.Config.weatherConfig.fontSize = Math.round(newValue); Root.Config.save(); }
                            }
                        }

                        // ── System ──
                        Components.SettingSection {
                            title: "SYSTEM"
                            width: parent.width

                            Components.SettingToggle {
                                label: "Show CPU"
                                isOn: Root.Config.systemConfig.showCpu
                                onToggled: { Root.Config.systemConfig.showCpu = !Root.Config.systemConfig.showCpu; Root.Config.save(); }
                            }
                            Components.SettingToggle {
                                label: "Show RAM"
                                isOn: Root.Config.systemConfig.showRam
                                onToggled: { Root.Config.systemConfig.showRam = !Root.Config.systemConfig.showRam; Root.Config.save(); }
                            }
                            Components.SettingSlider {
                                label: "Font size"
                                value: Root.Config.systemConfig.fontSize
                                minValue: 12; maxValue: 48; suffix: "px"
                                onSliderUpdated: newValue => { Root.Config.systemConfig.fontSize = Math.round(newValue); Root.Config.save(); }
                            }
                        }

                        // ── Now Playing ──
                        Components.SettingSection {
                            title: "NOW PLAYING"
                            width: parent.width

                            Components.SettingToggle {
                                label: "Show album art"
                                isOn: Root.Config.nowPlayingConfig.showArt
                                onToggled: { Root.Config.nowPlayingConfig.showArt = !Root.Config.nowPlayingConfig.showArt; Root.Config.save(); }
                            }
                            Components.SettingSlider {
                                label: "Art size"
                                value: Root.Config.nowPlayingConfig.artSize
                                minValue: 40; maxValue: 160; suffix: "px"
                                onSliderUpdated: newValue => { Root.Config.nowPlayingConfig.artSize = Math.round(newValue); Root.Config.save(); }
                            }
                        }

                        // ── Features ──
                        Components.SettingSection {
                            title: "FEATURES"
                            width: parent.width

                            Components.SettingToggle {
                                label: "Wallpaper widgets"
                                isOn: Root.Config.features.wallpaperWidgets
                                onToggled: { Root.Config.features.wallpaperWidgets = !Root.Config.features.wallpaperWidgets; Root.Config.save(); }
                            }
                            Components.SettingToggle {
                                label: "Auto-hide widgets"
                                isOn: Root.Config.features.autoHideWidgets
                                onToggled: { Root.Config.features.autoHideWidgets = !Root.Config.features.autoHideWidgets; Root.Config.save(); }
                            }
                            Components.SettingToggle {
                                label: "Auto-hide bar in fullscreen"
                                isOn: Root.Config.features.autoHideBarInFullscreen
                                onToggled: { Root.Config.features.autoHideBarInFullscreen = !Root.Config.features.autoHideBarInFullscreen; Root.Config.save(); }
                            }
                            Components.SettingToggle {
                                label: "Media popup"
                                isOn: Root.Config.features.mediaPopup
                                onToggled: { Root.Config.features.mediaPopup = !Root.Config.features.mediaPopup; Root.Config.save(); }
                            }
                            Components.SettingToggle {
                                label: "Clipboard history"
                                isOn: Root.Config.features.clipboardHistory
                                onToggled: { Root.Config.features.clipboardHistory = !Root.Config.features.clipboardHistory; Root.Config.save(); }
                            }
                        }

                        // Bottom padding
                        Item { width: 1; height: 8 }
                    }
                }
            }
        }
    }
}
