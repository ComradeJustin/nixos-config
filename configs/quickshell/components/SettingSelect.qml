import QtQuick
import ".." as Root

// A segmented single-choice control for settings: a label + optional description
// with a row of selectable pills beneath. Emits `selected(value)` on a tap; the
// host owns persistence (set `value` from config, save in the handler).
//
// Usage:
//   SettingSelect {
//       label: "Notification stacking"
//       options: [ { value: "hover", text: "Hover" }, { value: "stack", text: "Stacked" } ]
//       value: Config.behavior.notifStackStyle
//       onSelected: v => { Config.behavior.notifStackStyle = v; Config.save(); }
//   }
Item {
    id: root

    property string label: ""
    property string description: ""
    property var options: []        // [{ value: "x", text: "X" }, ...]
    property string value: ""

    signal selected(string value)

    width: parent ? parent.width : 200
    implicitHeight: col.implicitHeight
    height: implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Root.Theme.spacingXS

        Text {
            visible: root.label !== ""
            text: root.label
            color: Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
        }

        Text {
            visible: root.description !== ""
            text: root.description
            color: Root.Theme.textDimmed
            width: parent.width
            wrapMode: Text.WordWrap
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
        }

        // Segmented pills
        Flow {
            width: parent.width
            spacing: Root.Theme.spacingXS

            Repeater {
                model: root.options

                Rectangle {
                    required property var modelData
                    readonly property bool active: root.value === modelData.value

                    height: 26
                    width: pillText.implicitWidth + 22
                    radius: Root.Theme.radiusSmall
                    color: active
                         ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.18)
                         : pillMouse.containsMouse
                            ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06)
                            : Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.03)
                    border.width: 1
                    border.color: active
                        ? Root.Theme.accentPrimary
                        : Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.08)

                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                    Behavior on border.color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                    Text {
                        id: pillText
                        anchors.centerIn: parent
                        text: modelData.text
                        color: active ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
                    }

                    MouseArea {
                        id: pillMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected(modelData.value)
                    }
                }
            }
        }
    }
}
