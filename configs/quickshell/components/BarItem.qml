import QtQuick
import ".." as Root

// Bar module template — two modes:
// Simple:   BarItem { icon: "󰖙"; value: "72°F"; accent: Theme.domainWeather }
// Custom:   BarItem { custom: true; Text { ... }; Text { ... } }
Item {
    id: root

    property string icon: ""
    property string value: ""
    property color accent: Root.Theme.textDimmed
    property bool critical: false
    property color criticalColor: Root.Theme.accentDanger
    property bool custom: false

    readonly property font iconFont: Qt.font({
        family: Root.Theme.fontFamily,
        pixelSize: Root.Theme.iconSize
    })
    readonly property font valueFont: Qt.font({
        family: Root.Theme.fontFamily,
        pixelSize: Root.Theme.fontSize,
        bold: true
    })

    default property alias content: row.data

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        // Simple mode children (hidden when custom: true)
        Text {
            visible: !root.custom && root.icon !== ""
            text: root.icon
            color: root.critical ? root.criticalColor : root.accent
            font: root.iconFont
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: !root.custom && root.value !== ""
            text: root.value
            color: root.critical ? root.criticalColor : root.accent
            font: root.valueFont
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
