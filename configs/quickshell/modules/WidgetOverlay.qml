import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import ".." as Root
import "../widgets" as Widgets

Scope {
    id: root

    property var windowService: null
    property var playerService: null

    property bool editMode: false
    signal editModeToggled(bool enabled)

    property var pendingPositions: ({})
    property var cachedPositions: ({})

    readonly property var validPositions: [
        "top-left", "top-center", "top-right",
        "center-left", "center", "center-right",
        "bottom-left", "bottom-center", "bottom-right"
    ]

    function toggleEditMode() {
        editMode = !editMode;
        if (!editMode) pendingPositions = {};
        editModeToggled(editMode);
    }

    function savePositions() {
        // Merge pending into cached
        for (let widget in pendingPositions) {
            cachedPositions[widget] = pendingPositions[widget];
        }
        cachedPositions = Object.assign({}, cachedPositions);

        // Build lines from all cached positions
        let lines = [];
        for (let widget in cachedPositions) {
            let pos = cachedPositions[widget];
            if (validPositions.indexOf(pos) !== -1) {
                lines.push(widget + "=" + pos);
            }
        }

        // Save to file
        if (lines.length > 0) {
            let data = lines.join("\n");
            let path = Root.Theme.homeDir + "/.cache/quickshell-widget-positions";
            saveProc.command = ["sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"", "--", data, path];
            saveProc.running = true;
        }

        pendingPositions = {};
        editMode = false;
        editModeToggled(false);
    }

    Component.onCompleted: loadProc.running = true

    Process {
        id: loadProc
        command: ["cat", Root.Theme.homeDir + "/.cache/quickshell-widget-positions"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split("=");
                if (parts.length === 2) {
                    let widget = parts[0].trim();
                    let pos = parts[1].trim();
                    if (root.validPositions.indexOf(pos) !== -1) {
                        root.cachedPositions[widget] = pos;
                    }
                }
            }
        }
        onExited: {
            // Trigger reactivity after loading
            root.cachedPositions = Object.assign({}, root.cachedPositions);
        }
    }

    Process {
        id: saveProc
    }

    function getPosition(posStr, itemWidth, itemHeight, areaWidth, areaHeight, marginX, marginY) {
        let x = 0, y = 0;
        if (posStr.indexOf("left") !== -1) x = marginX;
        else if (posStr.indexOf("right") !== -1) x = areaWidth - itemWidth - marginX;
        else x = (areaWidth - itemWidth) / 2;

        if (posStr.indexOf("top") !== -1) y = marginY + Root.Theme.barHeight;
        else if (posStr.indexOf("bottom") !== -1) y = areaHeight - itemHeight - marginY;
        else y = (areaHeight - itemHeight) / 2;

        return Qt.point(x, y);
    }

    function findSnapPosition(x, y, itemWidth, itemHeight, areaWidth, areaHeight) {
        let marginX = Root.Config.widgetMarginX;
        let marginY = Root.Config.widgetMarginY;
        let centerX = x + itemWidth / 2;
        let centerY = y + itemHeight / 2;
        let bestPos = "center";
        let bestDist = Infinity;

        for (let pos of validPositions) {
            let target = getPosition(pos, itemWidth, itemHeight, areaWidth, areaHeight, marginX, marginY);
            let dist = Math.sqrt(Math.pow(centerX - target.x - itemWidth/2, 2) + Math.pow(centerY - target.y - itemHeight/2, 2));
            if (dist < bestDist) { bestDist = dist; bestPos = pos; }
        }
        return bestPos;
    }

    function getEffectivePosition(widgetName, configPos) {
        return pendingPositions[widgetName] || cachedPositions[widgetName] || configPos;
    }

    property bool widgetsShown: root.editMode || !Root.Config.autoHideWidgets || (root.windowService ? root.windowService.widgetsVisible : true)

    // Store widget sizes for ghost rectangles to use
    property size clockSize: Qt.size(160, 90)
    property size weatherSize: Qt.size(130, 70)
    property size systemSize: Qt.size(130, 70)
    property size quoteSize: Qt.size(180, 70)
    property size nowPlayingSize: Qt.size(180, 90)
    property size calendarSize: Qt.size(200, 180)
    property size stockSize: Qt.size(220, 120)

    // ══════════════════════════════════════════════════════════════════
    // ── Single Widget Overlay Panel ──
    // ══════════════════════════════════════════════════════════════════
    Variants {
        model: Root.Config.enableWallpaperWidgets ? Quickshell.screens : []

        PanelWindow {
            id: widgetPanel
            property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.namespace: "quickshell-widgets"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            // Clock Widget
            Widgets.ClockWidget {
                id: clockW
                visible: Root.Config.showClockWidget
                opacity: (root.widgetsShown && !root.editMode) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                property string posStr: root.getEffectivePosition("clockWidgetPosition", Root.Config.clockWidgetPosition)
                property point pos: root.getPosition(posStr, implicitWidth, implicitHeight, widgetPanel.width, widgetPanel.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: pos.x; y: pos.y
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                timeFormat: Root.Config.clockShowSeconds ? Root.Config.clockTimeFormat.replace("mm", "mm:ss") : Root.Config.clockTimeFormat
                dateFormat: Root.Config.clockDateFormat
                showDate: Root.Config.clockShowDate
                showSeconds: Root.Config.clockShowSeconds
                clockFontSize: Root.Config.clockFontSize

                onImplicitWidthChanged: root.clockSize = Qt.size(implicitWidth, implicitHeight)
                onImplicitHeightChanged: root.clockSize = Qt.size(implicitWidth, implicitHeight)
            }

            // Weather Widget
            Widgets.WeatherWidget {
                id: weatherW
                visible: Root.Config.showWeatherWidget
                opacity: (root.widgetsShown && !root.editMode) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                property string posStr: root.getEffectivePosition("weatherWidgetPosition", Root.Config.weatherWidgetPosition)
                property point pos: root.getPosition(posStr, implicitWidth, implicitHeight, widgetPanel.width, widgetPanel.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: pos.x; y: pos.y
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                useMetric: Root.Config.weatherUseMetric
                fontSize: Root.Config.weatherFontSize

                onImplicitWidthChanged: root.weatherSize = Qt.size(implicitWidth, implicitHeight)
                onImplicitHeightChanged: root.weatherSize = Qt.size(implicitWidth, implicitHeight)
            }

            // System Widget
            Widgets.SystemWidget {
                id: systemW
                visible: Root.Config.showSystemWidget
                opacity: (root.widgetsShown && !root.editMode) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                property string posStr: root.getEffectivePosition("systemWidgetPosition", Root.Config.systemWidgetPosition)
                property point pos: root.getPosition(posStr, implicitWidth, implicitHeight, widgetPanel.width, widgetPanel.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: pos.x; y: pos.y
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                showCpu: Root.Config.systemShowCpu
                showRam: Root.Config.systemShowRam
                fontSize: Root.Config.systemFontSize

                onImplicitWidthChanged: root.systemSize = Qt.size(implicitWidth, implicitHeight)
                onImplicitHeightChanged: root.systemSize = Qt.size(implicitWidth, implicitHeight)
            }

            // Quote Widget
            Widgets.QuoteWidget {
                id: quoteW
                visible: Root.Config.showQuoteWidget
                opacity: (root.widgetsShown && !root.editMode) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                property string posStr: root.getEffectivePosition("quoteWidgetPosition", Root.Config.quoteWidgetPosition)
                property point pos: root.getPosition(posStr, implicitWidth, implicitHeight, widgetPanel.width, widgetPanel.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: pos.x; y: pos.y
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                maxWidth: Root.Config.quoteMaxWidth
                fontSize: Root.Config.quoteFontSize
                refreshInterval: Root.Config.quoteRefreshInterval

                onImplicitWidthChanged: root.quoteSize = Qt.size(implicitWidth, implicitHeight)
                onImplicitHeightChanged: root.quoteSize = Qt.size(implicitWidth, implicitHeight)
            }

            // Now Playing Widget
            Widgets.NowPlayingWidget {
                id: nowPlayingW
                visible: Root.Config.showNowPlayingWidget
                opacity: (root.widgetsShown && !root.editMode && hasMedia) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                property string posStr: root.getEffectivePosition("nowPlayingWidgetPosition", Root.Config.nowPlayingWidgetPosition)
                property point pos: root.getPosition(posStr, implicitWidth, implicitHeight, widgetPanel.width, widgetPanel.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: pos.x; y: pos.y
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                playerService: root.playerService
                showArt: Root.Config.nowPlayingShowArt
                artSize: Root.Config.nowPlayingArtSize
                fontSize: Root.Config.nowPlayingFontSize

                onImplicitWidthChanged: root.nowPlayingSize = Qt.size(implicitWidth, implicitHeight)
                onImplicitHeightChanged: root.nowPlayingSize = Qt.size(implicitWidth, implicitHeight)
            }

            // Calendar Widget
            Widgets.CalendarWidget {
                id: calendarW
                visible: Root.Config.showCalendarWidget
                opacity: (root.widgetsShown && !root.editMode) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                property string posStr: root.getEffectivePosition("calendarWidgetPosition", Root.Config.calendarWidgetPosition)
                property point pos: root.getPosition(posStr, implicitWidth, implicitHeight, widgetPanel.width, widgetPanel.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: pos.x; y: pos.y
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                showWeekNumbers: Root.Config.calendarShowWeekNumbers
                cellSize: Root.Config.calendarCellSize

                onImplicitWidthChanged: root.calendarSize = Qt.size(implicitWidth, implicitHeight)
                onImplicitHeightChanged: root.calendarSize = Qt.size(implicitWidth, implicitHeight)
            }

            // Stock Widget
            Widgets.StockWidget {
                id: stockW
                visible: Root.Config.showStockWidget
                opacity: (root.widgetsShown && !root.editMode) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                property string posStr: root.getEffectivePosition("stockWidgetPosition", Root.Config.stockWidgetPosition)
                property point pos: root.getPosition(posStr, implicitWidth, implicitHeight, widgetPanel.width, widgetPanel.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: pos.x; y: pos.y
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                symbols: Root.Config.stockSymbols
                fontSize: Root.Config.stockFontSize
                refreshInterval: Root.Config.stockRefreshInterval

                onImplicitWidthChanged: root.stockSize = Qt.size(implicitWidth, implicitHeight)
                onImplicitHeightChanged: root.stockSize = Qt.size(implicitWidth, implicitHeight)
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // ── Edit Mode Overlay ──
    // ══════════════════════════════════════════════════════════════════
    Variants {
        model: root.editMode ? Quickshell.screens : []

        PanelWindow {
            id: editOverlay
            property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.namespace: "quickshell-widget-edit"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            exclusionMode: ExclusionMode.Ignore
            color: Qt.rgba(0, 0, 0, 0.3)

            // FocusScope for keyboard handling
            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.toggleEditMode()
            }

            // Track current drag state
            property bool isDragging: false
            property size draggedSize: Qt.size(100, 60)
            property string nearestSnap: ""

            function updateNearestSnap(x, y, w, h) {
                nearestSnap = root.findSnapPosition(x, y, w, h, editOverlay.width, editOverlay.height);
            }

            // Snap indicators
            Repeater {
                model: root.validPositions
                Item {
                    id: snapIndicator
                    property string posName: modelData
                    property bool isActive: editOverlay.isDragging && editOverlay.nearestSnap === posName
                    property bool showBorder: editOverlay.isDragging

                    // Use dragged widget size when dragging, otherwise compact for text
                    property real targetWidth: editOverlay.isDragging ? editOverlay.draggedSize.width : 60
                    property real targetHeight: editOverlay.isDragging ? editOverlay.draggedSize.height : 24

                    property point pos: root.getPosition(posName, targetWidth, targetHeight, editOverlay.width, editOverlay.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)

                    x: pos.x; y: pos.y
                    width: targetWidth; height: targetHeight
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    // Border rectangle that expands when dragging
                    Rectangle {
                        anchors.fill: parent
                        radius: Root.Theme.radiusMedium
                        color: snapIndicator.isActive ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.15) : "transparent"
                        border.width: snapIndicator.isActive ? 2 : 1
                        border.color: snapIndicator.isActive ? Root.Theme.textAccent : Root.Theme.textDimmed
                        opacity: snapIndicator.showBorder ? (snapIndicator.isActive ? 1 : 0.5) : 0
                        scale: snapIndicator.isActive ? 1.02 : 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on border.width { NumberAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: posName.replace("-", "\n")
                        horizontalAlignment: Text.AlignHCenter
                        color: snapIndicator.isActive ? Root.Theme.textAccent : Root.Theme.textDimmed
                        opacity: snapIndicator.showBorder ? (snapIndicator.isActive ? 1 : 0.7) : 0.4
                        font { family: Root.Theme.fontFamily; pixelSize: 9 }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }
            }

            // Clock ghost
            Rectangle {
                id: clockGhost
                visible: Root.Config.showClockWidget
                width: root.clockSize.width; height: root.clockSize.height
                radius: Root.Theme.widgetRadius
                color: Root.Theme.widgetBackground
                border.width: 2
                border.color: clockDrag.drag.active ? Root.Theme.textAccent : Root.Theme.editModeBorder

                property string posStr: root.getEffectivePosition("clockWidgetPosition", Root.Config.clockWidgetPosition)
                property point targetPos: root.getPosition(posStr, width, height, editOverlay.width, editOverlay.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: clockDrag.drag.active ? x : targetPos.x
                y: clockDrag.drag.active ? y : targetPos.y
                Behavior on x { enabled: !clockDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !clockDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Text { anchors.centerIn: parent; text: "Clock"; color: Root.Theme.widgetText; font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true } }
                MouseArea {
                    id: clockDrag; anchors.fill: parent; drag.target: parent; drag.smoothed: false
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: { editOverlay.isDragging = true; editOverlay.draggedSize = Qt.size(parent.width, parent.height); }
                    onPositionChanged: if (drag.active) editOverlay.updateNearestSnap(parent.x, parent.y, parent.width, parent.height)
                    onReleased: {
                        editOverlay.isDragging = false; editOverlay.nearestSnap = "";
                        let newPos = root.findSnapPosition(parent.x, parent.y, parent.width, parent.height, editOverlay.width, editOverlay.height);
                        root.pendingPositions["clockWidgetPosition"] = newPos;
                        root.pendingPositions = Object.assign({}, root.pendingPositions);
                    }
                }
            }

            // Weather ghost
            Rectangle {
                id: weatherGhost
                visible: Root.Config.showWeatherWidget
                width: root.weatherSize.width; height: root.weatherSize.height
                radius: Root.Theme.widgetRadius
                color: Root.Theme.widgetBackground
                border.width: 2
                border.color: weatherDrag.drag.active ? Root.Theme.textAccent : Root.Theme.editModeBorder

                property string posStr: root.getEffectivePosition("weatherWidgetPosition", Root.Config.weatherWidgetPosition)
                property point targetPos: root.getPosition(posStr, width, height, editOverlay.width, editOverlay.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: weatherDrag.drag.active ? x : targetPos.x
                y: weatherDrag.drag.active ? y : targetPos.y
                Behavior on x { enabled: !weatherDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !weatherDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Text { anchors.centerIn: parent; text: "Weather"; color: Root.Theme.widgetText; font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true } }
                MouseArea {
                    id: weatherDrag; anchors.fill: parent; drag.target: parent; drag.smoothed: false
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: { editOverlay.isDragging = true; editOverlay.draggedSize = Qt.size(parent.width, parent.height); }
                    onPositionChanged: if (drag.active) editOverlay.updateNearestSnap(parent.x, parent.y, parent.width, parent.height)
                    onReleased: {
                        editOverlay.isDragging = false; editOverlay.nearestSnap = "";
                        let newPos = root.findSnapPosition(parent.x, parent.y, parent.width, parent.height, editOverlay.width, editOverlay.height);
                        root.pendingPositions["weatherWidgetPosition"] = newPos;
                        root.pendingPositions = Object.assign({}, root.pendingPositions);
                    }
                }
            }

            // System ghost
            Rectangle {
                id: systemGhost
                visible: Root.Config.showSystemWidget
                width: root.systemSize.width; height: root.systemSize.height
                radius: Root.Theme.widgetRadius
                color: Root.Theme.widgetBackground
                border.width: 2
                border.color: systemDrag.drag.active ? Root.Theme.textAccent : Root.Theme.editModeBorder

                property string posStr: root.getEffectivePosition("systemWidgetPosition", Root.Config.systemWidgetPosition)
                property point targetPos: root.getPosition(posStr, width, height, editOverlay.width, editOverlay.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: systemDrag.drag.active ? x : targetPos.x
                y: systemDrag.drag.active ? y : targetPos.y
                Behavior on x { enabled: !systemDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !systemDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Text { anchors.centerIn: parent; text: "System"; color: Root.Theme.widgetText; font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true } }
                MouseArea {
                    id: systemDrag; anchors.fill: parent; drag.target: parent; drag.smoothed: false
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: { editOverlay.isDragging = true; editOverlay.draggedSize = Qt.size(parent.width, parent.height); }
                    onPositionChanged: if (drag.active) editOverlay.updateNearestSnap(parent.x, parent.y, parent.width, parent.height)
                    onReleased: {
                        editOverlay.isDragging = false; editOverlay.nearestSnap = "";
                        let newPos = root.findSnapPosition(parent.x, parent.y, parent.width, parent.height, editOverlay.width, editOverlay.height);
                        root.pendingPositions["systemWidgetPosition"] = newPos;
                        root.pendingPositions = Object.assign({}, root.pendingPositions);
                    }
                }
            }

            // Quote ghost
            Rectangle {
                id: quoteGhost
                visible: Root.Config.showQuoteWidget
                width: root.quoteSize.width; height: root.quoteSize.height
                radius: Root.Theme.widgetRadius
                color: Root.Theme.widgetBackground
                border.width: 2
                border.color: quoteDrag.drag.active ? Root.Theme.textAccent : Root.Theme.editModeBorder

                property string posStr: root.getEffectivePosition("quoteWidgetPosition", Root.Config.quoteWidgetPosition)
                property point targetPos: root.getPosition(posStr, width, height, editOverlay.width, editOverlay.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: quoteDrag.drag.active ? x : targetPos.x
                y: quoteDrag.drag.active ? y : targetPos.y
                Behavior on x { enabled: !quoteDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !quoteDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Text { anchors.centerIn: parent; text: "Quote"; color: Root.Theme.widgetText; font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true } }
                MouseArea {
                    id: quoteDrag; anchors.fill: parent; drag.target: parent; drag.smoothed: false
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: { editOverlay.isDragging = true; editOverlay.draggedSize = Qt.size(parent.width, parent.height); }
                    onPositionChanged: if (drag.active) editOverlay.updateNearestSnap(parent.x, parent.y, parent.width, parent.height)
                    onReleased: {
                        editOverlay.isDragging = false; editOverlay.nearestSnap = "";
                        let newPos = root.findSnapPosition(parent.x, parent.y, parent.width, parent.height, editOverlay.width, editOverlay.height);
                        root.pendingPositions["quoteWidgetPosition"] = newPos;
                        root.pendingPositions = Object.assign({}, root.pendingPositions);
                    }
                }
            }

            // Now Playing ghost
            Rectangle {
                id: nowPlayingGhost
                visible: Root.Config.showNowPlayingWidget
                width: root.nowPlayingSize.width; height: root.nowPlayingSize.height
                radius: Root.Theme.widgetRadius
                color: Root.Theme.widgetBackground
                border.width: 2
                border.color: nowPlayingDrag.drag.active ? Root.Theme.textAccent : Root.Theme.editModeBorder

                property string posStr: root.getEffectivePosition("nowPlayingWidgetPosition", Root.Config.nowPlayingWidgetPosition)
                property point targetPos: root.getPosition(posStr, width, height, editOverlay.width, editOverlay.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: nowPlayingDrag.drag.active ? x : targetPos.x
                y: nowPlayingDrag.drag.active ? y : targetPos.y
                Behavior on x { enabled: !nowPlayingDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !nowPlayingDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Text { anchors.centerIn: parent; text: "Now Playing"; color: Root.Theme.widgetText; font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true } }
                MouseArea {
                    id: nowPlayingDrag; anchors.fill: parent; drag.target: parent; drag.smoothed: false
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: { editOverlay.isDragging = true; editOverlay.draggedSize = Qt.size(parent.width, parent.height); }
                    onPositionChanged: if (drag.active) editOverlay.updateNearestSnap(parent.x, parent.y, parent.width, parent.height)
                    onReleased: {
                        editOverlay.isDragging = false; editOverlay.nearestSnap = "";
                        let newPos = root.findSnapPosition(parent.x, parent.y, parent.width, parent.height, editOverlay.width, editOverlay.height);
                        root.pendingPositions["nowPlayingWidgetPosition"] = newPos;
                        root.pendingPositions = Object.assign({}, root.pendingPositions);
                    }
                }
            }

            // Calendar ghost
            Rectangle {
                id: calendarGhost
                visible: Root.Config.showCalendarWidget
                width: root.calendarSize.width; height: root.calendarSize.height
                radius: Root.Theme.widgetRadius
                color: Root.Theme.widgetBackground
                border.width: 2
                border.color: calendarDrag.drag.active ? Root.Theme.textAccent : Root.Theme.editModeBorder

                property string posStr: root.getEffectivePosition("calendarWidgetPosition", Root.Config.calendarWidgetPosition)
                property point targetPos: root.getPosition(posStr, width, height, editOverlay.width, editOverlay.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: calendarDrag.drag.active ? x : targetPos.x
                y: calendarDrag.drag.active ? y : targetPos.y
                Behavior on x { enabled: !calendarDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !calendarDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Text { anchors.centerIn: parent; text: "Calendar"; color: Root.Theme.widgetText; font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true } }
                MouseArea {
                    id: calendarDrag; anchors.fill: parent; drag.target: parent; drag.smoothed: false
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: { editOverlay.isDragging = true; editOverlay.draggedSize = Qt.size(parent.width, parent.height); }
                    onPositionChanged: if (drag.active) editOverlay.updateNearestSnap(parent.x, parent.y, parent.width, parent.height)
                    onReleased: {
                        editOverlay.isDragging = false; editOverlay.nearestSnap = "";
                        let newPos = root.findSnapPosition(parent.x, parent.y, parent.width, parent.height, editOverlay.width, editOverlay.height);
                        root.pendingPositions["calendarWidgetPosition"] = newPos;
                        root.pendingPositions = Object.assign({}, root.pendingPositions);
                    }
                }
            }

            // Stock ghost
            Rectangle {
                id: stockGhost
                visible: Root.Config.showStockWidget
                width: root.stockSize.width; height: root.stockSize.height
                radius: Root.Theme.widgetRadius
                color: Root.Theme.widgetBackground
                border.width: 2
                border.color: stockDrag.drag.active ? Root.Theme.textAccent : Root.Theme.editModeBorder

                property string posStr: root.getEffectivePosition("stockWidgetPosition", Root.Config.stockWidgetPosition)
                property point targetPos: root.getPosition(posStr, width, height, editOverlay.width, editOverlay.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)
                x: stockDrag.drag.active ? x : targetPos.x
                y: stockDrag.drag.active ? y : targetPos.y
                Behavior on x { enabled: !stockDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !stockDrag.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Text { anchors.centerIn: parent; text: "Stocks"; color: Root.Theme.widgetText; font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true } }
                MouseArea {
                    id: stockDrag; anchors.fill: parent; drag.target: parent; drag.smoothed: false
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: { editOverlay.isDragging = true; editOverlay.draggedSize = Qt.size(parent.width, parent.height); }
                    onPositionChanged: if (drag.active) editOverlay.updateNearestSnap(parent.x, parent.y, parent.width, parent.height)
                    onReleased: {
                        editOverlay.isDragging = false; editOverlay.nearestSnap = "";
                        let newPos = root.findSnapPosition(parent.x, parent.y, parent.width, parent.height, editOverlay.width, editOverlay.height);
                        root.pendingPositions["stockWidgetPosition"] = newPos;
                        root.pendingPositions = Object.assign({}, root.pendingPositions);
                    }
                }
            }

            // Controls
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 40
                width: controlsRow.width + 32; height: 48
                radius: Root.Theme.radiusMedium
                color: Root.Theme.barBackground
                border.width: Root.Theme.borderWidth; border.color: Root.Theme.borderColor

                Row {
                    id: controlsRow
                    anchors.centerIn: parent; spacing: 16

                    Rectangle {
                        width: 90; height: 32; radius: Root.Theme.radiusSmall
                        color: saveMA.containsMouse ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.2) : "transparent"
                        border.width: 1; border.color: Root.Theme.textAccent
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: Root.Theme.iconSave; color: Root.Theme.textAccent; font.family: Root.Theme.fontFamily; font.pixelSize: 14 }
                            Text { text: "Save"; color: Root.Theme.textAccent; font { family: Root.Theme.fontFamily; pixelSize: 12; bold: true } }
                        }
                        MouseArea { id: saveMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.savePositions() }
                    }

                    Rectangle {
                        width: 90; height: 32; radius: Root.Theme.radiusSmall
                        color: cancelMA.containsMouse ? Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.2) : "transparent"
                        border.width: 1; border.color: Root.Theme.textDimmed
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: Root.Theme.iconCancel; color: Root.Theme.textDimmed; font.family: Root.Theme.fontFamily; font.pixelSize: 14 }
                            Text { text: "Cancel"; color: Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: 12 } }
                        }
                        MouseArea { id: cancelMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleEditMode() }
                    }
                }
            }

            Text {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: Root.Theme.barHeight + 16
                text: "Drag widgets to reposition"
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: 13 }
                opacity: 0.7
            }
        }
    }
}
