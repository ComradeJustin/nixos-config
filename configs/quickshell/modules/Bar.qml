import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Niri 0.1
import ".." as Root
import "../components" as Components
import "barmodules" as BarModules
import "../core" as Core

Scope {
    id: barScope

    property bool isHidden: false
    property bool showCava: false
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

        let layout = Root.Config.bar[layoutKey];
        let idx = 0;
        for (let i = 0; i < repeater.count; i++) {
            if (layout[i] === _dragKey) continue;
            let item = repeater.itemAt(i);
            if (!item) continue;
            let mid = item.mapToItem(bg, item.width / 2, 0).x;
            if (x > mid) idx = i + 1;
        }

        let dragIdx = layout.indexOf(_dragKey);
        if (dragIdx >= 0 && dragIdx < idx) idx--;

        _dropTargetSection = section;
        _dropTargetIndex = idx;
    }

    function _handleDrop(x, y) {
        if (!_dragActive || !_dragKey) return;
        _updateDropTarget(x, y);

        let key = _dragKey;
        let targetSection = _dropTargetSection;
        let targetIdx = _dropTargetIndex;

        _resetDrag();

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

        let prop = "layout" + targetSection.charAt(0).toUpperCase() + targetSection.slice(1);
        let arr = Root.Config.bar[prop].slice();
        arr.splice(Math.min(targetIdx, arr.length), 0, key);
        Root.Config.bar[prop] = arr;
        Root.Config.save();
    }

    function _startDrag(key, section) {
        _dragActive = true;
        _dragKey = key;
        _dragSourceSection = section;
    }

    function _resetDrag() {
        _dragActive = false;
        _dragKey = "";
        _dragSourceSection = "";
        _dropTargetSection = "";
        _dropTargetIndex = -1;
    }

    // exclusiveZone is kept constant so windows never resize when bar hides/shows

    // ── Component map for Repeater-driven bar ──
    // Custom overrides for modules needing special initialization
    Component { id: compMedia; BarModules.MediaModule { cavaOpen: barScope.showCava; onCavaToggled: barScope.showCava = !barScope.showCava } }
    Component { id: compTray; BarModules.TrayModule { barPanel: panel } }

    property var _customOverrides: ({ "media": compMedia, "tray": compTray })

    // Auto-generated from Registry.barModules file paths
    property var componentMap: ({})
    Component.onCompleted: {
        let map = {};
        let mods = Core.Registry.barModules;
        for (let i = 0; i < mods.length; i++) {
            let m = mods[i];
            if (_customOverrides[m.key]) {
                map[m.key] = _customOverrides[m.key];
            } else {
                map[m.key] = Qt.createComponent("../" + m.file);
            }
        }
        componentMap = map;
    }

    property bool isFloating: Root.Config.bar.style === "float"
    property int floatMargin: 6
    property int barTotalHeight: isFloating ? Root.Theme.barHeight + floatMargin * 2 : Root.Theme.barHeight

    // ── Sub-group background computation ──
    // Build a lookup from module key → group name
    property var _groupMap: {
        let map = {};
        let mods = Core.Registry.barModules;
        for (let i = 0; i < mods.length; i++) map[mods[i].key] = mods[i].group;
        return map;
    }

    // Find contiguous runs of same-group modules within a layout array
    function _computeSubGroups(layout, secName) {
        let groups = [];
        if (!layout || layout.length === 0) return groups;
        let gmap = _groupMap;
        let runStart = 0;
        let currentGroup = gmap[layout[0]] || layout[0];
        for (let i = 1; i <= layout.length; i++) {
            let g = i < layout.length ? (gmap[layout[i]] || layout[i]) : null;
            if (g !== currentGroup) {
                groups.push({ startIdx: runStart, endIdx: i - 1, sec: secName });
                runStart = i;
                currentGroup = g;
            }
        }
        return groups;
    }

    // Combined sub-groups across all three sections
    property var _allSubGroups: {
        let l = _computeSubGroups(Root.Config.bar.layoutLeft, "left");
        let c = _computeSubGroups(Root.Config.bar.layoutCenter, "center");
        let r = _computeSubGroups(Root.Config.bar.layoutRight, "right");
        return l.concat(c).concat(r);
    }

    // Delayed show: when detection says "no longer fullscreen", wait
    // a beat so the compositor uncovers the Top-layer bar first, THEN
    // slide the content in. This makes the slide-in visible.
    property bool _barVisible: true
    onIsHiddenChanged: {
        if (isHidden) {
            _barVisible = false;
        } else {
            _barShowDelay.start();
        }
    }
    Timer { id: _barShowDelay; interval: 50; onTriggered: barScope._barVisible = true }

    PanelWindow {
        id: panel

        anchors { top: true; left: true; right: true }
        implicitHeight: barScope.barTotalHeight

        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: barScope.barTotalHeight

        color: "transparent"

        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                id: bg
                width: barScope.isFloating ? parent.width - barScope.floatMargin * 2 : parent.width
                height: Root.Theme.barHeight
                x: barScope.isFloating ? barScope.floatMargin : 0
                color: Root.Theme.barBackground
                radius: barScope.isFloating ? Root.Theme.radiusMedium : 0
                border.width: barScope.isFloating ? Root.Theme.borderWidth : 0
                border.color: Root.Theme.borderColor
                y: barScope._barVisible ? (barScope.isFloating ? barScope.floatMargin : 0) : -barScope.barTotalHeight
                Behavior on y { NumberAnimation { duration: Root.Theme.anim.slideDuration; easing.type: Easing.InOutCubic } }

                // ── Sub-group backgrounds (when showGroups is on) ──
                Repeater {
                    model: barScope._allSubGroups
                    Rectangle {
                        required property var modelData
                        property var _rep: modelData.sec === "left" ? leftRepeater
                                        : (modelData.sec === "center" ? centerRepeater : rightRepeater)
                        property Item _row: modelData.sec === "left" ? leftSection
                                         : (modelData.sec === "center" ? centerSection : rightSection)

                        property var _bounds: {
                            void(_rep.count);
                            let firstX = -1;
                            let lastRight = -1;
                            for (let i = modelData.startIdx; i <= modelData.endIdx; i++) {
                                let item = _rep.itemAt(i);
                                if (!item || !item.contentVisible) continue;
                                let ix = item.x;
                                let iw = item.implicitWidth;
                                if (firstX < 0) firstX = ix;
                                lastRight = ix + iw;
                            }
                            if (firstX < 0) return null;
                            return { x: firstX, w: lastRight - firstX };
                        }

                        visible: Root.Config.bar.showGroups && _bounds !== null
                        x: _bounds ? _row.x + _bounds.x - _hPad : 0
                        width: _bounds ? _bounds.w + _hPad * 2 : 0
                        y: _vPad
                        height: bg.height - _vPad * 2
                        radius: Root.Theme.radiusSmall
                        color: Root.Theme.layer1

                        // No Behavior on x/width here — modules that change
                        // size (WindowModule, MediaModule) already animate
                        // their own implicitWidth.  Adding a second animation
                        // on the group pill creates a visible chase/lag
                        // because the pill reacts one frame late.

                        property int _hPad: 6
                        property int _vPad: 4
                    }
                }

                // ── Left section (scroll = brightness) ──
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

                    WheelHandler {
                        orientation: Qt.Vertical
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            let briSvc = Core.ServiceManager.brightness;
                            if (!briSvc) return;
                            if (event.angleDelta.y > 0) briSvc.increase(5);
                            else if (event.angleDelta.y < 0) briSvc.decrease(5);
                            event.accepted = true;
                        }
                    }

                    Repeater {
                        id: leftRepeater
                        model: Root.Config.bar.layoutLeft
                        delegate: Components.BarSectionDelegate {
                            sectionName: "left"
                            editMode: barScope.barEditMode
                            dragActive: barScope._dragActive
                            dragKey: barScope._dragKey
                            componentMap: barScope.componentMap
                            bgItem: bg
                            dragProxyItem: dragProxy
                            sectionRepeater: leftRepeater
                            onDragStart: (key, section) => barScope._startDrag(key, section)
                            onDragMove: (x, y) => barScope._updateDropTarget(x, y)
                            onDragDrop: (x, y) => barScope._handleDrop(x, y)
                            onDragReset: () => barScope._resetDrag()
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
                        delegate: Components.BarSectionDelegate {
                            sectionName: "center"
                            editMode: barScope.barEditMode
                            dragActive: barScope._dragActive
                            dragKey: barScope._dragKey
                            componentMap: barScope.componentMap
                            bgItem: bg
                            dragProxyItem: dragProxy
                            sectionRepeater: centerRepeater
                            onDragStart: (key, section) => barScope._startDrag(key, section)
                            onDragMove: (x, y) => barScope._updateDropTarget(x, y)
                            onDragDrop: (x, y) => barScope._handleDrop(x, y)
                            onDragReset: () => barScope._resetDrag()
                        }
                    }
                }

                // ── Right section (scroll = volume) ──
                Row {
                    id: rightSection
                    height: Root.Theme.barHeight
                    anchors {
                        right: parent.right; rightMargin: Root.Theme.barPadding
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Root.Theme.barSpacing

                    WheelHandler {
                        orientation: Qt.Vertical
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            let audioSvc = Core.ServiceManager.audio;
                            if (!audioSvc) return;
                            if (event.angleDelta.y > 0) audioSvc.setVolume(audioSvc.volume + 5);
                            else if (event.angleDelta.y < 0) audioSvc.setVolume(audioSvc.volume - 5);
                            event.accepted = true;
                        }
                    }

                    Repeater {
                        id: rightRepeater
                        model: Root.Config.bar.layoutRight
                        delegate: Components.BarSectionDelegate {
                            sectionName: "right"
                            editMode: barScope.barEditMode
                            dragActive: barScope._dragActive
                            dragKey: barScope._dragKey
                            componentMap: barScope.componentMap
                            bgItem: bg
                            dragProxyItem: dragProxy
                            sectionRepeater: rightRepeater
                            onDragStart: (key, section) => barScope._startDrag(key, section)
                            onDragMove: (x, y) => barScope._updateDropTarget(x, y)
                            onDragDrop: (x, y) => barScope._handleDrop(x, y)
                            onDragReset: () => barScope._resetDrag()
                        }
                    }
                }

                // ── Section separators ──
                // Subtle dots between left|center and center|right groups.
                // Only visible when showGroups is off (groups already provide
                // visual hierarchy) and the flanking sections have content.
                Repeater {
                    model: [
                        { left: leftSection, right: centerSection },
                        { left: centerSection, right: rightSection }
                    ]

                    Rectangle {
                        required property var modelData
                        property Item leftSec: modelData.left
                        property Item rightSec: modelData.right

                        visible: !Root.Config.bar.showGroups
                                 && leftSec.implicitWidth > 0
                                 && rightSec.implicitWidth > 0
                        width: 3; height: 3; radius: 1.5
                        color: Root.Theme.textDimmed
                        opacity: 0.3
                        anchors.verticalCenter: parent.verticalCenter
                        x: {
                            let lRight = leftSec.x + leftSec.implicitWidth;
                            let rLeft = rightSec.x;
                            return (lRight + rLeft) / 2 - 1;
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
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: barScope.barEditMode = false
        }

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

    // Shared hover popup window for bar modules
    BarPopup {
        id: barPopup
        barHeight: barScope.barTotalHeight
        Component.onCompleted: Core.ServiceManager.barPopup = barPopup
    }

    // ── Shared tooltip window (renders outside bar clip) ──
    PanelWindow {
        id: barTooltipWindow
        visible: false
        color: "transparent"

        anchors { top: true }
        margins.top: barScope.barTotalHeight + 4
        margins.left: _tipX
        implicitWidth: _tipLabel.implicitWidth + 16
        implicitHeight: _tipLabel.implicitHeight + 10

        WlrLayershell.namespace: "quickshell-tooltip"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        property real _tipX: 0
        property string _tipText: ""
        property bool _showing: false

        function show(sourceItem, text) {
            if (!text || text.length === 0) return;
            _tipText = text;
            let mapped = sourceItem.mapToGlobal(sourceItem.width / 2, 0);
            _tipX = Math.max(4, mapped.x - implicitWidth / 2);
            _showDelay.restart();
        }

        function hide() {
            _showDelay.stop();
            _showing = false;
            _closeDelay.start();
        }

        Timer { id: _showDelay; interval: 400; onTriggered: { barTooltipWindow.visible = true; barTooltipWindow._showing = true; } }
        Timer { id: _closeDelay; interval: 150; onTriggered: { if (!barTooltipWindow._showing) barTooltipWindow.visible = false; } }

        Rectangle {
            anchors.fill: parent
            radius: Root.Theme.radiusSmall
            color: Root.Theme.layer2
            border.width: 1
            border.color: Root.Theme.borderColor
            opacity: barTooltipWindow._showing ? 1 : 0
            scale: barTooltipWindow._showing ? 1 : 0.95
            transformOrigin: Item.Top

            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic } }

            Text {
                id: _tipLabel
                anchors.centerIn: parent
                text: barTooltipWindow._tipText
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: 11 }
            }
        }

        Component.onCompleted: Core.ServiceManager.barTooltip = barTooltipWindow
    }

    // Media popup
    BarModules.MediaPopup {
        showCava: barScope.showCava
        barHidden: barScope.isHidden
    }

    // ── Fullscreen detection (cosmetic animation) ──
    // Bar is at WlrLayer.Top so input blocking is handled by the
    // compositor. This detection only drives the slide animation.
    // A pending flag prevents the race where focusedWindowChanged
    // fires while the check process is still running.
    Niri {
        id: barNiri
        Component.onCompleted: connect()
        onFocusedWindowChanged: barScope._requestFsCheck()
    }

    property int _screenW: panel.screen?.width ?? 0
    property int _screenH: panel.screen?.height ?? 0
    property bool _fsPending: false

    function _requestFsCheck() {
        if (fsCheckProc.running) {
            _fsPending = true;
        } else {
            fsCheckProc.running = true;
        }
    }

    Process {
        id: fsCheckProc
        command: ["niri", "msg", "-j", "focused-window"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                try {
                    var w = JSON.parse(data);
                    var sz = w.layout && w.layout.window_size ? w.layout.window_size : [0, 0];
                    barScope.isHidden = (sz[0] >= barScope._screenW && sz[1] >= barScope._screenH);
                } catch(e) {
                    barScope.isHidden = false;
                }
            }
        }

        onExited: {
            if (barScope._fsPending) {
                barScope._fsPending = false;
                fsCheckProc.running = true;
            } else {
                fsPollTimer.start();
            }
        }
    }

    Timer { id: fsPollTimer; interval: 500; onTriggered: barScope._requestFsCheck() }
}
