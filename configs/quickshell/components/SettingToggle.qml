import QtQuick
import ".." as Root

Item {
    id: root

    property string label: ""
    property string description: ""
    property bool isOn: false
    property color accent: Root.Theme.accentPrimary

    signal toggled()

    width: parent ? parent.width : 200
    height: 36

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    // Label column
    Column {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter; right: pill.left; rightMargin: 8 }
        spacing: 2

        Text {
            text: root.label
            color: Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
            width: parent.width
            elide: Text.ElideRight
        }

        Text {
            visible: root.description !== ""
            text: root.description
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
            width: parent.width
            elide: Text.ElideRight
        }
    }

    // Toggle pill
    Rectangle {
        id: pill
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 36
        height: 20
        radius: 10
        color: root.isOn ? root.accent : Root.Theme.textDimmed
        opacity: root.isOn ? 1.0 : 0.3

        Behavior on color { ColorAnimation { duration: Root.Theme.animFast } }

        Rectangle {
            width: 14
            height: 14
            radius: 7
            color: Root.Theme.textPrimary
            anchors.verticalCenter: parent.verticalCenter
            x: root.isOn ? pill.width - width - 3 : 3

            Behavior on x { NumberAnimation { duration: Root.Theme.animFast; easing.type: Easing.InOutCubic } }
        }
    }
}
