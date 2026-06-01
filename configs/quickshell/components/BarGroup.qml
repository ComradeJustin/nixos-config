import QtQuick
import QtQuick.Layouts
import ".." as Root

// Visual grouping container for bar modules.
// Creates a rounded card background around a set of modules.
// Based on end-4's BarGroup pattern for visual hierarchy.
//
// Usage:
//   BarGroup {
//       ResourceModule {}
//       MediaModule {}
//   }
Item {
    id: group

    property real padding: 5
    property bool showBackground: true
    default property alias items: layout.children

    implicitWidth: layout.implicitWidth + padding * 2
    implicitHeight: Root.Theme.barHeight

    Rectangle {
        anchors {
            fill: parent
            topMargin: Root.Theme.spacingXS
            bottomMargin: Root.Theme.spacingXS
        }
        color: showBackground ? Root.Theme.layer1 : "transparent"
        radius: Root.Theme.radiusSmall
        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
    }

    RowLayout {
        id: layout
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            right: parent.right
            margins: group.padding
        }
        spacing: Root.Theme.spacingXS
    }
}
