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

    property bool editMode: false
    signal editModeToggled(bool enabled)

    property var savedPositions: ({})    // persisted to disk
    property var editPositions: ({})     // uncommitted edit-mode changes

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
        if (!editMode) editPositions = {};
        editModeToggled(editMode);
    }

    function commit() {
        Object.assign(savedPositions, editPositions);
        savedPositions = Object.assign({}, savedPositions);

        let lines = [];
        for (let key in savedPositions) {
            if (validPositions.indexOf(savedPositions[key]) !== -1)
                lines.push(key + "=" + savedPositions[key]);
        }

        if (lines.length > 0) {
            let path = Root.Theme.homeDir + "/.cache/quickshell-widget-positions";
            saveProc.command = ["sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"", "--", lines.join("\n"), path];
            saveProc.running = true;
        }

        editPositions = {};
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
                        root.savedPositions[widget] = pos;
                    }
                }
            }
        }
        onExited: {
            root.savedPositions = Object.assign({}, root.savedPositions);
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
        let marginX = Root.Config.widgets.marginX;
        let marginY = Root.Config.widgets.marginY;
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
        return editPositions[widgetName] || savedPositions[widgetName] || configPos;
    }

    // ── Swap Logic ──
    // Snapshot of editPositions taken at drag start, so mid-drag
    // hover-swaps always reset to the pre-drag state before applying.
    property var preDragSnapshot: ({})

    function beginDrag(droppedKey) {
        preDragSnapshot = Object.assign({}, editPositions);
    }

    // Swap: occupant goes to the dragged widget's pre-drag position.
    // Each call rebuilds from preDragSnapshot so only one swap is active.
    function handleSwap(droppedKey, targetPosition, originPosition) {
        let origin = originPosition;
        let fresh = Object.assign({}, preDragSnapshot);

        // Find which widget occupies the target in the pre-drag state
        for (let key of allWidgetKeys) {
            if (key !== droppedKey) {
                let pos = fresh[key] || savedPositions[key] || getDefaultPosition(key);
                if (pos === targetPosition) {
                    fresh[key] = origin;
                    break;
                }
            }
        }
        fresh[droppedKey] = targetPosition;
        editPositions = fresh;
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
        if (root.editMode || !Root.Config.features.autoHideWidgets) return true;
        let ws = Core.ServiceManager.window;
        if (!ws) return true;
        return ws.screenEmpty(screenName) && !ws.overviewOpen;
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
            Root.Config.widgets.marginX, Root.Config.widgets.marginY)
        x: pos.x; y: pos.y
        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    // ── Widget Component definitions (config bindings baked in) ──
    Component { id: compClock; Widgets.ClockWidget {
        timeFormat: Root.Config.clockConfig.showSeconds ? Root.Config.clockConfig.timeFormat.replace("mm", "mm:ss") : Root.Config.clockConfig.timeFormat
        dateFormat: Root.Config.clockConfig.dateFormat
        showDate: Root.Config.clockConfig.showDate
        showSeconds: Root.Config.clockConfig.showSeconds
        clockFontSize: Root.Config.clockConfig.fontSize
    }}
    Component { id: compWeather; Widgets.WeatherWidget {
        weatherService: Core.ServiceManager.weather
        fontSize: Root.Config.weatherConfig.fontSize
    }}
    Component { id: compSystem; Widgets.SystemWidget {
        statsService: Core.ServiceManager.systemStats
        showCpu: Root.Config.systemConfig.showCpu
        showRam: Root.Config.systemConfig.showRam
        fontSize: Root.Config.systemConfig.fontSize
    }}
    Component { id: compQuote; Widgets.QuoteWidget {
        maxWidth: Root.Config.quoteConfig.maxWidth
        fontSize: Root.Config.quoteConfig.fontSize
        refreshInterval: Root.Config.quoteConfig.refreshInterval
    }}
    Component { id: compNowPlaying; Widgets.NowPlayingWidget {
        playerService: Core.ServiceManager.player
        showArt: Root.Config.nowPlayingConfig.showArt
        artSize: Root.Config.nowPlayingConfig.artSize
        fontSize: Root.Config.nowPlayingConfig.fontSize
    }}
    Component { id: compCalendar; Widgets.CalendarWidget {
        showWeekNumbers: Root.Config.calendarConfig.showWeekNumbers
        cellSize: Root.Config.calendarConfig.cellSize
    }}
    Component { id: compStock; Widgets.StockWidget {
        symbols: Root.Config.stockConfig.symbols
        fontSize: Root.Config.stockConfig.fontSize
        refreshInterval: Root.Config.stockConfig.refreshInterval
    }}

    property var widgetComponentMap: ({
        "clock": compClock,
        "weather": compWeather,
        "system": compSystem,
        "quote": compQuote,
        "nowPlaying": compNowPlaying,
        "calendar": compCalendar,
        "stock": compStock
    })

    // ══════════════════════════════════════════════════════════════════
    // ── Widget Overlay Panel ──
    // ══════════════════════════════════════════════════════════════════
    Variants {
        model: Root.Config.features.wallpaperWidgets ? Quickshell.screens : []

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

            // Data-driven widget instantiation from Registry
            Repeater {
                model: Core.Registry.widgets
                PositionedWidget {
                    required property var modelData
                    positionKey: modelData.positionKey
                    defaultPosition: Root.Config.widgets[modelData.configKey + "Position"] || modelData.defaultPos
                    configVisible: Root.Config.widgets[modelData.configKey] || false
                    screenName: widgetPanel.panelScreenName
                    extraVisible: widgetLoader.item
                        ? (widgetLoader.item.hasMedia !== undefined ? widgetLoader.item.hasMedia : true)
                        : true

                    implicitWidth: widgetLoader.item ? widgetLoader.item.implicitWidth : 0
                    implicitHeight: widgetLoader.item ? widgetLoader.item.implicitHeight : 0

                    Loader {
                        id: widgetLoader
                        sourceComponent: root.widgetComponentMap[modelData.key] || null
                    }

                    Connections {
                        target: widgetLoader.item
                        function onImplicitWidthChanged() { root.updateWidgetSize(modelData.key, widgetLoader.item.implicitWidth, widgetLoader.item.implicitHeight) }
                        function onImplicitHeightChanged() { root.updateWidgetSize(modelData.key, widgetLoader.item.implicitWidth, widgetLoader.item.implicitHeight) }
                    }
                }
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
                Keys.onReturnPressed: root.commit()
                Keys.onEnterPressed: root.commit()
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

                    property point pos: root.getPosition(posName, targetWidth, targetHeight, editOverlay.width, editOverlay.height, Root.Config.widgets.marginX, Root.Config.widgets.marginY)

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
                    visible: Root.Config.widgets[modelData.configKey] || false
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
                            Text { text: Root.Icons.save; color: Root.Theme.textAccent; font.family: Root.Theme.fontFamily; font.pixelSize: 14 }
                            Text { text: "Save"; color: Root.Theme.textAccent; font { family: Root.Theme.fontFamily; pixelSize: 12; bold: true } }
                        }
                        MouseArea { id: saveMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.commit() }
                    }

                    Rectangle {
                        width: 90; height: 32; radius: Root.Theme.radiusSmall
                        color: cancelMA.containsMouse ? Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.2) : "transparent"
                        border.width: 1; border.color: Root.Theme.textDimmed
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: Root.Icons.cancel; color: Root.Theme.textDimmed; font.family: Root.Theme.fontFamily; font.pixelSize: 14 }
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
