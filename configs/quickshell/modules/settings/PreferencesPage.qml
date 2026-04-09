import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

// Preferences page — feature toggles, auto-hide behavior, timing knobs.
Column {
    width: parent ? parent.width : 0
    spacing: 16

    Components.SettingSection {
        title: "FEATURES"
        width: parent.width
        resetCallback: () => Root.Config.resetSection("features")

        Components.SettingToggle {
            label: "Media popup"
            description: "Floating media controls overlay"
            isOn: Root.Config.features.mediaPopup
            onToggled: {
                Root.Config.features.mediaPopup = !Root.Config.features.mediaPopup
                Root.Config.save()
            }
        }
        Components.SettingToggle {
            label: "Clipboard history"
            description: "Track and browse clipboard entries"
            isOn: Root.Config.features.clipboardHistory
            onToggled: {
                Root.Config.features.clipboardHistory = !Root.Config.features.clipboardHistory
                Root.Config.save()
            }
        }
        Components.SettingToggle {
            label: "Wallpaper selector"
            description: "Enable wallpaper picker in Spotlight"
            isOn: Root.Config.features.wallpaperSelector
            onToggled: {
                Root.Config.features.wallpaperSelector = !Root.Config.features.wallpaperSelector
                Root.Config.save()
            }
        }
        Components.SettingToggle {
            label: "Wallpaper widgets"
            description: "Render widgets directly on the wallpaper layer"
            isOn: Root.Config.features.wallpaperWidgets
            onToggled: {
                Root.Config.features.wallpaperWidgets = !Root.Config.features.wallpaperWidgets
                Root.Config.save()
            }
        }
    }

    Components.SettingSection {
        title: "BEHAVIOR"
        width: parent.width
        resetCallback: () => Root.Config.resetSection("features")

        Components.SettingToggle {
            label: "Auto-hide widgets"
            description: "Hide desktop widgets when windows are present"
            isOn: Root.Config.features.autoHideWidgets
            onToggled: {
                Root.Config.features.autoHideWidgets = !Root.Config.features.autoHideWidgets
                Root.Config.save()
            }
        }
        Components.SettingToggle {
            label: "Auto-hide bar in fullscreen"
            description: "Hide the bar when a window goes fullscreen"
            isOn: Root.Config.features.autoHideBarInFullscreen
            onToggled: {
                Root.Config.features.autoHideBarInFullscreen = !Root.Config.features.autoHideBarInFullscreen
                Root.Config.save()
            }
        }
    }

    Components.SettingSection {
        title: "TIMING"
        width: parent.width
        resetCallback: () => Root.Config.resetSection("behavior")

        Components.SettingSlider {
            label: "Weather update"
            value: Math.round(Root.Config.behavior.weatherUpdateInterval / 60000)
            minValue: 1; maxValue: 30; suffix: " min"
            onSliderUpdated: newValue => {
                Root.Config.behavior.weatherUpdateInterval = Math.round(newValue) * 60000
                Root.Config.save()
            }
        }
        Components.SettingSlider {
            label: "System stats"
            value: Math.round(Root.Config.behavior.systemStatsInterval / 1000)
            minValue: 1; maxValue: 10; suffix: " sec"
            onSliderUpdated: newValue => {
                Root.Config.behavior.systemStatsInterval = Math.round(newValue) * 1000
                Root.Config.save()
            }
        }
        Components.SettingSlider {
            label: "Notification timeout"
            value: Math.round(Root.Config.behavior.notificationTimeout / 1000)
            minValue: 1; maxValue: 15; suffix: " sec"
            onSliderUpdated: newValue => {
                Root.Config.behavior.notificationTimeout = Math.round(newValue) * 1000
                Root.Config.save()
            }
        }
        Components.SettingSlider {
            label: "Max clipboard items"
            value: Root.Config.behavior.maxClipboardItems
            minValue: 10; maxValue: 100
            onSliderUpdated: newValue => {
                Root.Config.behavior.maxClipboardItems = Math.round(newValue)
                Root.Config.save()
            }
        }
    }

    Item { width: 1; height: 8 }
}
