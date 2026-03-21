import QtQuick
import "../.." as Root

Item {
    id: root
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    // Theme is now a singleton - access via Root.Theme.propertyName

    property bool isOpen: false
    signal clicked()

    Text {
        id: icon
        text: Root.Theme.iconGear
        color: root.isOpen ? Root.Theme.domainSettings : Root.Theme.textDimmed
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
        anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
