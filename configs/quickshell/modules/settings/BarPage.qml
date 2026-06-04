import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

// Bar page — module toggles, reorder action, bar style / groups / sparkline.
// Loaded by SettingsWindow via its settings-page Loader. The root Column
// auto-fills its parent's width so the Loader can size it via `width:`.
Column {
    width: parent ? parent.width : 0
    spacing: Root.Theme.spacingL

    Components.SettingSection {
        title: "MODULES"
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

        // Spacer before reorder button
        Item { width: 1; height: 4 }

        // Reorder button
        Rectangle {
            width: parent.width
            height: 32
            radius: Root.Theme.radiusSmall
            color: reorderMouse.containsMouse
                ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.15)
                : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.08)

            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: Root.Icons.drag
                    color: reorderMouse.containsMouse ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                    font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize }
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                }
                Text {
                    text: "Reorder Bar"
                    color: reorderMouse.containsMouse ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                }
            }

            MouseArea {
                id: reorderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // Close the settings window (if any) and toggle bar edit mode.
                    let sw = Core.ServiceManager.settingsWindow; if (sw) sw.toggle()
                    let bar = Core.ServiceManager.bar; if (bar) bar.toggleBarEdit()
                }
            }
        }
    }

    Components.SettingSection {
        title: "BAR STYLE"
        width: parent.width
        resetCallback: () => Root.Config.resetSection("bar")

        Components.SettingToggle {
            label: "Floating bar"
            description: "Detach bar from screen edge with rounded corners"
            isOn: Root.Config.bar.style === "float"
            onToggled: {
                Root.Config.bar.style = Root.Config.bar.style === "float" ? "flat" : "float"
                Root.Config.save()
            }
        }

        Components.SettingToggle {
            label: "Frosted glass"
            description: "Translucent blurred backgrounds for the bar and panels"
            isOn: Root.Config.appearance.glass
            onToggled: {
                Root.Config.appearance.glass = !Root.Config.appearance.glass
                Root.Config.save()
            }
        }

        Components.SettingToggle {
            label: "Module groups"
            description: "Show card backgrounds around bar module groups"
            isOn: Root.Config.bar.showGroups
            onToggled: {
                Root.Config.bar.showGroups = !Root.Config.bar.showGroups
                Root.Config.save()
            }
        }

        Components.SettingToggle {
            label: "CPU sparkline"
            description: "Show mini graph next to CPU usage"
            isOn: Root.Config.bar.showCpuGraph
            onToggled: {
                Root.Config.bar.showCpuGraph = !Root.Config.bar.showCpuGraph
                Root.Config.save()
            }
        }

        Components.SettingToggle {
            label: "Always show caffeine"
            description: "Keep caffeine bar icon visible even when idle inhibit is off"
            isOn: Root.Config.bar.showCaffeineWhenOff
            onToggled: {
                Root.Config.bar.showCaffeineWhenOff = !Root.Config.bar.showCaffeineWhenOff
                Root.Config.save()
            }
        }
    }

    // Bottom padding
    Item { width: 1; height: 8 }
}
