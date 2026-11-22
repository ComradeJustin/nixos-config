import QtQuick

// The panel that opens from the status cluster: clock, quick toggles, volume
// and brightness, the playing track, and recent notifications.
// Everything in it is sample content; nothing here does anything yet.
Rectangle {
    id: root

    // The current time, passed in by the layout.
    property var now: new Date()

    readonly property int padding: 16
    readonly property int contentWidth: 328

    implicitWidth: contentWidth + padding * 2
    implicitHeight: content.implicitHeight + padding * 2
    radius: Theme.radiusPanel
    color: Theme.surface
    border.width: 1
    border.color: Theme.stroke

    // One quick toggle: an icon, a name and its current state.
    component Toggle: Rectangle {
        id: toggle

        property string icon
        property string label
        property string detail
        property bool on: false

        width: 160
        height: 48
        radius: Theme.radiusControl
        color: on ? Theme.accentStrong : "transparent"
        border.width: on ? 0 : 1
        border.color: Theme.stroke

        Text {
            id: toggleIcon

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            horizontalAlignment: Text.AlignHCenter
            text: toggle.icon
            color: toggle.on ? Theme.accent : Theme.textFaint
            font.family: Theme.fontMono
            font.pixelSize: 16
        }

        Column {
            anchors.left: toggleIcon.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: toggle.label
                color: toggle.on ? Theme.textStrong : Theme.textDim
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Text {
                text: toggle.detail
                color: Theme.textDim
                font.family: Theme.fontUi
                font.pixelSize: 11
            }
        }
    }

    // A level row (volume, brightness): icon, a filled track, and the number.
    component Level: Item {
        id: level

        property string icon
        property int percent

        width: root.contentWidth
        height: 24

        Text {
            id: levelIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            text: level.icon
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 15
        }

        Text {
            id: levelNumber

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            horizontalAlignment: Text.AlignRight
            text: level.percent
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: 12
        }

        Rectangle {
            id: track

            anchors.left: levelIcon.right
            anchors.leftMargin: 8
            anchors.right: levelNumber.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: 3
            color: Theme.raised

            Rectangle {
                width: track.width * level.percent / 100
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }
        }
    }

    Column {
        id: content

        x: root.padding
        y: root.padding
        width: root.contentWidth
        spacing: 14

        // --- Date, session buttons, and the clock ---
        Item {
            width: parent.width
            height: 68

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                text: Qt.formatDateTime(root.now, "dddd, d MMMM")
                color: Theme.textDim
                font.family: Theme.fontUi
                font.pixelSize: 13
            }

            Row {
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 14

                Repeater {
                    model: [Icons.gear, Icons.lock, Icons.power]

                    Text {
                        required property string modelData

                        text: modelData
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: 15
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: Qt.formatDateTime(root.now, "hh:mm")
                color: Theme.textStrong
                font.family: Theme.fontDisplay
                font.pixelSize: 44
            }
        }

        // --- Quick toggles ---
        Grid {
            columns: 2
            spacing: 8

            Toggle {
                icon: Icons.wifiHi
                label: "Wi-Fi"
                detail: "Home-5G"
                on: true
            }

            Toggle {
                icon: Icons.btOff
                label: "Bluetooth"
                detail: "Off"
            }

            Toggle {
                icon: Icons.nightOn
                label: "Night light"
                detail: "Until 07:00"
                on: true
            }

            Toggle {
                icon: Icons.dnd
                label: "Do not disturb"
                detail: "Off"
            }

            Toggle {
                icon: Icons.caffeine
                label: "Keep awake"
                detail: "Off"
            }

            Toggle {
                icon: Icons.vpnOn
                label: "Exit node"
                detail: "nixpc"
                on: true
            }
        }

        // --- Volume and brightness ---
        Column {
            spacing: 8

            Level {
                icon: Icons.volMid
                percent: 35
            }

            Level {
                icon: Icons.briMid
                percent: 60
            }
        }

        // --- Playing track ---
        Rectangle {
            width: parent.width
            height: 60
            radius: Theme.radiusControl
            color: Theme.raised

            Rectangle {
                id: cover

                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 6
                color: Theme.stroke

                Text {
                    anchors.centerIn: parent
                    text: Icons.music
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: 16
                }
            }

            Column {
                anchors.left: cover.right
                anchors.leftMargin: 12
                anchors.right: transport.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: "Shelter"
                    color: Theme.textStrong
                    elide: Text.ElideRight
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    text: "Porter Robinson & Madeon"
                    color: Theme.textDim
                    elide: Text.ElideRight
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                }
            }

            Row {
                id: transport

                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Repeater {
                    model: [Icons.skipBack, Icons.play, Icons.skipFwd]

                    Text {
                        required property string modelData

                        text: modelData
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 16
                    }
                }
            }
        }

        // --- Notifications ---
        Item {
            width: parent.width
            height: 16

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: Theme.textDim
                font.family: Theme.fontUi
                font.pixelSize: 12
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Clear"
                color: Theme.accent
                font.family: Theme.fontUi
                font.pixelSize: 12
            }
        }

        Column {
            spacing: 8

            NotificationCard {
                width: root.contentWidth
            }

            NotificationCard {
                width: root.contentWidth
                app: "nh"
                time: "12 min ago"
                title: "Rebuild finished"
                body: "nixlaptop switched to generation 288"
            }
        }
    }
}
