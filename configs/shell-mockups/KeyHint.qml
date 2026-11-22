import QtQuick

// One key hint: the key in a box, then what it does.
Row {
    id: hint

    property string keys
    property string action

    spacing: 8

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: keyLabel.implicitWidth + 12
        height: 18
        color: "transparent"
        border.width: 1
        border.color: Theme.rule

        Label {
            id: keyLabel

            anchors.centerIn: parent
            text: hint.keys
            caps: true
            weight: 650
            color: Theme.ink
            font.pixelSize: 9
        }
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: hint.action
        caps: true
        color: Theme.inkDim
        font.pixelSize: 9
    }
}
