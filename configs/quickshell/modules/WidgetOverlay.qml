import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import ".." as Root
import "../widgets" as Widgets
import "../components" as Components
import "../core" as Core

Scope {
    id: root

    property var windowService: null
    property var playerService: null
    property var weatherService: null

    property bool editMode: false
    signal editModeToggled(bool enabled)

    property var pendingPositions: ({})
    property var cachedPositions: ({})

    readonly property var validPositions: [
        "top-left", "top-center", "top-right",
        "center-left", "center", "center-right",
        "bottom-left", "bottom-center", "bottom-right"
    ]

    // All widget position keys for swap logic (derived from Registry)
    readonly property var allWidgetKeys: {
        let keys = [];
        for (let w of Core.Registry.widgets) keys.push(w.positionKey);
        return keys;
    }

    function toggleEditMode() {
        editMode = !editMode;
        if (!editMode) pendingPositions = {};
        editModeToggled(editMode);
    }

    function savePositions() {
        for (let widget in pendingPositions) {
            cachedPositions[widget] = pendingPositions[widget];
        }
        cachedPositions = Object.assign({}, cachedPositions);

        let lines = [];
        for (let widget in cachedPositions) {
            let pos = cachedPositions[widget];
            if (validPositions.indexOf(pos) !== -1) {
                lines.push(widget + "=" + pos);
            }
        }

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
            root.cachedPositions = Object.assign({}, root.cachedPositions);
        }
    }

    Process { id: saveProc }

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

    // ── Swap Logic ──
    // Snapshot of pendingPositions taken at drag start, so mid-drag
    // hover-swaps always reset to the pre-drag state before applying.
    property var preDragPending: ({})

    function beginDrag(droppedKey) {
        preDragPending = Object.assign({}, pendingPositions);
    }

    // Swap: occupant goes to the dragged widget's pre-drag position.
    // Each call rebuilds from preDragPending so only one swap is active.
    function handleSwap(droppedKey, targetPosition, originPosition) {
        let origin = originPosition;
        let fresh = Object.assign({}, preDragPending);

        // Find which widget occupies the target in the pre-drag state
        for (let key of allWidgetKeys) {
            if (key !== droppedKey) {
                let pos = fresh[key] || cachedPositions[key] || getDefaultPosition(key);
                if (pos === targetPosition) {
                    fresh[key] = origin;
                    break;
                }
            }
        }
        fresh[droppedKey] = targetPosition;
        pendingPositions = fresh;
    }

    function getDefaultPosition(key) {
        for (let w of Core.Registry.widgets) {
            if (w.positionKey === key)
                return Root.Config[key] || w.defaultPos;
        }
        return "center";
    }

    // Per-screen widget visibility check
    function widgetsShownForScreen(screenName) {
        if (root.editMode || !Root.Config.autoHideWidgets) return true;
        if (!root.windowService) return true;
        return root.windowService.screenEmpty(screenName) && !root.windowService.overviewOpen;
    }

    // Store widget sizes for ghost rectangles (keyed by widget key)
    property var widgetSizes: ({
        "clock": Qt.size(160, 90), "weather": Qt.size(130, 70),
        "system": Qt.size(130, 70), "quote": Qt.size(180, 70),
        "nowPlaying": Qt.size(180, 90), "calendar": Qt.size(200, 180),
        "stock": Qt.size(220, 120)
    })

    function updateWidgetSize(key, w, h) {
        let s = widgetSizes;
        s[key] = Qt.size(w, h);
        widgetSizes = s;
    }

    // ══════════════════════════════════════════════════════════════════
    // ── Widget positioning helper for panel children ──
    // ══════════════════════════════════════════════════════════════════
    component PositionedWidget : Item {
        id: pw
        property string positionKey
        property string defaultPosition
        property bool configVisible: true
        property bool extraVisible: true  // e.g. hasMedia for NowPlaying
        property string screenName: ""  // set by parent PanelWindow

        visible: configVisible
        opacity: (root.widgetsShownForScreen(screenName) && !root.editMode && extraVisible) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

        property string posStr: root.getEffectivePosition(positionKey, defaultPosition)
        property point pos: root.getPosition(posStr, implicitWidth, implicitHeight,
            (parent ? parent.width : 1920), (parent ? parent.height : 1080),
            Root.Config.widgetMarginX, Root.Config.widgetMarginY)
        x: pos.x; y: pos.y
        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    // ══════════════════════════════════════════════════════════════════
    // ── Widget Overlay Panel ──
    // ══════════════════════════════════════════════════════════════════
    Variants {
        model: Root.Config.enableWallpaperWidgets ? Quickshell.screens : []

        PanelWindow {
            id: widgetPanel
            property var modelData
            screen: modelData
            property string panelScreenName: screen?.name ?? ""

            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.namespace: "quickshell-widgets"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            PositionedWidget {
                positionKey: "clockWidgetPosition"
                defaultPosition: Root.Config.clockWidgetPosition
                configVisible: Root.Config.showClockWidget
                screenName: widgetPanel.panelScreenName

                Widgets.ClockWidget {
                    id: clockW
                    timeFormat: Root.Config.clockShowSeconds ? Root.Config.clockTimeFormat.replace("mm", "mm:ss") : Root.Config.clockTimeFormat
                    dateFormat: Root.Config.clockDateFormat
                    showDate: Root.Config.clockShowDate
                    showSeconds: Root.Config.clockShowSeconds
                    clockFontSize: Root.Config.clockFontSize
                    onImplicitWidthChanged: root.updateWidgetSize("clock", implicitWidth, implicitHeight)
                    onImplicitHeightChanged: root.updateWidgetSize("clock", implicitWidth, implicitHeight)
                }
                implicitWidth: clockW.implicitWidth
                implicitHeight: clockW.implicitHeight
            }

            PositionedWidget {
                positionKey: "weatherWidgetPosition"
                defaultPosition: Root.Config.weatherWidgetPosition
                configVisible: Root.Config.showWeatherWidget
                screenName: widgetPanel.panelScreenName

                Widgets.WeatherWidget {
                    id: weatherW
                    weatherService: root.weatherService
                    fontSize: Root.Config.weatherFontSize
                    onImplicitWidthChanged: root.updateWidgetSize("weather", implicitWidth, implicitHeight)
                    onImplicitHeightChanged: root.updateWidgetSize("weather", implicitWidth, implicitHeight)
                }
                implicitWidth: weatherW.implicitWidth
                implicitHeight: weatherW.implicitHeight
            }

            PositionedWidget {
                positionKey: "systemWidgetPosition"
                defaultPosition: Root.Config.systemWidgetPosition
                configVisible: Root.Config.showSystemWidget
                screenName: widgetPanel.panelScreenName

                Widgets.SystemWidget {
                    id: systemW
                    statsService: Core.ServiceManager.systemStats
                    showCpu: Root.Config.systemShowCpu
                    showRam: Root.Config.systemShowRam
                    fontSize: Root.Config.systemFontSize
                    onImplicitWidthChanged: root.updateWidgetSize("system", implicitWidth, implicitHeight)
                    onImplicitHeightChanged: root.updateWidgetSize("system", implicitWidth, implicitHeight)
                }
                implicitWidth: systemW.implicitWidth
                implicitHeight: systemW.implicitHeight
            }

            PositionedWidget {
                positionKey: "quoteWidgetPosition"
                defaultPosition: Root.Config.quoteWidgetPosition
                configVisible: Root.Config.showQuoteWidget
                screenName: widgetPanel.panelScreenName

                Widgets.QuoteWidget {
                    id: quoteW
                    maxWidth: Root.Config.quoteMaxWidth
                    fontSize: Root.Config.quoteFontSize
                    refreshInterval: Root.Config.quoteRefreshInterval
                    onImplicitWidthChanged: root.updateWidgetSize("quote", implicitWidth, implicitHeight)
                    onImplicitHeightChanged: root.updateWidgetSize("quote", implicitWidth, implicitHeight)
                }
                implicitWidth: quoteW.implicitWidth
                implicitHeight: quoteW.implicitHeight
            }

            PositionedWidget {
                positionKey: "nowPlayingWidgetPosition"
                defaultPosition: Root.Config.nowPlayingWidgetPosition
                configVisible: Root.Config.showNowPlayingWidget
                screenName: widgetPanel.panelScreenName
                extraVisible: nowPlayingW.hasMedia

                Widgets.NowPlayingWidget {
                    id: nowPlayingW
                    playerService: root.playerService
                    showArt: Root.Config.nowPlayingShowArt
                    artSize: Root.Config.nowPlayingArtSize
                    fontSize: Root.Config.nowPlayingFontSize
                    onImplicitWidthChanged: root.updateWidgetSize("nowPlaying", implicitWidth, implicitHeight)
                    onImplicitHeightChanged: root.updateWidgetSize("nowPlaying", implicitWidth, implicitHeight)
                }
                implicitWidth: nowPlayingW.implicitWidth
                implicitHeight: nowPlayingW.implicitHeight
            }

            PositionedWidget {
                positionKey: "calendarWidgetPosition"
                defaultPosition: Root.Config.calendarWidgetPosition
                configVisible: Root.Config.showCalendarWidget
                screenName: widgetPanel.panelScreenName

                Widgets.CalendarWidget {
                    id: calendarW
                    showWeekNumbers: Root.Config.calendarShowWeekNumbers
                    cellSize: Root.Config.calendarCellSize
                    onImplicitWidthChanged: root.updateWidgetSize("calendar", implicitWidth, implicitHeight)
                    onImplicitHeightChanged: root.updateWidgetSize("calendar", implicitWidth, implicitHeight)
                }
                implicitWidth: calendarW.implicitWidth
                implicitHeight: calendarW.implicitHeight
            }

            PositionedWidget {
                positionKey: "stockWidgetPosition"
                defaultPosition: Root.Config.stockWidgetPosition
                configVisible: Root.Config.showStockWidget
                screenName: widgetPanel.panelScreenName

                Widgets.StockWidget {
                    id: stockW
                    symbols: Root.Config.stockSymbols
                    fontSize: Root.Config.stockFontSize
                    refreshInterval: Root.Config.stockRefreshInterval
                    onImplicitWidthChanged: root.updateWidgetSize("stock", implicitWidth, implicitHeight)
                    onImplicitHeightChanged: root.updateWidgetSize("stock", implicitWidth, implicitHeight)
                }
                implicitWidth: stockW.implicitWidth
                implicitHeight: stockW.implicitHeight
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

            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.toggleEditMode()
            }

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

                    property real targetWidth: editOverlay.isDragging ? editOverlay.draggedSize.width : 60
                    property real targetHeight: editOverlay.isDragging ? editOverlay.draggedSize.height : 24

                    property point pos: root.getPosition(posName, targetWidth, targetHeight, editOverlay.width, editOverlay.height, Root.Config.widgetMarginX, Root.Config.widgetMarginY)

                    x: pos.x; y: pos.y
                    width: targetWidth; height: targetHeight
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

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

            // Widget drag ghosts — driven by Registry
            Repeater {
                model: Core.Registry.widgets
                Components.DragGhost {
                    required property var modelData
                    visible: Root.Config["show" + modelData.configKey.charAt(0).toUpperCase()
                             + modelData.configKey.slice(1) + "Widget"]
                    widgetName: modelData.key
                    label: modelData.label
                    positionKey: modelData.positionKey
                    widgetSize: root.widgetSizes[modelData.key] || Qt.size(100, 60)
                    overlay: editOverlay
                    widgetRoot: root
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
