import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import ".." as Root
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
            if (isValidPosition(savedPositions[key]))
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

    Component.onCompleted: {
        loadProc.running = true;

        // Auto-generate widget component map from Registry file paths
        let map = {};
        let ws = Core.Registry.widgets;
        for (let i = 0; i < ws.length; i++) {
            map[ws[i].key] = Qt.createComponent("../" + ws[i].file);
        }
        widgetComponentMap = map;
    }

    Process {
        id: loadProc
        command: ["cat", Root.Theme.homeDir + "/.cache/quickshell-widget-positions"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split("=");
                if (parts.length === 2) {
                    let widget = parts[0].trim();
                    let pos = parts[1].trim();
                    if (root.isValidPosition(pos)) {
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

    // ── Grid ──
    // Widgets snap their top-left to a cols×rows grid (clamped on-screen). A
    // position string is either a grid cell "col,row" (user-placed) or one of
    // the legacy named anchors (still used as Registry defaults).
    property int gridCols: 12
    property int gridRows: 6

    // Grid intersection points (for the edit-mode dot overlay).
    readonly property var _gridDots: {
        let d = [];
        for (let c = 0; c <= gridCols; c++)
            for (let r = 0; r <= gridRows; r++)
                d.push({ c: c, r: r });
        return d;
    }

    function isValidPosition(p) {
        return validPositions.indexOf(p) !== -1 || /^\d+,\d+$/.test(p);
    }

    function gridPoint(col, row, itemWidth, itemHeight, areaWidth, areaHeight, marginX, marginY) {
        let top = marginY + Root.Theme.barHeight;
        let usableW = Math.max(1, areaWidth - 2 * marginX);
        let usableH = Math.max(1, areaHeight - top - marginY);
        let x = marginX + (col / gridCols) * usableW;
        let y = top + (row / gridRows) * usableH;
        // Clamp so the widget never spills off-screen.
        x = Math.max(marginX, Math.min(x, areaWidth - itemWidth - marginX));
        y = Math.max(top, Math.min(y, areaHeight - itemHeight - marginY));
        return Qt.point(x, y);
    }

    function getPosition(posStr, itemWidth, itemHeight, areaWidth, areaHeight, marginX, marginY) {
        // Grid cell "col,row"
        if (posStr && posStr.indexOf(",") !== -1) {
            let parts = posStr.split(",");
            let c = parseInt(parts[0]), r = parseInt(parts[1]);
            if (!isNaN(c) && !isNaN(r))
                return gridPoint(c, r, itemWidth, itemHeight, areaWidth, areaHeight, marginX, marginY);
        }
        // Legacy named anchor (Registry defaults)
        let x = 0, y = 0;
        if (posStr.indexOf("left") !== -1) x = marginX;
        else if (posStr.indexOf("right") !== -1) x = areaWidth - itemWidth - marginX;
        else x = (areaWidth - itemWidth) / 2;

        if (posStr.indexOf("top") !== -1) y = marginY + Root.Theme.barHeight;
        else if (posStr.indexOf("bottom") !== -1) y = areaHeight - itemHeight - marginY;
        else y = (areaHeight - itemHeight) / 2;

        return Qt.point(x, y);
    }

    // Nearest grid cell to a dragged top-left position → "col,row".
    function findSnapPosition(x, y, itemWidth, itemHeight, areaWidth, areaHeight) {
        let marginX = Root.Config.widgets.marginX;
        let marginY = Root.Config.widgets.marginY;
        let best = "0,0";
        let bestDist = Infinity;
        for (let c = 0; c <= gridCols; c++) {
            for (let r = 0; r <= gridRows; r++) {
                let t = gridPoint(c, r, itemWidth, itemHeight, areaWidth, areaHeight, marginX, marginY);
                let d = Math.pow(x - t.x, 2) + Math.pow(y - t.y, 2);
                if (d < bestDist) { bestDist = d; best = c + "," + r; }
            }
        }
        return best;
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

    // Place the dragged widget at the target grid cell. With a grid there are
    // plenty of cells, so we simply place it (no occupant swap).
    function handleSwap(droppedKey, targetPosition, originPosition) {
        let fresh = Object.assign({}, preDragSnapshot);
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
        Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.exitDuration; easing.type: Easing.InOutQuad } }

        property string posStr: root.getEffectivePosition(positionKey, defaultPosition)
        property point pos: root.getPosition(posStr, implicitWidth, implicitHeight,
            (parent ? parent.width : 1920), (parent ? parent.height : 1080),
            Root.Config.widgets.marginX, Root.Config.widgets.marginY)
        x: pos.x; y: pos.y
        Behavior on x { NumberAnimation { duration: Root.Theme.anim.exitDuration; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Root.Theme.anim.exitDuration; easing.type: Easing.OutCubic } }
    }

    // Auto-generated from Registry.widgets file paths — each widget
    // reads its own config from Root.Config internally, so no property
    // bindings are needed here. Adding a new widget requires only:
    //   1. Create the QML file in widgets/
    //   2. Add a Registry entry with a `file` path
    property var widgetComponentMap: ({})

    // (screen × widget) pairs — one PanelWindow each. Recomputes when the
    // wallpaper-widgets feature toggles or the screen list changes.
    readonly property var _screenWidgetPairs: {
        if (!Root.Config.features.wallpaperWidgets) return [];
        let pairs = [];
        let ws = Core.Registry.widgets;
        let scr = Quickshell.screens;
        for (let s = 0; s < scr.length; s++)
            for (let i = 0; i < ws.length; i++)
                pairs.push({ screen: scr[s], widget: ws[i] });
        return pairs;
    }

    // ══════════════════════════════════════════════════════════════════
    // ── Widget Overlay — one layer surface PER widget ──
    // Each enabled widget gets its own small PanelWindow, sized to the widget
    // and anchored top-left with the snap position applied as margins. Being
    // individual *sized* surfaces lets niri's layer-rule blur scope to each
    // widget (glass), instead of one full-screen surface blurring the whole
    // backdrop. Disabled/hidden widgets simply leave their surface unmapped.
    // ══════════════════════════════════════════════════════════════════
    Variants {
        model: root._screenWidgetPairs

        PanelWindow {
            id: widgetPanel
            required property var modelData
            readonly property var widgetDef: modelData.widget
            screen: modelData.screen
            property string panelScreenName: screen ? screen.name : ""

            WlrLayershell.namespace: "quickshell-widgets"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            // Anchor to the top-left corner; the snap position is applied as
            // margins so the surface floats exactly where the widget belongs.
            anchors { top: true; left: true }

            readonly property string posStr: root.getEffectivePosition(
                widgetDef.positionKey,
                Root.Config.widgets[widgetDef.configKey + "Position"] || widgetDef.defaultPos)
            readonly property point pos: root.getPosition(
                posStr, implicitWidth, implicitHeight,
                screen ? screen.width : 1920, screen ? screen.height : 1080,
                Root.Config.widgets.marginX, Root.Config.widgets.marginY)
            margins.left: pos.x
            margins.top: pos.y
            Behavior on margins.left { NumberAnimation { duration: Root.Theme.anim.exitDuration; easing.type: Easing.OutCubic } }
            Behavior on margins.top  { NumberAnimation { duration: Root.Theme.anim.exitDuration; easing.type: Easing.OutCubic } }

            implicitWidth: widgetLoader.item ? widgetLoader.item.implicitWidth : 1
            implicitHeight: widgetLoader.item ? widgetLoader.item.implicitHeight : 1

            readonly property bool extraVisible: widgetLoader.item
                ? (widgetLoader.item.hasMedia !== undefined ? widgetLoader.item.hasMedia : true)
                : true
            visible: (Root.Config.widgets[widgetDef.configKey] || false)
                     && !!widgetLoader.item
                     && extraVisible
                     && root.widgetsShownForScreen(panelScreenName)
                     && !root.editMode

            Loader {
                id: widgetLoader
                sourceComponent: root.widgetComponentMap[widgetPanel.widgetDef.key] || null
            }

            Connections {
                target: widgetLoader.item
                function onImplicitWidthChanged() { root.updateWidgetSize(widgetPanel.widgetDef.key, widgetLoader.item.implicitWidth, widgetLoader.item.implicitHeight) }
                function onImplicitHeightChanged() { root.updateWidgetSize(widgetPanel.widgetDef.key, widgetLoader.item.implicitWidth, widgetLoader.item.implicitHeight) }
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

            // Grid dots — faint intersection markers shown while dragging.
            Repeater {
                model: root._gridDots
                Rectangle {
                    required property var modelData
                    readonly property real _mx: Root.Config.widgets.marginX
                    readonly property real _top: Root.Config.widgets.marginY + Root.Theme.barHeight
                    readonly property real _usableW: editOverlay.width - 2 * _mx
                    readonly property real _usableH: editOverlay.height - _top - Root.Config.widgets.marginY
                    x: _mx + (modelData.c / root.gridCols) * _usableW - width / 2
                    y: _top + (modelData.r / root.gridRows) * _usableH - height / 2
                    width: 4; height: 4; radius: 2
                    color: Root.Theme.textDimmed
                    opacity: editOverlay.isDragging ? 0.35 : 0
                    Behavior on opacity { NumberAnimation { duration: Root.Theme.animFast } }
                }
            }

            // Snap-target highlight — where the dragged widget will land.
            Rectangle {
                id: snapTarget
                visible: editOverlay.isDragging && editOverlay.nearestSnap !== ""
                property point gp: root.getPosition(editOverlay.nearestSnap,
                    editOverlay.draggedSize.width, editOverlay.draggedSize.height,
                    editOverlay.width, editOverlay.height,
                    Root.Config.widgets.marginX, Root.Config.widgets.marginY)
                x: gp.x; y: gp.y
                width: editOverlay.draggedSize.width
                height: editOverlay.draggedSize.height
                radius: Root.Theme.radiusMedium
                color: Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.15)
                border.width: 2
                border.color: Root.Theme.textAccent
                Behavior on x { NumberAnimation { duration: Root.Theme.animFast; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: Root.Theme.animFast; easing.type: Easing.OutCubic } }
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
                    anchors.centerIn: parent; spacing: Root.Theme.spacingL

                    Rectangle {
                        width: 90; height: 32; radius: Root.Theme.radiusSmall
                        color: saveMA.containsMouse ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.2) : "transparent"
                        border.width: 1; border.color: Root.Theme.textAccent
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: Root.Icons.save; color: Root.Theme.textAccent; font.family: Root.Theme.fontIcons; font.pixelSize: Root.Theme.fontSizeXL }
                            Text { text: "Save"; color: Root.Theme.textAccent; font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM; bold: true } }
                        }
                        MouseArea { id: saveMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.commit() }
                    }

                    Rectangle {
                        width: 90; height: 32; radius: Root.Theme.radiusSmall
                        color: cancelMA.containsMouse ? Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.2) : "transparent"
                        border.width: 1; border.color: Root.Theme.textDimmed
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: Root.Icons.cancel; color: Root.Theme.textDimmed; font.family: Root.Theme.fontIcons; font.pixelSize: Root.Theme.fontSizeXL }
                            Text { text: "Cancel"; color: Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM } }
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
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeL }
                opacity: 0.7
            }
        }
    }
}
