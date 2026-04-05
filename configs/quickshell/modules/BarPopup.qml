import Quickshell
import Quickshell.Wayland
import QtQuick
import ".." as Root

// Shared popup window that appears below the bar.
// Modules call show(sourceItem, contentItem) / hide().
PanelWindow {
    id: popup
    visible: false

    property Item _sourceItem: null
    property Item _contentItem: null
    property bool _hoveringSelf: false
    property bool _showing: false
    property int barHeight: Root.Theme.barHeight
    property real _targetX: 0

    anchors { top: true }
    margins.top: barHeight + 4
    implicitWidth: _contentItem ? _contentItem.width : 200
    implicitHeight: (_contentItem ? _contentItem.height : 100) + 12
    margins.left: _targetX

    WlrLayershell.namespace: "quickshell-barpopup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    function show(sourceItem, contentItem) {
        _sourceItem = sourceItem;
        if (_contentItem && _contentItem !== contentItem) {
            _contentItem.parent = null;
            _contentItem.visible = false;
        }
        _contentItem = contentItem;
        if (_contentItem) {
            _contentItem.parent = contentHost;
            _contentItem.visible = true;
            _contentItem.x = 0;
            _contentItem.y = 0;
        }
        _updatePosition();
        _hideTimer.stop();
        _showTimer.start();
    }

    function _updatePosition() {
        if (!_sourceItem) return;
        // Map source item center to global coordinates
        let mapped = _sourceItem.mapToGlobal(_sourceItem.width / 2, 0);
        _targetX = Math.max(0, mapped.x - implicitWidth / 2);
    }

    function hide() {
        _showTimer.stop();
        _hideTimer.start();
    }

    function _doHide() {
        if (_hoveringSelf) return;
        visible = false;
        if (_contentItem) {
            _contentItem.parent = null;
            _contentItem.visible = false;
        }
        _sourceItem = null;
        _contentItem = null;
    }

    Timer {
        id: _showTimer
        interval: 350
        onTriggered: {
            popup.visible = true;
            popup._showing = true;
        }
    }

    Timer {
        id: _hideTimer
        interval: 250
        onTriggered: {
            if (popup._hoveringSelf) return;
            popup._showing = false;
            _closeTimer.start();
        }
    }

    // Delay actual hide until fade-out completes
    Timer {
        id: _closeTimer
        interval: Root.Theme.anim.exitDuration
        onTriggered: popup._doHide()
    }

    Item {
        id: contentHost
        anchors.fill: parent
        anchors.topMargin: 6

        opacity: popup._showing ? 1 : 0
        transform: Translate {
            y: popup._showing ? 0 : -8
            Behavior on y {
                NumberAnimation {
                    duration: popup._showing ? Root.Theme.anim.enterDuration : Root.Theme.anim.exitDuration
                    easing.type: popup._showing ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: 0.5
                }
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: popup._showing ? Root.Theme.anim.enterDuration : Root.Theme.anim.exitDuration
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: {
                popup._hoveringSelf = containsMouse;
                if (!containsMouse) popup.hide();
                else {
                    _hideTimer.stop();
                    _closeTimer.stop();
                    popup._showing = true;
                }
            }
        }
    }
}
