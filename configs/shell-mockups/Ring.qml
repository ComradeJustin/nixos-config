import QtQuick
import Quickshell
import Quickshell.Wayland

// The summoned layer: the rotation ring, now carrying the whole shell.
//
// Six stations sit on a ring around a hub. h and l turn the ring, and the
// station on the right is the focused one. Enter "dives": the focused
// station collapses into the hub, the others fly outward, and that station's
// controls fan out on an arc to the right. Esc backs out.
//
// Everything on screen is positioned from three animated numbers below
// (openness, angle, dive), so the motion is one continuous system.
PanelWindow {
    id: ring

    // The shell root (shell.qml), which holds the state and the sample data.
    required property var shell

    readonly property var stations: shell.stations
    readonly property int stationCount: stations.length
    readonly property real stepDegrees: 360 / stationCount
    // shell.turns counts presses and never wraps, so the ring keeps turning
    // the same way when it passes the last station.
    readonly property int focusedIndex: ((shell.turns % stationCount) + stationCount) % stationCount
    readonly property var focusedStation: stations[focusedIndex]

    // --- The three animated values ---
    // 0 = hidden, 1 = open.
    property real openness: shell.ringOpen ? 1 : 0
    // Rotation of the ring, in degrees.
    property real angle: -stepDegrees * shell.turns
    // 0 = ring view, 1 = dived into the focused station.
    property real dive: shell.dived ? 1 : 0

    Behavior on openness {
        SpringAnimation {
            spring: Theme.panelSpring
            damping: Theme.panelDamping
            epsilon: 0.002
        }
    }
    Behavior on angle {
        SpringAnimation {
            spring: Theme.ringSpring
            damping: Theme.ringDamping
            epsilon: 0.02
        }
    }
    Behavior on dive {
        SpringAnimation {
            spring: Theme.panelSpring
            damping: Theme.panelDamping
            epsilon: 0.002
        }
    }

    // --- Geometry ---
    readonly property real ringRadius: 250
    // How much further the unfocused stations fly out on dive.
    readonly property real divePush: 150
    readonly property real fanRadius: 330
    readonly property real fanStepDegrees: 9.5
    readonly property real hubDiameter: 140 + 44 * dive
    // The whole figure slides left on dive to make room for the fan.
    readonly property real centerX: width / 2 - 190 * dive
    readonly property real centerY: height / 2

    function clamp01(value: real): real {
        return Math.max(0, Math.min(1, value));
    }

    // Stay mapped while the closing spring is still settling.
    visible: shell.ringOpen || openness > 0.02
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shell.ringOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible)
            stage.forceActiveFocus();
    }

    // Dim everything behind the ring.
    Rectangle {
        anchors.fill: parent
        color: Theme.base00
        opacity: 0.78 * ring.clamp01(ring.openness)
    }

    Item {
        id: stage

        anchors.fill: parent
        focus: true
        opacity: ring.clamp01(ring.openness)

        Keys.onPressed: event => {
            const shell = ring.shell;
            const forward = event.key === Qt.Key_L || event.key === Qt.Key_Right;
            const backward = event.key === Qt.Key_H || event.key === Qt.Key_Left;
            const down = event.key === Qt.Key_J || event.key === Qt.Key_Down;
            const up = event.key === Qt.Key_K || event.key === Qt.Key_Up;
            const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space;

            if (event.key === Qt.Key_Escape)
                shell.back();
            else if (!shell.dived && forward)
                shell.rotate(1);
            else if (!shell.dived && backward)
                shell.rotate(-1);
            else if (!shell.dived && enter)
                shell.diveIn();
            else if (shell.dived && backward)
                shell.back();
            else if (shell.dived && down)
                shell.moveSelection(1);
            else if (shell.dived && up)
                shell.moveSelection(-1);
            event.accepted = true;
        }

        // Faint guide circle the stations travel on.
        Rectangle {
            width: ring.ringRadius * 2 * ring.openness
            height: width
            x: ring.centerX - width / 2
            y: ring.centerY - height / 2
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Theme.stroke
            opacity: 0.6 * (1 - ring.clamp01(ring.dive))
        }

        // --- Stations ---
        Repeater {
            model: ring.stations

            Rectangle {
                id: station

                required property var modelData
                required property int index

                readonly property bool focused: index === ring.focusedIndex
                // 0 = resting, 1 = focused. Drives weight, border and notch.
                property real emphasis: focused ? 1 : 0
                readonly property real theta: (ring.stepDegrees * index + ring.angle) * Math.PI / 180
                // The focused station falls into the hub on dive; the rest fly out.
                readonly property real distance: focused ? ring.ringRadius * ring.openness * (1 - ring.dive) : ring.ringRadius * ring.openness + ring.divePush * ring.dive

                Behavior on emphasis {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                width: 224
                height: 60
                x: ring.centerX + distance * Math.cos(theta) - width / 2
                y: ring.centerY + distance * Math.sin(theta) - height / 2
                radius: 10
                opacity: 1 - ring.clamp01(ring.dive)
                color: Theme.surface
                border.width: 1
                border.color: Qt.tint(Theme.stroke, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, emphasis))

                // Notch on the left edge that grows when focused.
                Rectangle {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 10 + 22 * station.emphasis
                    radius: 1.5
                    color: Qt.tint(Theme.stroke, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, station.emphasis))
                }

                Column {
                    x: 24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Label {
                        text: station.modelData.name
                        caps: true
                        mono: true
                        weight: 480 + 420 * station.emphasis
                        color: Qt.tint(Theme.text, Qt.rgba(Theme.textStrong.r, Theme.textStrong.g, Theme.textStrong.b, station.emphasis))
                        font.pixelSize: 14
                    }

                    Label {
                        width: 150
                        text: station.modelData.readout
                        color: Theme.textDim
                        elide: Text.ElideRight
                        font.pixelSize: 11
                    }
                }

                // Position number, engraved in the corner.
                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    text: "0" + (station.index + 1)
                    mono: true
                    color: Theme.textFaint
                    font.pixelSize: 10
                }

                Meter {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 11
                    visible: station.modelData.level >= 0
                    level: station.modelData.level
                }
            }
        }

        // --- Hub ---
        Item {
            id: hub

            readonly property int minute: ring.shell.now.getMinutes()

            width: ring.hubDiameter
            height: width
            x: ring.centerX - width / 2
            y: ring.centerY - height / 2
            scale: 0.6 + 0.4 * ring.openness

            // Battery level as an arc just outside the hub.
            Arc {
                anchors.centerIn: parent
                width: parent.width + 24
                height: width
                level: 0.28
                thickness: 3
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.surface
                border.width: 1
                border.color: Theme.stroke
            }

            // Sixty minute ticks around the rim; the current minute is lit.
            Repeater {
                model: 60

                Item {
                    id: tick

                    required property int index

                    readonly property bool major: index % 5 === 0

                    anchors.fill: parent
                    rotation: index * 6

                    Rectangle {
                        x: parent.width / 2 - width / 2
                        y: 6
                        width: tick.index === hub.minute ? 2 : 1
                        height: tick.index === hub.minute ? 10 : (tick.major ? 7 : 3)
                        color: tick.index === hub.minute ? Theme.accent : (tick.major ? Theme.textDim : Theme.textFaint)
                    }
                }
            }

            // Resting face: the time.
            Column {
                anchors.centerIn: parent
                opacity: 1 - ring.clamp01(ring.dive)
                spacing: 1

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(ring.shell.now, "hh:mm")
                    mono: true
                    weight: 820
                    color: Theme.textStrong
                    font.pixelSize: 30
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(ring.shell.now, "ddd d MMM")
                    caps: true
                    mono: true
                    color: Theme.textDim
                    font.pixelSize: 9
                }
            }

            // Dived face: which station this is.
            Column {
                anchors.centerIn: parent
                opacity: ring.clamp01(ring.dive)
                spacing: 3

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "0" + (ring.focusedIndex + 1) + " / 0" + ring.stationCount
                    mono: true
                    color: Theme.textDim
                    font.pixelSize: 10
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ring.focusedStation.name
                    caps: true
                    mono: true
                    weight: 850
                    color: Theme.textStrong
                    font.pixelSize: 18
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 120
                    horizontalAlignment: Text.AlignHCenter
                    text: ring.focusedStation.readout
                    color: Theme.textDim
                    elide: Text.ElideRight
                    font.pixelSize: 10
                }
            }
        }

        // --- Fan: the focused station's controls, on an arc to the right ---
        Repeater {
            model: ring.focusedStation.controls

            Rectangle {
                id: control

                required property var modelData
                required property int index

                readonly property int count: ring.focusedStation.controls.length
                readonly property bool selected: index === ring.shell.fanIndex
                property real emphasis: selected ? 1 : 0
                // Each control starts moving a little after the one above it.
                readonly property real progress: Math.max(0, (ring.dive - index * 0.07) / (1 - index * 0.07))
                readonly property real theta: (index - (count - 1) / 2) * ring.fanStepDegrees * Math.PI / 180
                readonly property real distance: ring.hubDiameter / 2 + (ring.fanRadius - ring.hubDiameter / 2) * progress

                Behavior on emphasis {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                width: 300
                height: 46
                x: ring.centerX + distance * Math.cos(theta) - width / 2
                y: ring.centerY + distance * Math.sin(theta) - height / 2
                radius: 10
                visible: ring.dive > 0.01
                opacity: ring.clamp01(progress)
                color: Theme.surface
                border.width: 1
                border.color: Qt.tint(Theme.stroke, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, emphasis))

                Rectangle {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 8 + 16 * control.emphasis
                    radius: 1.5
                    color: Qt.tint(Theme.stroke, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, control.emphasis))
                }

                Label {
                    id: controlLabel

                    x: 24
                    anchors.verticalCenter: parent.verticalCenter
                    width: 84
                    text: control.modelData.label
                    caps: true
                    mono: true
                    color: Theme.textDim
                    elide: Text.ElideRight
                    font.pixelSize: 10
                }

                Label {
                    anchors.left: controlLabel.right
                    anchors.leftMargin: 8
                    anchors.right: controlMeter.visible ? controlMeter.left : parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: control.modelData.value
                    weight: 480 + 320 * control.emphasis
                    color: Theme.textStrong
                    elide: Text.ElideRight
                    font.pixelSize: 13
                }

                Meter {
                    id: controlMeter

                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: control.modelData.level >= 0
                    level: control.modelData.level
                    segments: 8
                    segmentHeight: 10
                }
            }
        }

        // Key hints.
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 64
            text: ring.shell.dived ? "j k  select     enter  act     esc  back" : "h l  turn     enter  open     esc  close"
            caps: true
            mono: true
            color: Theme.textDim
            font.pixelSize: 10
        }
    }
}
