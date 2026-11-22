import QtQuick
import Quickshell
import Quickshell.Wayland

// The calendar: this month as a grid, with today in reverse video and the
// weather above it. It drops out of the bar under the clock. The month is
// real; the weather is sample text.
PanelWindow {
    id: calendar

    // The shell root (shell.qml).
    required property var shell

    readonly property var today: shell.now
    readonly property int year: today.getFullYear()
    readonly property int month: today.getMonth()
    // Day 0 of next month is the last day of this one.
    readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
    // Which column the 1st falls in. Weeks start on Monday.
    readonly property int firstColumn: (new Date(year, month, 1).getDay() + 6) % 7

    // 0 = nothing showing, 1 = the whole panel.
    property real shown: shell.calendarShown ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    // Stay mapped until the panel has been wiped away.
    visible: shell.calendarShown || shown > 0
    anchors.top: true
    // Directly under the bar, or against the top of the screen when a
    // fullscreen window has covered the bar.
    margins.top: shell.fullscreen ? 0 : Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Overlay

    Box {
        id: panel

        // Seven days of three cells each, less the space after the last.
        columns: 24
        // Two lines of weather, a gap, the weekdays and six weeks.
        rows: 10
        title: Qt.formatDateTime(calendar.today, "MMMM yyyy")
        footer: "←→ month"
        shown: calendar.shown

        Label {
            text: "12°  light rain"
            color: Theme.ink
        }

        Label {
            y: Theme.cellHeight
            text: "high 14  low 8"
            color: Theme.inkDim
        }

        Label {
            y: 3 * Theme.cellHeight
            text: "mo tu we th fr sa su"
            color: Theme.inkDim
            smallCaps: true
        }

        Repeater {
            model: 42

            // One day. Places before the 1st and after the last day stay empty.
            Item {
                required property int index

                readonly property int day: index - calendar.firstColumn + 1
                readonly property bool inMonth: day >= 1 && day <= calendar.daysInMonth
                readonly property bool isToday: inMonth && day === calendar.today.getDate()
                readonly property bool weekend: index % 7 >= 5

                x: (index % 7) * 3 * Theme.cellWidth
                y: (4 + Math.floor(index / 7)) * Theme.cellHeight
                width: 2 * Theme.cellWidth
                height: Theme.cellHeight

                Rectangle {
                    anchors.fill: parent
                    visible: parent.isToday
                    color: Theme.accent
                }

                Label {
                    visible: parent.inMonth
                    text: parent.day < 10 ? " " + parent.day : parent.day
                    color: parent.isToday ? Theme.slab : (parent.weekend ? Theme.inkDim : Theme.inkSoft)
                }
            }
        }
    }
}
