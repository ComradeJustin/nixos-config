import QtQuick
import "../../.." as Root

// CalendarCard — compact month grid with today highlighted.
Rectangle {
    id: card

    width: parent ? parent.width : 320
    implicitHeight: headerCol.implicitHeight + 24

    radius: Root.Theme.radiusMedium
    color: Root.Theme.ccSectionBg
    border.width: Root.Theme.borderWidth
    border.color: Root.Theme.borderColor
    clip: true

    // Current date tracking
    property date _now: new Date()
    property int _year: _now.getFullYear()
    property int _month: _now.getMonth()
    property int _today: _now.getDate()

    // Month navigation
    property int viewYear: _year
    property int viewMonth: _month

    readonly property var _dayNames: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    readonly property var _monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    // Compute the 42-cell grid (6 weeks) for the viewed month
    readonly property var _cells: {
        let first = new Date(viewYear, viewMonth, 1);
        // Monday = 0, Sunday = 6
        let startDay = (first.getDay() + 6) % 7;
        let daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate();
        let daysInPrev = new Date(viewYear, viewMonth, 0).getDate();

        let cells = [];
        // Previous month trailing days
        for (let i = startDay - 1; i >= 0; i--)
            cells.push({ day: daysInPrev - i, current: false });
        // Current month
        for (let d = 1; d <= daysInMonth; d++)
            cells.push({ day: d, current: true });
        // Next month leading days
        while (cells.length < 42)
            cells.push({ day: cells.length - startDay - daysInMonth + 1, current: false });
        return cells;
    }

    readonly property bool _isCurrentMonth: viewYear === _year && viewMonth === _month

    function _prevMonth() {
        if (viewMonth === 0) { viewMonth = 11; viewYear--; }
        else viewMonth--;
    }
    function _nextMonth() {
        if (viewMonth === 11) { viewMonth = 0; viewYear++; }
        else viewMonth++;
    }
    function _goToday() { viewYear = _year; viewMonth = _month; }

    // Refresh date at midnight
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            let now = new Date();
            if (now.getDate() !== card._today) {
                card._now = now;
                card._year = now.getFullYear();
                card._month = now.getMonth();
                card._today = now.getDate();
            }
        }
    }

    Column {
        id: headerCol
        anchors {
            left: parent.left; right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 8

        // Month/year header with nav arrows
        Row {
            width: parent.width
            spacing: 0

            // Previous month
            Rectangle {
                width: 24; height: 24; radius: 12
                color: prevMouse.containsMouse ? Root.Theme.layer1Hover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: 14; bold: true }
                }
                MouseArea {
                    id: prevMouse; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: card._prevMonth()
                }
            }

            // Month label (clickable to go back to today)
            Item {
                width: parent.width - 48
                height: 24

                Text {
                    anchors.centerIn: parent
                    text: card._monthNames[card.viewMonth] + " " + card.viewYear
                    color: card._isCurrentMonth ? Root.Theme.domainTime : Root.Theme.textPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: card._isCurrentMonth ? undefined : Qt.PointingHandCursor
                        onClicked: if (!card._isCurrentMonth) card._goToday()
                    }
                }
            }

            // Next month
            Rectangle {
                width: 24; height: 24; radius: 12
                color: nextMouse.containsMouse ? Root.Theme.layer1Hover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "›"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: 14; bold: true }
                }
                MouseArea {
                    id: nextMouse; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: card._nextMonth()
                }
            }
        }

        // Day-of-week headers
        Grid {
            id: dayHeaders
            columns: 7
            width: parent.width
            property real cellW: width / 7

            Repeater {
                model: card._dayNames
                Text {
                    width: dayHeaders.cellW
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: 10 }
                }
            }
        }

        // Calendar grid
        Grid {
            id: calGrid
            columns: 7
            width: parent.width
            property real cellW: width / 7
            property real cellH: 26

            Repeater {
                model: card._cells

                Item {
                    width: calGrid.cellW
                    height: calGrid.cellH

                    property bool isToday: modelData.current
                        && card._isCurrentMonth
                        && modelData.day === card._today

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(calGrid.cellW - 2, calGrid.cellH - 2)
                        height: width
                        radius: width / 2
                        color: parent.isToday
                            ? Root.Theme.domainTime
                            : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.day
                        color: parent.isToday
                            ? Root.Theme.base00
                            : (modelData.current ? Root.Theme.textPrimary : Root.Theme.textDimmed)
                        font {
                            family: Root.Theme.fontFamily
                            pixelSize: 11
                            bold: parent.isToday
                        }
                        opacity: modelData.current ? 1 : 0.4
                    }
                }
            }
        }
    }
}
