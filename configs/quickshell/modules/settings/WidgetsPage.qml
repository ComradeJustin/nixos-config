import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

// Widgets page — desktop widget toggles, edit layout action, per-widget
// appearance knobs (clock, weather, system, now-playing).
Column {
    width: parent ? parent.width : 0
    spacing: Root.Theme.spacingL

    Components.SettingSection {
        title: "DESKTOP WIDGETS"
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

        Components.SettingToggle {
            label: "Glass background"
            isOn: Root.Config.widgets.glass
            onToggled: {
                Root.Config.widgets.glass = !Root.Config.widgets.glass
                Root.Config.save()
            }
        }

        Item { width: 1; height: 4 }

        // Edit widget layout button
        Rectangle {
            width: parent.width
            height: 32
            radius: Root.Theme.radiusSmall
            color: widgetEditMouse.containsMouse
                ? Qt.rgba(Root.Theme.domainSettings.r, Root.Theme.domainSettings.g, Root.Theme.domainSettings.b, 0.15)
                : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.08)

            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: Root.Icons.widgets
                    color: widgetEditMouse.containsMouse ? Root.Theme.domainSettings : Root.Theme.textDimmed
                    font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize }
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                }
                Text {
                    text: "Edit Widget Layout"
                    color: widgetEditMouse.containsMouse ? Root.Theme.domainSettings : Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                }
            }

            MouseArea {
                id: widgetEditMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    let sw = Core.ServiceManager.settingsWindow; if (sw) sw.toggle()
                    let wo = Core.ServiceManager.widgetOverlay; if (wo) wo.toggleEditMode()
                }
            }
        }
    }

    Components.SettingSection {
        title: "CLOCK"
        width: parent.width
        resetCallback: () => Root.Config.resetSection("clock")

        Components.SettingSlider {
            label: "Font size"
            value: Root.Config.clockConfig.fontSize
            minValue: 12; maxValue: 72; suffix: "px"
            onSliderUpdated: newValue => {
                Root.Config.clockConfig.fontSize = Math.round(newValue)
                Root.Config.save()
            }
        }
        Components.SettingToggle {
            label: "Show seconds"
            isOn: Root.Config.clockConfig.showSeconds
            onToggled: {
                Root.Config.clockConfig.showSeconds = !Root.Config.clockConfig.showSeconds
                Root.Config.save()
            }
        }
        Components.SettingToggle {
            label: "Show date"
            isOn: Root.Config.clockConfig.showDate
            onToggled: {
                Root.Config.clockConfig.showDate = !Root.Config.clockConfig.showDate
                Root.Config.save()
            }
        }
    }

    Components.SettingSection {
        title: "WEATHER"
        width: parent.width
        resetCallback: () => Root.Config.resetSection("weather")

        Components.SettingToggle {
            label: "Use metric units"
            isOn: Root.Config.weatherConfig.useMetric
            onToggled: {
                Root.Config.weatherConfig.useMetric = !Root.Config.weatherConfig.useMetric
                Root.Config.save()
            }
        }
        Components.SettingSlider {
            label: "Font size"
            value: Root.Config.weatherConfig.fontSize
            minValue: 12; maxValue: 48; suffix: "px"
            onSliderUpdated: newValue => {
                Root.Config.weatherConfig.fontSize = Math.round(newValue)
                Root.Config.save()
            }
        }
    }

    Components.SettingSection {
        title: "SYSTEM"
        width: parent.width
        resetCallback: () => Root.Config.resetSection("system")

        Components.SettingToggle {
            label: "Show CPU"
            isOn: Root.Config.systemConfig.showCpu
            onToggled: {
                Root.Config.systemConfig.showCpu = !Root.Config.systemConfig.showCpu
                Root.Config.save()
            }
        }
        Components.SettingToggle {
            label: "Show RAM"
            isOn: Root.Config.systemConfig.showRam
            onToggled: {
                Root.Config.systemConfig.showRam = !Root.Config.systemConfig.showRam
                Root.Config.save()
            }
        }
        Components.SettingSlider {
            label: "Font size"
            value: Root.Config.systemConfig.fontSize
            minValue: 12; maxValue: 48; suffix: "px"
            onSliderUpdated: newValue => {
                Root.Config.systemConfig.fontSize = Math.round(newValue)
                Root.Config.save()
            }
        }
    }

    Components.SettingSection {
        title: "NOW PLAYING"
        width: parent.width
        resetCallback: () => Root.Config.resetSection("nowPlaying")

        Components.SettingToggle {
            label: "Show album art"
            isOn: Root.Config.nowPlayingConfig.showArt
            onToggled: {
                Root.Config.nowPlayingConfig.showArt = !Root.Config.nowPlayingConfig.showArt
                Root.Config.save()
            }
        }
        Components.SettingSlider {
            label: "Art size"
            value: Root.Config.nowPlayingConfig.artSize
            minValue: 40; maxValue: 160; suffix: "px"
            onSliderUpdated: newValue => {
                Root.Config.nowPlayingConfig.artSize = Math.round(newValue)
                Root.Config.save()
            }
        }
    }

    Item { width: 1; height: 8 }
}
