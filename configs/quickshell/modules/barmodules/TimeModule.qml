import QtQuick
import Quickshell.Io
import "../.." as Root
import "../../components" as Components

Components.BarItem {
    id: root
    custom: true
    accent: Root.Theme.domainTime
    popupContent: timePopup

    property string dateFormat: "+%a %b %d"
    property string timeFormat: "+%H:%M"
    property string longDateFormat: "+%A, %B %d %Y"
    property string dateText: ""
    property string timeText: ""
    property string longDateText: ""
    property string timeHours: timeText ? timeText.split(":")[0] || "--" : "--"
    property string timeMinutes: timeText ? timeText.split(":")[1] || "--" : "--"

    property string weekNum: ""
    property string dayOfYear: ""

    // Typewriter startup animation
    property bool startupDone: false
    property int revealedChars: 0

    Text {
        text: Root.Icons.cal
        color: Root.Theme.domainTime
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
        anchors.verticalCenter: parent.verticalCenter
    }

    Row {
        spacing: 0
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.startupDone

        Repeater {
            id: typewriterRepeater
            model: (root.dateText || "--").split("")

            Text {
                required property string modelData
                required property int index
                text: modelData
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: true }
                opacity: index < root.revealedChars ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    Text {
        visible: root.startupDone
        text: root.dateText || "--"
        color: Root.Theme.textPrimary
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: true }
        anchors.verticalCenter: parent.verticalCenter
    }

    Item { width: 4; height: 1 }

    Text {
        text: Root.Icons.clock
        color: Root.Theme.domainTime
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: root.timeHours
        color: Root.Theme.textPrimary
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: true }
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        id: colonText
        text: ":"
        color: Root.Theme.textPrimary
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: true }
        anchors.verticalCenter: parent.verticalCenter

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: true
            NumberAnimation { from: 1.0; to: 0.3; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.3; to: 1.0; duration: 500; easing.type: Easing.InOutSine }
        }
    }

    Text {
        text: root.timeMinutes
        color: Root.Theme.textPrimary
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: true }
        anchors.verticalCenter: parent.verticalCenter
    }

    // ── Popup content (hosted in shared BarPopup window) ──
    property Components.HoverPopup timePopup: Components.HoverPopup {
        visible: false
        popupWidth: 190

        Text {
            text: root.timeText || "--:--"
            color: Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: 28; bold: true }
            width: parent ? parent.width : 0
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: root.longDateText || "--"
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
            width: parent ? parent.width : 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Rectangle {
            width: parent ? parent.width : 0; height: 1
            color: Root.Theme.borderColor; opacity: 0.5
        }

        Components.PopupRow {
            label: "Week"
            value: root.weekNum || "--"
        }

        Components.PopupRow {
            label: "Day of year"
            value: root.dayOfYear || "--"
        }
    }

    // ── Processes ──
    Process {
        id: dateProc
        command: ["date", root.dateFormat]
        running: true
        stdout: SplitParser { onRead: data => { root.dateText = data; } }
        onExited: timeProc.running = true
    }

    Process {
        id: timeProc
        command: ["date", root.timeFormat]
        stdout: SplitParser { onRead: data => { root.timeText = data; } }
        onExited: longDateProc.running = true
    }

    Process {
        id: longDateProc
        command: ["date", root.longDateFormat]
        stdout: SplitParser { onRead: data => { root.longDateText = data; } }
        onExited: weekProc.running = true
    }

    Process {
        id: weekProc
        command: ["date", "+%V"]
        stdout: SplitParser { onRead: data => { root.weekNum = data.trim(); } }
        onExited: doyProc.running = true
    }

    Process {
        id: doyProc
        command: ["date", "+%j"]
        stdout: SplitParser { onRead: data => { root.dayOfYear = data.trim(); } }
        onExited: pollTimer.start()
    }

    Timer {
        id: pollTimer
        interval: 1000
        onTriggered: dateProc.running = true
    }

    Timer {
        id: typewriterTimer
        interval: 45; repeat: true
        onTriggered: {
            root.revealedChars++;
            if (root.revealedChars >= (root.dateText || "").length) {
                typewriterTimer.stop();
                typewriterDoneTimer.start();
            }
        }
    }

    Timer {
        id: typewriterDoneTimer
        interval: 300
        onTriggered: root.startupDone = true
    }

    onDateTextChanged: {
        if (!startupDone && dateText.length > 0 && revealedChars === 0)
            typewriterTimer.start();
    }
}
