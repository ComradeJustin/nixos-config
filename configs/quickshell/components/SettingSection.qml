import QtQuick
import ".." as Root

Item {
    id: root

    property string title: ""
    property bool collapsible: false
    property bool collapsed: false
    // Optional reset hook. Set this to a function and a small "Reset" link
    // appears next to the title (e.g. `resetCallback: () => Config.resetSection("bar")`).
    property var resetCallback: null

    default property alias content: contentCol.data

    width: parent ? parent.width : 200
    height: header.height + (collapsed ? 0 : contentCol.height + 8)
    clip: true

    Behavior on height { NumberAnimation { duration: Root.Theme.anim.exitDuration; easing.type: Easing.InOutCubic } }

    // Header
    Item {
        id: header
        width: parent.width
        height: 28

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: root.title
            color: Root.Theme.textDimmed
            font {
                family: Root.Theme.fontFamily
                pixelSize: Root.Theme.fontSizeSmall
                bold: true
                letterSpacing: 1.5
            }
        }

        Text {
            visible: root.collapsible
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: root.collapsed ? "+" : "-"
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
        }

        // Reset link (only shown when a reset callback is provided)
        Text {
            id: resetLabel
            visible: root.resetCallback !== null
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: "Reset"
            color: resetMouse.containsMouse ? Root.Theme.accentPrimary : Root.Theme.textDimmed
            font {
                family: Root.Theme.fontFamily
                pixelSize: Root.Theme.fontSizeSmall
                letterSpacing: 1
            }
            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

            MouseArea {
                id: resetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (root.resetCallback) root.resetCallback(); }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.collapsible
            cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.collapsed = !root.collapsed
        }
    }

    // Separator
    Rectangle {
        anchors { top: header.bottom; left: parent.left; right: parent.right }
        height: 1
        color: Root.Theme.textDimmed
        opacity: 0.15
    }

    // Content
    Column {
        id: contentCol
        anchors { top: header.bottom; topMargin: 8; left: parent.left; right: parent.right }
        spacing: 4
        visible: !root.collapsed
    }
}
