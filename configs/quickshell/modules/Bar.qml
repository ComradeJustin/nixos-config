import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".." as Root
import "../components" as Components
import "barmodules" as BarModules
import "../core" as Core

Scope {
    id: barScope

    property bool isHidden: false
    property bool showCava: false
    property var notifRef: null
    property var powerMenuRef: null
    property var playerService: null
    property bool barEditMode: false

    // ── Drag-and-drop state ──
    property bool _dragActive: false
    property string _dragKey: ""
    property string _dragSourceSection: ""
    property string _dropTargetSection: ""
    property int _dropTargetIndex: -1

    // Disabled modules for ghost pool
    property var _disabledModules: {
        let l = Root.Config.bar.layoutLeft;
        let c = Root.Config.bar.layoutCenter;
        let r = Root.Config.bar.layoutRight;
        let enabled = l.concat(c, r);
        let all = Core.Registry.barModules;
        let disabled = [];
        for (let i = 0; i < all.length; i++) {
            if (enabled.indexOf(all[i].key) < 0) disabled.push(all[i]);
        }
        return disabled;
    }

    function toggleBarEdit() { barEditMode = !barEditMode; }

    // Safety: always clean up drag state when leaving edit mode
    onBarEditModeChanged: { if (!barEditMode) _resetDrag(); }

    function _updateDropTarget(x, y) {
        if (y > Root.Theme.barHeight) {
            _dropTargetSection = "disable";
            _dropTargetIndex = -1;
            return;
        }

        let barWidth = bg.width;
        let third = barWidth / 3;
        let section, repeater, layoutKey;
        if (x < third) { section = "left"; repeater = leftRepeater; layoutKey = "layoutLeft"; }
        else if (x > 2 * third) { section = "right"; repeater = rightRepeater; layoutKey = "layoutRight"; }
        else { section = "center"; repeater = centerRepeater; layoutKey = "layoutCenter"; }

        // Compute insertion index, skipping the dragged item's position
        let layout = Root.Config.bar[layoutKey];
        let idx = 0;
        for (let i = 0; i < repeater.count; i++) {
            // Skip the dragged item — it's still in the model but faded out
            if (layout[i] === _dragKey) continue;
            let item = repeater.itemAt(i);
            if (!item) continue;
            let mid = item.mapToItem(bg, item.width / 2, 0).x;
            if (x > mid) idx = i + 1;
        }

        // Adjust: if dragged item is in this section before idx, subtract 1
        // so the index is correct after removal
        let dragIdx = layout.indexOf(_dragKey);
        if (dragIdx >= 0 && dragIdx < idx) idx--;

        _dropTargetSection = section;
        _dropTargetIndex = idx;
    }

    function _handleDrop(x, y) {
        if (!_dragActive || !_dragKey) return;
        _updateDropTarget(x, y);

        // Capture values before resetting — the Repeater may destroy the
        // calling delegate when we touch the layout arrays
        let key = _dragKey;
        let targetSection = _dropTargetSection;
        let targetIdx = _dropTargetIndex;

        // Reset drag state FIRST so visuals clear even if delegate is destroyed
        _resetDrag();

        // Remove from all sections
        let sections = ["layoutLeft", "layoutCenter", "layoutRight"];
        for (let s of sections) {
            let arr = Root.Config.bar[s].slice();
            let idx = arr.indexOf(key);
            if (idx >= 0) {
                arr.splice(idx, 1);
                Root.Config.bar[s] = arr;
            }
        }

        if (targetSection === "disable") {
            Root.Config.save();
            return;
        }

        // Insert into target section
        let prop = "layout" + targetSection.charAt(0).toUpperCase() + targetSection.slice(1);
        let arr = Root.Config.bar[prop].slice();
        arr.splice(Math.min(targetIdx, arr.length), 0, key);
        Root.Config.bar[prop] = arr;
        Root.Config.save();
    }

    function _resetDrag() {
        _dragActive = false;
        _dragKey = "";
        _dragSourceSection = "";
        _dropTargetSection = "";
        _dropTargetIndex = -1;
    }

    onIsHiddenChanged: {
        if (isHidden) {
            zoneReleaseTimer.start();
        } else {
            panel.visible = true;
            zoneRestoreTimer.start();
        }
    }

    Timer { id: zoneReleaseTimer; interval: 220; onTriggered: panel.visible = false }
    Timer { id: zoneRestoreTimer; interval: 220; onTriggered: {} }

    // ── Component map for Repeater-driven bar ──
    Component { id: compPower; BarModules.PowerModule { powerMenuRef: barScope.powerMenuRef } }
    Component { id: compWorkspace; BarModules.WorkspaceModule {} }
    Component { id: compTime; BarModules.TimeModule {} }
    Component { id: compWeather; BarModules.WeatherModule {} }
    Component { id: compWindow; BarModules.WindowModule {} }
    Component { id: compMedia; BarModules.MediaModule { playerService: barScope.playerService; onCavaToggled: barScope.showCava = !barScope.showCava } }
    Component { id: compResource; BarModules.ResourceModule {} }
    Component { id: compAudio; BarModules.AudioModule {} }
    Component { id: compNetwork; BarModules.NetworkModule {} }
    Component { id: compBluetooth; BarModules.BluetoothModule {} }
    Component { id: compBattery; BarModules.BatteryModule {} }
    Component { id: compTray; BarModules.TrayModule { barPanel: panel } }
    Component { id: compGear; BarModules.GearModule { notifRef: barScope.notifRef } }

    property var componentMap: ({
        "power": compPower, "workspace": compWorkspace, "time": compTime,
        "weather": compWeather, "window": compWindow, "media": compMedia,
        "resource": compResource, "audio": compAudio, "network": compNetwork,
        "bluetooth": compBluetooth, "battery": compBattery, "tray": compTray,
        "gear": compGear
    })

    PanelWindow {
        id: panel

        anchors { top: true; left: true; right: true }
        implicitHeight: Root.Theme.barHeight

        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: barScope.isHidden ? 0 : Root.Theme.barHeight

        color: "transparent"

        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                id: bg
                width: parent.width
                height: Root.Theme.barHeight
                color: Root.Theme.barBackground
                y: barScope.isHidden ? -Root.Theme.barHeight : 0
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }

                // ── Left section ──
                Row {
                    id: leftSection
                    height: Root.Theme.barHeight
                    anchors {
                        left: parent.left; leftMargin: Root.Theme.barPadding
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Root.Theme.barSpacing
                    width: Math.min(implicitWidth, centerSection.x - Root.Theme.barPadding - Root.Theme.barSpacing)
                    clip: true

                    Repeater {
                        id: leftRepeater
                        model: Root.Config.bar.layoutLeft
                        delegate: Item {
                            required property string modelData
                            required property int index
                            implicitWidth: barScope.barEditMode
                                ? leftEditGhost.width + (index > 0 ? Root.Theme.barSpacing : 0)
                                : (leftSep.visible ? leftSep.width + Root.Theme.barSpacing + leftLoader.implicitWidth : leftLoader.implicitWidth)
                            implicitHeight: Root.Theme.barHeight
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: (barScope._dragActive && barScope._dragKey === modelData) ? 0.3 : 1.0

                            Components.Separator {
                                id: leftSep; vertical: true
                                visible: {
                                    if (barScope.barEditMode) return false;
                                    if (index === 0) return false;
                                    for (let i = index - 1; i >= 0; i--) {
                                        let prev = leftRepeater.itemAt(i);
                                        if (prev && prev.visible) return true;
                                    }
                                    return false;
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Loader {
                                id: leftLoader
                                visible: !barScope.barEditMode
                                sourceComponent: barScope.componentMap[modelData] || null
                                anchors.verticalCenter: parent.verticalCenter
                                x: leftSep.visible ? leftSep.width + Root.Theme.barSpacing : 0
                            }

                            // Full ghost in edit mode
                            Rectangle {
                                id: leftEditGhost
                                visible: barScope.barEditMode
                                width: leftEditLabel.implicitWidth + 20
                                height: Root.Theme.barHeight - 10
                                x: index > 0 ? Root.Theme.barSpacing : 0
                                anchors.verticalCenter: parent.verticalCenter
                                radius: Root.Theme.radiusSmall
                                color: leftDragMouse.containsMouse && !barScope._dragActive
                                    ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.15)
                                    : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.1)
                                border.width: 1
                                border.color: leftDragMouse.containsMouse && !barScope._dragActive ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                                opacity: 0.8

                                Text {
                                    id: leftEditLabel; anchors.centerIn: parent
                                    text: {
                                        let modules = Core.Registry.barModules;
                                        for (let i = 0; i < modules.length; i++) {
                                            if (modules[i].key === modelData) return modules[i].label;
                                        }
                                        return modelData.charAt(0).toUpperCase() + modelData.slice(1);
                                    }
                                    color: Root.Theme.textPrimary
                                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall; bold: true }
                                }
                            }

                            MouseArea {
                                id: leftDragMouse
                                anchors.fill: parent
                                enabled: barScope.barEditMode
                                hoverEnabled: barScope.barEditMode
                                cursorShape: barScope.barEditMode ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                                propagateComposedEvents: !barScope.barEditMode

                                property point _pressPos
                                property bool _isDragging: false

                                onPressed: function(mouse) {
                                    if (!barScope.barEditMode) { mouse.accepted = false; return; }
                                    _pressPos = Qt.point(mouse.x, mouse.y);
                                    _isDragging = false;
                                }

                                onPositionChanged: function(mouse) {
                                    if (!barScope.barEditMode || !pressed) return;
                                    let dx = mouse.x - _pressPos.x;
                                    let dy = mouse.y - _pressPos.y;
                                    if (!_isDragging && Math.sqrt(dx*dx + dy*dy) > 5) {
                                        _isDragging = true;
                                        barScope._dragActive = true;
                                        barScope._dragKey = modelData;
                                        barScope._dragSourceSection = "left";
                                    }
                                    if (_isDragging) {
                                        let mapped = mapToItem(bg, mouse.x, mouse.y);
                                        dragProxy.x = mapped.x - dragProxy.width / 2;
                                        dragProxy.y = mapped.y - dragProxy.height / 2;
                                        barScope._updateDropTarget(mapped.x, mapped.y);
                                    }
                                }

                                onReleased: function(mouse) {
                                    if (_isDragging) {
                                        let mapped = mapToItem(bg, mouse.x, mouse.y);
                                        barScope._handleDrop(mapped.x, mapped.y);
                                    }
                                    _isDragging = false;
                                    barScope._resetDrag();
                                }

                                onCanceled: {
                                    _isDragging = false;
                                    barScope._resetDrag();
                                }
                            }
                        }
                    }
                }

                // ── Center section ──
                Row {
                    id: centerSection
                    height: Root.Theme.barHeight
                    anchors.centerIn: parent
                    spacing: Root.Theme.barSpacing

                    Repeater {
                        id: centerRepeater
                        model: Root.Config.bar.layoutCenter
                        delegate: Item {
                            required property string modelData
                            required property int index
                            implicitWidth: barScope.barEditMode
                                ? centerEditGhost.width + (index > 0 ? Root.Theme.barSpacing : 0)
                                : (centerSep.visible ? centerSep.width + Root.Theme.barSpacing + centerLoader.implicitWidth : centerLoader.implicitWidth)
                            implicitHeight: Root.Theme.barHeight
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: (barScope._dragActive && barScope._dragKey === modelData) ? 0.3 : 1.0

                            Components.Separator {
                                id: centerSep; vertical: true
                                visible: {
                                    if (barScope.barEditMode) return false;
                                    if (index === 0) return false;
                                    for (let i = index - 1; i >= 0; i--) {
                                        let prev = centerRepeater.itemAt(i);
                                        if (prev && prev.visible) return true;
                                    }
                                    return false;
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Loader {
                                id: centerLoader
                                visible: !barScope.barEditMode
                                sourceComponent: barScope.componentMap[modelData] || null
                                anchors.verticalCenter: parent.verticalCenter
                                x: centerSep.visible ? centerSep.width + Root.Theme.barSpacing : 0
                            }

                            // Full ghost in edit mode
                            Rectangle {
                                id: centerEditGhost
                                visible: barScope.barEditMode
                                width: centerEditLabel.implicitWidth + 20
                                height: Root.Theme.barHeight - 10
                                x: index > 0 ? Root.Theme.barSpacing : 0
                                anchors.verticalCenter: parent.verticalCenter
                                radius: Root.Theme.radiusSmall
                                color: centerDragMouse.containsMouse && !barScope._dragActive
                                    ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.15)
                                    : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.1)
                                border.width: 1
                                border.color: centerDragMouse.containsMouse && !barScope._dragActive ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                                opacity: 0.8

                                Text {
                                    id: centerEditLabel; anchors.centerIn: parent
                                    text: {
                                        let modules = Core.Registry.barModules;
                                        for (let i = 0; i < modules.length; i++) {
                                            if (modules[i].key === modelData) return modules[i].label;
                                        }
                                        return modelData.charAt(0).toUpperCase() + modelData.slice(1);
                                    }
                                    color: Root.Theme.textPrimary
                                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall; bold: true }
                                }
                            }

                            MouseArea {
                                id: centerDragMouse
                                anchors.fill: parent
                                enabled: barScope.barEditMode
                                hoverEnabled: barScope.barEditMode
                                cursorShape: barScope.barEditMode ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                                propagateComposedEvents: !barScope.barEditMode

                                property point _pressPos
                                property bool _isDragging: false

                                onPressed: function(mouse) {
                                    if (!barScope.barEditMode) { mouse.accepted = false; return; }
                                    _pressPos = Qt.point(mouse.x, mouse.y);
                                    _isDragging = false;
                                }

                                onPositionChanged: function(mouse) {
                                    if (!barScope.barEditMode || !pressed) return;
                                    let dx = mouse.x - _pressPos.x;
                                    let dy = mouse.y - _pressPos.y;
                                    if (!_isDragging && Math.sqrt(dx*dx + dy*dy) > 5) {
                                        _isDragging = true;
                                        barScope._dragActive = true;
                                        barScope._dragKey = modelData;
                                        barScope._dragSourceSection = "center";
                                    }
                                    if (_isDragging) {
                                        let mapped = mapToItem(bg, mouse.x, mouse.y);
                                        dragProxy.x = mapped.x - dragProxy.width / 2;
                                        dragProxy.y = mapped.y - dragProxy.height / 2;
                                        barScope._updateDropTarget(mapped.x, mapped.y);
                                    }
                                }

                                onReleased: function(mouse) {
                                    if (_isDragging) {
                                        let mapped = mapToItem(bg, mouse.x, mouse.y);
                                        barScope._handleDrop(mapped.x, mapped.y);
                                    }
                                    _isDragging = false;
                                    barScope._resetDrag();
                                }

                                onCanceled: {
                                    _isDragging = false;
                                    barScope._resetDrag();
                                }
                            }
                        }
                    }
                }

                // ── Right section ──
                Row {
                    id: rightSection
                    height: Root.Theme.barHeight
                    anchors {
                        right: parent.right; rightMargin: Root.Theme.barPadding
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Root.Theme.barSpacing

                    Repeater {
                        id: rightRepeater
                        model: Root.Config.bar.layoutRight
                        delegate: Item {
                            required property string modelData
                            required property int index
                            implicitWidth: barScope.barEditMode
                                ? rightEditGhost.width + (index > 0 ? Root.Theme.barSpacing : 0)
                                : (rightSep.visible ? rightSep.width + Root.Theme.barSpacing + rightLoader.implicitWidth : rightLoader.implicitWidth)
                            implicitHeight: Root.Theme.barHeight
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: (barScope._dragActive && barScope._dragKey === modelData) ? 0.3 : 1.0

                            Components.Separator {
                                id: rightSep; vertical: true
                                visible: {
                                    if (barScope.barEditMode) return false;
                                    if (index === 0) return false;
                                    for (let i = index - 1; i >= 0; i--) {
                                        let prev = rightRepeater.itemAt(i);
                                        if (prev && prev.visible) return true;
                                    }
                                    return false;
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Loader {
                                id: rightLoader
                                visible: !barScope.barEditMode
                                sourceComponent: barScope.componentMap[modelData] || null
                                anchors.verticalCenter: parent.verticalCenter
                                x: rightSep.visible ? rightSep.width + Root.Theme.barSpacing : 0
                            }

                            // Full ghost in edit mode
                            Rectangle {
                                id: rightEditGhost
                                visible: barScope.barEditMode
                                width: rightEditLabel.implicitWidth + 20
                                height: Root.Theme.barHeight - 10
                                x: index > 0 ? Root.Theme.barSpacing : 0
                                anchors.verticalCenter: parent.verticalCenter
                                radius: Root.Theme.radiusSmall
                                color: rightDragMouse.containsMouse && !barScope._dragActive
                                    ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.15)
                                    : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.1)
                                border.width: 1
                                border.color: rightDragMouse.containsMouse && !barScope._dragActive ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                                opacity: 0.8

                                Text {
                                    id: rightEditLabel; anchors.centerIn: parent
                                    text: {
                                        let modules = Core.Registry.barModules;
                                        for (let i = 0; i < modules.length; i++) {
                                            if (modules[i].key === modelData) return modules[i].label;
                                        }
                                        return modelData.charAt(0).toUpperCase() + modelData.slice(1);
                                    }
                                    color: Root.Theme.textPrimary
                                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall; bold: true }
                                }
                            }

                            MouseArea {
                                id: rightDragMouse
                                anchors.fill: parent
                                enabled: barScope.barEditMode
                                hoverEnabled: barScope.barEditMode
                                cursorShape: barScope.barEditMode ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                                propagateComposedEvents: !barScope.barEditMode

                                property point _pressPos
                                property bool _isDragging: false

                                onPressed: function(mouse) {
                                    if (!barScope.barEditMode) { mouse.accepted = false; return; }
                                    _pressPos = Qt.point(mouse.x, mouse.y);
                                    _isDragging = false;
                                }

                                onPositionChanged: function(mouse) {
                                    if (!barScope.barEditMode || !pressed) return;
                                    let dx = mouse.x - _pressPos.x;
                                    let dy = mouse.y - _pressPos.y;
                                    if (!_isDragging && Math.sqrt(dx*dx + dy*dy) > 5) {
                                        _isDragging = true;
                                        barScope._dragActive = true;
                                        barScope._dragKey = modelData;
                                        barScope._dragSourceSection = "right";
                                    }
                                    if (_isDragging) {
                                        let mapped = mapToItem(bg, mouse.x, mouse.y);
                                        dragProxy.x = mapped.x - dragProxy.width / 2;
                                        dragProxy.y = mapped.y - dragProxy.height / 2;
                                        barScope._updateDropTarget(mapped.x, mapped.y);
                                    }
                                }

                                onReleased: function(mouse) {
                                    if (_isDragging) {
                                        let mapped = mapToItem(bg, mouse.x, mouse.y);
                                        barScope._handleDrop(mapped.x, mapped.y);
                                    }
                                    _isDragging = false;
                                    barScope._resetDrag();
                                }

                                onCanceled: {
                                    _isDragging = false;
                                    barScope._resetDrag();
                                }
                            }
                        }
                    }
                }

                // ── Insertion indicator ──
                Rectangle {
                    id: insertIndicator
                    visible: barScope._dragActive && barScope._dropTargetSection !== "" && barScope._dropTargetSection !== "disable"
                    z: 999
                    width: 2; height: Root.Theme.barHeight - 8; radius: 1
                    color: Root.Theme.accentPrimary
                    y: 4

                    x: {
                        if (!visible) return 0;
                        let repeater = barScope._dropTargetSection === "left" ? leftRepeater :
                                       (barScope._dropTargetSection === "center" ? centerRepeater : rightRepeater);
                        let section = barScope._dropTargetSection === "left" ? leftSection :
                                      (barScope._dropTargetSection === "center" ? centerSection : rightSection);
                        let idx = barScope._dropTargetIndex;

                        if (repeater.count === 0) return section.mapToItem(bg, 0, 0).x;
                        if (idx >= repeater.count) {
                            let last = repeater.itemAt(repeater.count - 1);
                            return last ? last.mapToItem(bg, last.width + 2, 0).x : 0;
                        }
                        let item = repeater.itemAt(idx);
                        return item ? item.mapToItem(bg, -4, 0).x : 0;
                    }
                }

                // ── Disable zone overlay ──
                Rectangle {
                    visible: barScope._dragActive && barScope._dropTargetSection === "disable"
                    anchors.fill: parent; z: 998
                    color: Qt.rgba(1, 0.2, 0.2, 0.08)
                }

                // ── Floating drag proxy ──
                Rectangle {
                    id: dragProxy
                    visible: barScope._dragActive
                    z: 1000
                    width: dragProxyLabel.implicitWidth + 24
                    height: Root.Theme.barHeight - 8
                    radius: Root.Theme.radiusSmall
                    color: Root.Theme.barBackground
                    border.width: 2
                    border.color: Root.Theme.accentPrimary
                    scale: 1.05

                    Text {
                        id: dragProxyLabel
                        anchors.centerIn: parent
                        text: {
                            if (!barScope._dragKey) return "";
                            let modules = Core.Registry.barModules;
                            for (let i = 0; i < modules.length; i++) {
                                if (modules[i].key === barScope._dragKey) return modules[i].label;
                            }
                            return barScope._dragKey.charAt(0).toUpperCase() + barScope._dragKey.slice(1);
                        }
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall; bold: true }
                    }
                }
            }
        }
    }

    // ── Edit mode panel with ghost pool (bottom center) ──
    PanelWindow {
        id: editPanel
        visible: barScope.barEditMode

        anchors { bottom: true }
        margins.bottom: 12
        implicitWidth: editContent.width + 24
        implicitHeight: editContent.height + 16

        WlrLayershell.namespace: "quickshell-baredit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: Root.Theme.radiusMedium
            color: Root.Theme.barBackground
            border.width: 1
            border.color: Root.Theme.accentPrimary

            Row {
                id: editContent
                anchors.centerIn: parent
                spacing: 12

                // Ghost pool — disabled modules
                Row {
                    id: ghostPool
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ghostRepeater.count > 0

                    Repeater {
                        id: ghostRepeater
                        model: barScope._disabledModules

                        delegate: Rectangle {
                            required property var modelData
                            width: ghostLabel.implicitWidth + 16
                            height: 24
                            radius: Root.Theme.radiusSmall
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                            color: ghostMouse.containsMouse
                                ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.15)
                                : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.08)
                            border.width: 1
                            border.color: Root.Theme.textDimmed
                            opacity: 0.7

                            Text {
                                id: ghostLabel; anchors.centerIn: parent
                                text: modelData.label
                                color: Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall; italic: true }
                            }

                            MouseArea {
                                id: ghostMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Root.Config.toggleBarModule(modelData.key, modelData.section)
                            }
                        }
                    }
                }

                // Separator between ghost pool and controls
                Components.Separator {
                    visible: ghostPool.visible
                    vertical: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Drag to reorder"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
                }

                Rectangle {
                    width: doneText.implicitWidth + 16; height: 24
                    radius: Root.Theme.radiusSmall
                    anchors.verticalCenter: parent.verticalCenter
                    color: doneMouse.containsMouse ? Root.Theme.accentPrimary : Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.3)

                    Text {
                        id: doneText; anchors.centerIn: parent
                        text: "Done"
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall; bold: true }
                    }
                    MouseArea {
                        id: doneMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: barScope.barEditMode = false
                    }
                }
            }
        }
    }

    // Media popup
    BarModules.MediaPopup {
        showCava: barScope.showCava
        barHidden: barScope.isHidden
    }

    // Fullscreen detection — checks all windows on the bar's screen, not just focused
    property string _barScreenName: panel.screen?.name ?? ""

    Process {
        id: fsProc
        command: [
            "bash", "-c",
            "command -v jq >/dev/null || { echo 0; exit; }; " +
            "BAR_SCREEN=\"$1\"; " +
            "[ -z \"$BAR_SCREEN\" ] && { echo 0; exit; }; " +
            "wsid=$(niri msg -j workspaces 2>/dev/null | jq -r --arg out \"$BAR_SCREEN\" " +
            "  '.[] | select(.is_active and .output == $out) | .id // empty'); " +
            "[ -z \"$wsid\" ] && { echo 0; exit; }; " +
            "o=$(niri msg -j outputs 2>/dev/null) || { echo 0; exit; }; " +
            "ow=$(echo \"$o\" | jq --arg n \"$BAR_SCREEN\" '.[$n].logical.width // 0'); " +
            "oh=$(echo \"$o\" | jq --arg n \"$BAR_SCREEN\" '.[$n].logical.height // 0'); " +
            "fs=$(niri msg -j windows 2>/dev/null | jq --argjson ws \"$wsid\" --argjson ow \"$ow\" --argjson oh \"$oh\" " +
            "  '[.[] | select(.workspace_id == $ws and ((.layout.window_size[0] // 0) | floor) >= ($ow | floor) and ((.layout.window_size[1] // 0) | floor) >= ($oh | floor))] | length'); " +
            "[ \"${fs:-0}\" -gt 0 ] && echo 1 || echo 0",
            "--", barScope._barScreenName
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                barScope.isHidden = data.trim() === "1";
            }
        }

        onExited: fsPollTimer.start()
    }

    Timer { id: fsPollTimer; interval: 350; onTriggered: fsProc.running = true }
}
