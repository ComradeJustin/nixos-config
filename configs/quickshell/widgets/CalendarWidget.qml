import QtQuick
import ".." as Root
import "../components" as Components

// Background calendar widget with month view
Components.WidgetFrame {
    id: root
    widgetName: "calendar"

    property bool showWeekNumbers: Root.Config.calendarConfig.showWeekNumbers
    property int cellSize: Root.Config.calendarConfig.cellSize

    property date currentDate: new Date()
    property int currentYear: currentDate.getFullYear()
    property int currentMonth: currentDate.getMonth()
    property int currentDay: currentDate.getDate()
    property int displayYear: currentYear
    property int displayMonth: currentMonth

    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: {
            let now = new Date();
            if (now.getDate() !== root.currentDay) root.currentDate = now;
        }
    }

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
                                        "July", "August", "September", "October", "November", "December"]
    readonly property var dayNames: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    function getDaysInMonth(year, month) { return new Date(year, month + 1, 0).getDate(); }
    function getFirstDayOfMonth(year, month) { return new Date(year, month, 1).getDay(); }
    function getWeekNumber(date) {
        let d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        let dayNum = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - dayNum);
        let yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    }

    Column {
        spacing: Root.Theme.spacingS

        // Header: Month navigation
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Root.Theme.spacingL

            Components.IconButton {
                icon: "<"
                iconColor: Root.Theme.textAccent
                size: 24
                onClicked: {
                    if (root.displayMonth === 0) { root.displayMonth = 11; root.displayYear--; }
                    else root.displayMonth--;
                }
            }

            Text {
                text: root.monthNames[root.displayMonth] + " " + root.displayYear
                color: Root.Theme.widgetText
                font { family: Root.Theme.fontDisplay; pixelSize: Root.Theme.fontSizeXL; weight: Font.Medium }
                width: 120; horizontalAlignment: Text.AlignHCenter
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.displayYear = root.currentYear; root.displayMonth = root.currentMonth; }
                }
            }

            Components.IconButton {
                icon: ">"
                iconColor: Root.Theme.textAccent
                size: 24
                onClicked: {
                    if (root.displayMonth === 11) { root.displayMonth = 0; root.displayYear++; }
                    else root.displayMonth++;
                }
            }
        }

        // Day names header
        Row {
            spacing: 2
            Item { visible: root.showWeekNumbers; width: root.cellSize; height: root.cellSize }
            Repeater {
                model: root.dayNames
                Text {
                    width: root.cellSize; height: root.cellSize
                    text: modelData; color: Root.Theme.widgetTextDimmed
                    font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeXS }
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Calendar grid
        Column {
            spacing: 2
            Repeater {
                model: 6
                Row {
                    id: weekRow; property int weekIndex: index; spacing: 2

                    Text {
                        visible: root.showWeekNumbers
                        width: root.cellSize; height: root.cellSize
                        property int firstDayOffset: root.getFirstDayOfMonth(root.displayYear, root.displayMonth)
                        property int dayNum: weekRow.weekIndex * 7 - firstDayOffset + 1
                        property date weekDate: new Date(root.displayYear, root.displayMonth, Math.max(1, dayNum))
                        text: root.getWeekNumber(weekDate)
                        color: Root.Theme.widgetTextDimmed
                        font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeXS }
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        opacity: 0.6
                    }

                    Repeater {
                        model: 7
                        Rectangle {
                            width: root.cellSize; height: root.cellSize
                            property int firstDayOffset: root.getFirstDayOfMonth(root.displayYear, root.displayMonth)
                            property int daysInMonth: root.getDaysInMonth(root.displayYear, root.displayMonth)
                            property int dayIndex: weekRow.weekIndex * 7 + index - firstDayOffset + 1
                            property bool isCurrentMonth: dayIndex >= 1 && dayIndex <= daysInMonth
                            property bool isToday: isCurrentMonth && dayIndex === root.currentDay &&
                                                   root.displayMonth === root.currentMonth && root.displayYear === root.currentYear
                            color: isToday ? Root.Theme.textAccent : "transparent"
                            radius: root.cellSize / 2
                            Text {
                                anchors.centerIn: parent
                                text: parent.isCurrentMonth ? parent.dayIndex : ""
                                color: parent.isToday ? Root.Theme.base00 :
                                       (index === 0 || index === 6) ? Root.Theme.widgetTextDimmed : Root.Theme.widgetText
                                font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeM; bold: parent.isToday }
                            }
                        }
                    }
                }
            }
        }
    }
}
