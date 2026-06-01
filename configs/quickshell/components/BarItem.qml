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
    // Service health: set true when the backing service is degraded
    // (e.g. API unreachable, daemon not running). Shows a tiny amber dot.
    property bool degraded: false

    // Set to a HoverPopup Item for hover popup support
    property Item popupContent: null

    // Expose hover state
    readonly property bool hovered: hoverArea.containsMouse

    readonly property font iconFont: Qt.font({
        family: Root.Theme.fontMono,
        pixelSize: Root.Theme.iconSize
    })
    readonly property font valueFont: Qt.font({
        family: Root.Theme.fontMono,
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
        spacing: Root.Theme.spacingXS
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

    // Health warning dot — tiny amber circle at top-right corner
    Rectangle {
        id: healthDot
        visible: root.degraded
        width: 5; height: 5; radius: 2.5
        color: Root.Theme.accentWarning
        anchors { top: parent.top; right: parent.right; topMargin: -1; rightMargin: 0 }

        SequentialAnimation {
            running: root.degraded
            loops: Animation.Infinite
            NumberAnimation { target: healthDot; property: "opacity"; from: 0.9; to: 0.4; duration: 1200; easing.type: Easing.InOutSine }
            NumberAnimation { target: healthDot; property: "opacity"; from: 0.4; to: 0.9; duration: 1200; easing.type: Easing.InOutSine }
        }
    }

    // Click-to-toggle popup — TapHandler coexists with child MouseAreas
    TapHandler {
        enabled: root.popupContent !== null
        onTapped: {
            let bp = Core.ServiceManager.barPopup;
            if (bp) bp.toggle(root, root.popupContent);
        }
    }

    // Hover = tooltip only (does not intercept clicks)
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: 998

        onContainsMouseChanged: {
            let bt = Core.ServiceManager.barTooltip;
            if (containsMouse) {
                if (root.tooltipText.length > 0 && bt) bt.show(root, root.tooltipText);
            } else {
                if (bt) bt.hide();
            }
        }
    }
}
