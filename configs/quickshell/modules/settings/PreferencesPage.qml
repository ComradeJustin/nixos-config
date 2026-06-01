import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

// Preferences page — feature toggles, auto-hide behavior, timing knobs.
Column {
    width: parent ? parent.width : 0
    spacing: Root.Theme.spacingL

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

    // ── CC Cards — toggle and reorder ──
    Components.SettingSection {
        title: "CONTROL CENTER CARDS"
        width: parent.width

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: Root.Config.cc.cardLayout

                Item {
                    id: ccCardItem
                    required property var modelData
                    required property int index
                    width: parent ? parent.width : 200
                    height: 40

                    property var _meta: {
                        let cards = Core.Registry.ccCards;
                        for (let i = 0; i < cards.length; i++)
                            if (cards[i].key === modelData) return cards[i];
                        return { label: modelData, icon: "" };
                    }
                    property bool _enabled: Root.Config.cc.cards[modelData] || false

                    Rectangle {
                        anchors.fill: parent
                        radius: Root.Theme.radiusSmall
                        color: ccCardMouse.containsMouse
                            ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.04)
                            : "transparent"
                    }

                    Row {
                        anchors {
                            left: parent.left; leftMargin: Root.Theme.spacingXS
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: Root.Theme.spacingS

                        // Reorder arrows
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Text {
                                text: "▲"
                                color: ccUpMouse.containsMouse ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: 8 }
                                opacity: ccCardItem.index > 0 ? 1 : 0.2
                                MouseArea {
                                    id: ccUpMouse
                                    anchors.fill: parent; anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: ccCardItem.index > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: if (ccCardItem.index > 0) Root.Config.moveCcCard(ccCardItem.modelData, -1)
                                }
                            }
                            Text {
                                text: "▼"
                                color: ccDownMouse.containsMouse ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: 8 }
                                opacity: ccCardItem.index < Root.Config.cc.cardLayout.length - 1 ? 1 : 0.2
                                MouseArea {
                                    id: ccDownMouse
                                    anchors.fill: parent; anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: ccCardItem.index < Root.Config.cc.cardLayout.length - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: if (ccCardItem.index < Root.Config.cc.cardLayout.length - 1) Root.Config.moveCcCard(ccCardItem.modelData, 1)
                                }
                            }
                        }

                        // Card icon
                        Text {
                            text: ccCardItem._meta.icon
                            color: ccCardItem._enabled ? Root.Theme.textPrimary : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize2XL }
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Card label
                        Text {
                            text: ccCardItem._meta.label
                            color: ccCardItem._enabled ? Root.Theme.textPrimary : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Toggle pill
                    Rectangle {
                        anchors { right: parent.right; rightMargin: Root.Theme.spacingXS; verticalCenter: parent.verticalCenter }
                        width: 36; height: 20; radius: 10
                        color: ccCardItem._enabled ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                        opacity: ccCardItem._enabled ? 1.0 : 0.3
                        Behavior on color { ColorAnimation { duration: Root.Theme.animFast } }

                        Rectangle {
                            width: 14; height: 14; radius: 7
                            color: Root.Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                            x: ccCardItem._enabled ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: Root.Theme.animFast; easing.type: Easing.InOutCubic } }
                        }
                    }

                    MouseArea {
                        id: ccCardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Root.Config.toggleCcCard(ccCardItem.modelData)
                    }
                }
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
