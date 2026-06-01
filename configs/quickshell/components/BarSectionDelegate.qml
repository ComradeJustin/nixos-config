import QtQuick
import ".." as Root
import "../core" as Core

Item {
    id: delegate

    // From Repeater
    required property string modelData
    required property int index

    // Injected context
    property string sectionName: ""
    property bool editMode: false
    property bool dragActive: false
    property string dragKey: ""
    property var componentMap: ({})
    property Item bgItem: null
    property Item dragProxyItem: null
    property var sectionRepeater: null

    // Drag callbacks (set by Bar.qml)
    property var onDragStart: null   // function(key, section)
    property var onDragMove: null    // function(globalX, globalY)
    property var onDragDrop: null    // function(globalX, globalY)
    property var onDragReset: null   // function()

    // Whether the loaded module has visible content with actual width
    readonly property bool contentVisible: !editMode && loader.item !== null && loader.item.visible && loader.item.implicitWidth > 0

    implicitWidth: editMode
        ? editGhost.width + (index > 0 ? Root.Theme.barSpacing : 0)
        : (contentVisible ? (sep.visible ? sep.width + Root.Theme.barSpacing + loader.implicitWidth : loader.implicitWidth) : 0)
    implicitHeight: Root.Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    opacity: (dragActive && dragKey === modelData) ? 0.3 : _entranceOpacity

    // Staggered entrance animation — each module fades in 40ms after the previous
    property real _entranceOpacity: 0
    Component.onCompleted: entranceTimer.start()
    Timer {
        id: entranceTimer
        interval: 40 * delegate.index
        onTriggered: entranceAnim.start()
    }
    NumberAnimation {
        id: entranceAnim
        target: delegate
        property: "_entranceOpacity"
        from: 0; to: 1
        duration: Root.Theme.anim.exitDuration
        easing.type: Easing.OutCubic
    }

    Separator {
        id: sep; vertical: true
        visible: {
            if (delegate.editMode) return false;
            if (delegate.index === 0) return false;
            if (!delegate.contentVisible) return false;
            // Hide separators when group backgrounds are showing
            if (Root.Config.bar.showGroups) return false;
            let rep = delegate.sectionRepeater;
            if (!rep) return false;
            for (let i = delegate.index - 1; i >= 0; i--) {
                let prev = rep.itemAt(i);
                if (prev && prev.contentVisible) return true;
            }
            return false;
        }
        anchors.verticalCenter: parent.verticalCenter
    }

    Loader {
        id: loader
        visible: !delegate.editMode
        sourceComponent: delegate.componentMap[delegate.modelData] || null
        anchors.verticalCenter: parent.verticalCenter
        x: sep.visible ? sep.width + Root.Theme.barSpacing : 0
    }

    Rectangle {
        id: editGhost
        visible: delegate.editMode
        width: editLabel.implicitWidth + 20
        height: Root.Theme.barHeight - 10
        x: delegate.index > 0 ? Root.Theme.barSpacing : 0
        anchors.verticalCenter: parent.verticalCenter
        radius: Root.Theme.radiusSmall
        color: dragMouse.containsMouse && !delegate.dragActive
            ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.15)
            : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.1)
        border.width: 1
        border.color: dragMouse.containsMouse && !delegate.dragActive ? Root.Theme.accentPrimary : Root.Theme.textDimmed
        opacity: 0.8

        Text {
            id: editLabel; anchors.centerIn: parent
            text: {
                let modules = Core.Registry.barModules;
                for (let i = 0; i < modules.length; i++) {
                    if (modules[i].key === delegate.modelData) return modules[i].label;
                }
                return delegate.modelData.charAt(0).toUpperCase() + delegate.modelData.slice(1);
            }
            color: Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall; bold: true }
        }
    }

    MouseArea {
        id: dragMouse
        anchors.fill: parent
        enabled: delegate.editMode
        hoverEnabled: delegate.editMode
        cursorShape: delegate.editMode ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
        propagateComposedEvents: !delegate.editMode

        property point _pressPos
        property bool _isDragging: false

        onPressed: function(mouse) {
            if (!delegate.editMode) { mouse.accepted = false; return; }
            _pressPos = Qt.point(mouse.x, mouse.y);
            _isDragging = false;
        }

        onPositionChanged: function(mouse) {
            if (!delegate.editMode || !pressed) return;
            let dx = mouse.x - _pressPos.x;
            let dy = mouse.y - _pressPos.y;
            if (!_isDragging && Math.sqrt(dx*dx + dy*dy) > 5) {
                _isDragging = true;
                if (delegate.onDragStart) delegate.onDragStart(delegate.modelData, delegate.sectionName);
            }
            if (_isDragging && delegate.bgItem) {
                let mapped = mapToItem(delegate.bgItem, mouse.x, mouse.y);
                if (delegate.dragProxyItem) {
                    delegate.dragProxyItem.x = mapped.x - delegate.dragProxyItem.width / 2;
                    delegate.dragProxyItem.y = mapped.y - delegate.dragProxyItem.height / 2;
                }
                if (delegate.onDragMove) delegate.onDragMove(mapped.x, mapped.y);
            }
        }

        onReleased: function(mouse) {
            if (_isDragging && delegate.bgItem) {
                let mapped = mapToItem(delegate.bgItem, mouse.x, mouse.y);
                if (delegate.onDragDrop) delegate.onDragDrop(mapped.x, mapped.y);
            }
            _isDragging = false;
            if (delegate.onDragReset) delegate.onDragReset();
        }

        onCanceled: {
            _isDragging = false;
            if (delegate.onDragReset) delegate.onDragReset();
        }
    }
}
