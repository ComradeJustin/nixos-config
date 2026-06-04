import QtQuick
import ".." as Root

// Hover-state icon button. Built on ClickableItem.
//
// Usage:
//   IconButton { icon: Icons.power; onClicked: powerMenu.toggle() }
//   IconButton { icon: Icons.power; tooltipText: "Power menu"; onClicked: ... }
ClickableItem {
    id: root

    property string icon: ""
    property color iconColor: Root.Theme.textDimmed
    property int size: 28
    property string tooltipText: ""

    width: size
    height: size
    pressScale: true

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.hovered ? root.iconColor : Root.Theme.textDimmed
        font: Root.Theme.fontIcon
    }

    Tooltip {
        id: tip
        text: root.tooltipText
        anchors.bottom: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Root.Theme.spacingXS
    }

    onHoveredChanged: {
        if (root.tooltipText) {
            if (root.hovered)
                tip.show();
            else
                tip.hide();
        }
    }
}
