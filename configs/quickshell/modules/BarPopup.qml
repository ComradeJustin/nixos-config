import Quickshell
import Quickshell.Wayland
import QtQuick
import ".." as Root

// Shared popup window for bar modules — click-to-toggle.
// Modules call toggle(sourceItem, contentItem) to open/close.
// Escape dismisses. Clicking same module toggles off; clicking
// a different module switches content.
PanelWindow {
    id: popup
    visible: false

    property Item _sourceItem: null
    property Item _contentItem: null
    property bool _showing: false
    property int barHeight: Root.Theme.barHeight
    property real _targetX: 0

    anchors { top: true }
    margins.top: barHeight + 4
    implicitWidth: _contentItem ? _contentItem.width : 200
    implicitHeight: (_contentItem ? _contentItem.height : 100) + 4
    margins.left: _targetX

    WlrLayershell.namespace: "quickshell-barpopup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Toggle popup for a source. Same source while showing = close.
    // Different source = switch content.
    function toggle(sourceItem, contentItem) {
        if (_sourceItem === sourceItem && _showing) {
            dismiss();
            return;
        }
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
        _closeTimer.stop();
        visible = true;
        _showing = true;
    }

    // Close unconditionally
    function dismiss() {
        _showing = false;
        _closeTimer.start();
    }

    // Close only if the popup is currently showing for this source — used when a
    // module's content disappears (e.g. media stops) so a stale popup doesn't
    // linger with nothing to anchor to.
    function dismissFor(sourceItem) {
        if (_sourceItem === sourceItem && _showing) dismiss();
    }

    function _updatePosition() {
        if (!_sourceItem) return;
        let mapped = _sourceItem.mapToGlobal(_sourceItem.width / 2, 0);
        _targetX = Math.max(0, mapped.x - implicitWidth / 2);
    }

    function _doHide() {
        visible = false;
        if (_contentItem) {
            _contentItem.parent = null;
            _contentItem.visible = false;
        }
        _sourceItem = null;
        _contentItem = null;
    }

    // Delay actual hide until fade-out animation completes
    Timer {
        id: _closeTimer
        interval: Root.Theme.anim.exitDuration
        onTriggered: popup._doHide()
    }

    Item {
        id: contentHost
        anchors.fill: parent
        anchors.topMargin: 2

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
    }

    // Escape key closes popup
    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: popup.dismiss()
    }
}
