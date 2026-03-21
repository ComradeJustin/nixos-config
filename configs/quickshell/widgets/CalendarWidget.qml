import QtQuick
import ".." as Root

// Background calendar widget with month view
Item {
    id: root

    // Config properties
    property bool showWeekNumbers: false
    property int cellSize: 28

    implicitWidth: content.implicitWidth + Root.Theme.widgetPadding * 2
    implicitHeight: content.implicitHeight + Root.Theme.widgetPadding * 2

    // Date state
    property date currentDate: new Date()
    property int currentYear: currentDate.getFullYear()
    property int currentMonth: currentDate.getMonth()
    property int currentDay: currentDate.getDate()
    property int displayYear: currentYear
    property int displayMonth: currentMonth

    // Update current date at midnight
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            let now = new Date();
            if (now.getDate() !== root.currentDay) {
                root.currentDate = now;
            }
        }
    }

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
                                        "July", "August", "September", "October", "November", "December"]
    readonly property var dayNames: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    function getDaysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function getFirstDayOfMonth(year, month) {
        return new Date(year, month, 1).getDay();
    }

    function getWeekNumber(date) {
        let d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        let dayNum = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - dayNum);
        let yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    }

    // Shadow layer
    Rectangle {
        anchors.fill: bg
        anchors.margins: -2
        anchors.topMargin: 2
        radius: Root.Theme.widgetRadius + 2
        color: Root.Theme.widgetShadowColor
        opacity: 0.4
    }

    // Widget background
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Root.Theme.widgetRadius
        color: Root.Theme.widgetBackground
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor
    }

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 8

        // Header: Month navigation
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Text {
                text: "<"
                color: prevHover.containsMouse ? Root.Theme.textAccent : Root.Theme.widgetTextDimmed
                font { family: Root.Theme.fontMono; pixelSize: 14; bold: true }
                MouseArea {
                    id: prevHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.displayMonth === 0) {
                            root.displayMonth = 11;
                            root.displayYear--;
                        } else {
                            root.displayMonth--;
                        }
                    }
                }
            }

            Text {
                text: root.monthNames[root.displayMonth] + " " + root.displayYear
                color: Root.Theme.widgetText
                font { family: Root.Theme.fontFamily; pixelSize: 14; bold: true }
                width: 120
                horizontalAlignment: Text.AlignHCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.displayYear = root.currentYear;
                        root.displayMonth = root.currentMonth;
                    }
                }
            }

            Text {
                text: ">"
                color: nextHover.containsMouse ? Root.Theme.textAccent : Root.Theme.widgetTextDimmed
                font { family: Root.Theme.fontMono; pixelSize: 14; bold: true }
                MouseArea {
                    id: nextHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.displayMonth === 11) {
                            root.displayMonth = 0;
                            root.displayYear++;
                        } else {
                            root.displayMonth++;
                        }
                    }
                }
            }
        }

        // Day names header
        Row {
            spacing: 2

            // Week number header spacer
            Item {
                visible: root.showWeekNumbers
                width: root.cellSize
                height: root.cellSize
            }

            Repeater {
                model: root.dayNames
                Text {
                    width: root.cellSize
                    height: root.cellSize
                    text: modelData
                    color: Root.Theme.widgetTextDimmed
                    font { family: Root.Theme.fontMono; pixelSize: 10 }
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Calendar grid
        Column {
            spacing: 2

            Repeater {
                model: 6  // Max 6 weeks in a month view

                Row {
                    id: weekRow
                    property int weekIndex: index
                    spacing: 2

                    // Week number
                    Text {
                        visible: root.showWeekNumbers
                        width: root.cellSize
                        height: root.cellSize
                        property int firstDayOffset: root.getFirstDayOfMonth(root.displayYear, root.displayMonth)
                        property int dayNum: weekRow.weekIndex * 7 - firstDayOffset + 1
                        property date weekDate: new Date(root.displayYear, root.displayMonth, Math.max(1, dayNum))
                        text: root.getWeekNumber(weekDate)
                        color: Root.Theme.widgetTextDimmed
                        font { family: Root.Theme.fontMono; pixelSize: 10 }
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: 0.6
                    }

                    Repeater {
                        model: 7  // 7 days per week

                        Rectangle {
                            width: root.cellSize
                            height: root.cellSize

                            property int firstDayOffset: root.getFirstDayOfMonth(root.displayYear, root.displayMonth)
                            property int daysInMonth: root.getDaysInMonth(root.displayYear, root.displayMonth)
                            property int dayIndex: weekRow.weekIndex * 7 + index - firstDayOffset + 1
                            property bool isCurrentMonth: dayIndex >= 1 && dayIndex <= daysInMonth
                            property bool isToday: isCurrentMonth &&
                                                   dayIndex === root.currentDay &&
                                                   root.displayMonth === root.currentMonth &&
                                                   root.displayYear === root.currentYear

                            color: isToday ? Root.Theme.textAccent : "transparent"
                            radius: root.cellSize / 2

                            Text {
                                anchors.centerIn: parent
                                text: parent.isCurrentMonth ? parent.dayIndex : ""
                                color: parent.isToday ? Root.Theme.base00 :
                                       (index === 0 || index === 6) ? Root.Theme.widgetTextDimmed : Root.Theme.widgetText
                                font {
                                    family: Root.Theme.fontMono
                                    pixelSize: 12
                                    bold: parent.isToday
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
