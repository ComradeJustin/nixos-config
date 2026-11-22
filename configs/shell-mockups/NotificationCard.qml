import QtQuick

// One notification: app, time, title and body. Used inside the status panel
// and, on its own, as a toast.
Rectangle {
    id: root

    property string app: "Vesktop"
    property string time: "now"
    property string title: "Mara"
    property string body: "are you still coming tonight?"
    // A toast floats on its own, so it needs the panel surface and a border.
    property bool floating: false

    implicitWidth: 328
    implicitHeight: 64
    radius: floating ? Theme.radiusPanel : Theme.radiusControl
    color: floating ? Theme.surface : Theme.raised
    border.width: floating ? 1 : 0
    border.color: Theme.stroke

    Rectangle {
        id: appIcon

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: 8
        color: Theme.accentSoft

        Text {
            anchors.centerIn: parent
            text: Icons.bell
            color: Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: 16
        }
    }

    Column {
        anchors.left: appIcon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            text: root.app + "  ·  " + root.time
            color: Theme.textDim
            font.family: Theme.fontUi
            font.pixelSize: 11
        }

        Text {
            width: parent.width
            text: root.title
            color: Theme.textStrong
            elide: Text.ElideRight
            font.family: Theme.fontUi
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: root.body
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.fontUi
            font.pixelSize: 12
        }
    }
}
