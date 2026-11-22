import QtQuick
import Quickshell
import Quickshell.Wayland

// The calendar: a month as a grid, with today in reverse video and today's
// weather under it. It drops out of the bar under the clock and takes the
// keyboard while it is open:
// h and l or the arrows change the month, t goes back to today, esc closes
// it. The wheel changes the month too. Changing month wipes the panel away
// and wipes the new month in.
PanelWindow {
    id: calendar

    // The shell root (shell.qml). shell.calendarOffset says which month is
    // wanted, counted in months from this one.
    required property var shell

    // The month that is drawn. It follows shell.calendarOffset only once
    // the panel has been wiped away, so a month never changes on screen.
    property int drawnOffset: 0

    readonly property var today: shell.now
    // The first day of the month that is drawn. A month number past
    // December, or before January, rolls over into the next or last year.
    readonly property var firstDay: new Date(today.getFullYear(), today.getMonth() + drawnOffset, 1)
    // Day 0 of the month after is the last day of this one.
    readonly property int daysInMonth: new Date(firstDay.getFullYear(), firstDay.getMonth() + 1, 0).getDate()
    // Which column the 1st falls in. Weeks start on Monday.
    readonly property int firstColumn: (firstDay.getDay() + 6) % 7

    // 0 = nothing showing, 1 = the whole panel.
    property real shown: shell.calendarShown && drawnOffset === shell.calendarOffset ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    onShownChanged: {
        if (shown === 0)
            drawnOffset = shell.calendarOffset;
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
    WlrLayershell.namespace: "shell"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shell.calendarShown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible) {
            drawnOffset = shell.calendarOffset;
            panel.forceActiveFocus();
        }
    }

    Box {
        id: panel

        // Seven days of three cells each, less the space after the last.
        columns: 24
        // The weekdays, six weeks, and a line for today's weather.
        rows: 8
        title: Qt.formatDateTime(calendar.firstDay, "MMMM yyyy")
        // Only the keys that do something: "today" once it has moved away.
        footer: calendar.drawnOffset === 0 ? "←→ month  esc close" : "t today  esc close"
        shown: calendar.shown
        focus: true

        WheelHandler {
            onWheel: event => calendar.shell.calendarOffset += event.angleDelta.y > 0 ? -1 : 1
        }

        Keys.onPressed: event => {
            const shell = calendar.shell;
            event.accepted = true;
            if (event.key === Qt.Key_Escape)
                shell.calendarShown = false;
            else if (event.key === Qt.Key_H || event.key === Qt.Key_Left)
                shell.calendarOffset -= 1;
            else if (event.key === Qt.Key_L || event.key === Qt.Key_Right)
                shell.calendarOffset += 1;
            else if (event.key === Qt.Key_T)
                shell.calendarOffset = 0;
        }

        Label {
            text: "mo tu we th fr sa su"
            color: Theme.inkDim
            smallCaps: true
        }

        // Today's weather, once the shell has it (shell.qml asks for it
        // when the calendar opens).
        Label {
            y: 7 * Theme.cellHeight
            width: panel.contentColumns * Theme.cellWidth
            text: calendar.shell.weather !== null ? calendar.shell.weather.temperature + " " + calendar.shell.weather.description : ""
            color: Theme.inkDim
            elide: Text.ElideRight
        }

        Repeater {
            model: 42

            // One day. Places before the 1st and after the last day stay empty.
            Item {
                required property int index

                readonly property int day: index - calendar.firstColumn + 1
                readonly property bool inMonth: day >= 1 && day <= calendar.daysInMonth
                // Today is only marked in this month.
                readonly property bool isToday: inMonth && calendar.drawnOffset === 0 && day === calendar.today.getDate()
                readonly property bool weekend: index % 7 >= 5

                x: (index % 7) * 3 * Theme.cellWidth
                y: (1 + Math.floor(index / 7)) * Theme.cellHeight
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
