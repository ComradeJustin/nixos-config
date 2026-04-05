import QtQuick
import ".." as Root
import "../core" as Core

// Bar module template — two modes:
// Simple:   BarItem { icon: "󰖙"; value: "72°F"; accent: Theme.domainWeather }
// Custom:   BarItem { custom: true; Text { ... }; Text { ... } }
// Popup:    BarItem { popupContent: myHoverPopup }  — hover shows via shared BarPopup window
Item {
    id: root

    property string icon: ""
    property string value: ""
    property color accent: Root.Theme.textDimmed
    property bool critical: false
    property color criticalColor: Root.Theme.accentDanger
    property bool custom: false
    property string tooltipText: ""

    // Set to a HoverPopup Item for hover popup support
    property Item popupContent: null

    // Expose hover state
    readonly property bool hovered: hoverArea.containsMouse

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

    implicitWidth: row.implicitWidth + 8
    implicitHeight: row.implicitHeight

    // Hover glow background
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Root.Theme.radiusSmall
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, hoverArea.containsMouse ? 0.12 : 0)
        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
    }

    Row {
        id: row
        spacing: 4
        anchors.centerIn: parent

        // Simple mode children (hidden when custom: true)
        Text {
            visible: !root.custom && root.icon !== ""
            text: root.icon
            color: root.critical ? root.criticalColor : root.accent
            font: root.iconFont
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
        }

        Text {
            visible: !root.custom && root.value !== ""
            text: root.value
            color: root.critical ? root.criticalColor : Root.Theme.textPrimary
            font: root.valueFont
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
        }
    }

    // Hover area on top for reliable hover detection
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: 998

        onContainsMouseChanged: {
            if (containsMouse) {
                if (root.tooltipText.length > 0) barTooltip.show();
                if (root.popupContent) {
                    let bp = Core.ServiceManager.barPopup;
                    if (bp) bp.show(root, root.popupContent);
                }
            } else {
                barTooltip.hide();
                if (root.popupContent) {
                    let bp = Core.ServiceManager.barPopup;
                    if (bp) bp.hide();
                }
            }
        }
    }

    Tooltip {
        id: barTooltip
        text: root.tooltipText
        x: (root.width - width) / 2
        y: root.height + 6
    }
}
