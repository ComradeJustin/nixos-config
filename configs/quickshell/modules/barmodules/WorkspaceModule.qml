import QtQuick
import Quickshell.Io
import Niri 0.1
import "../.." as Root

// Workspace indicators with sliding active pill overlay.
// All dots stay the same size. The colored pill slides over the focused one.
Item {
    id: root

    property int maxVisible: 6
    property int dotSize: 6
    property int pillWidth: 16
    property int spacing: Root.Theme.spacingS

    // Account for pill overflow beyond the dot grid
    property int _pillOverflow: Math.max(0, Math.ceil((pillWidth - dotSize) / 2))
    implicitWidth: _pillOverflow + (dotSize + spacing) * Math.max(wsRepeater.count, 1) - spacing + _pillOverflow
    implicitHeight: Root.Theme.barHeight

    Niri {
        id: niri
        Component.onCompleted: {
            connect();
            workspaces.maxCount = root.maxVisible;
        }
        onErrorOccurred: function(error) {
            console.warn("WorkspaceModule: niri error:", error);
        }
    }

    property int focusedIndex: {
        for (let i = 0; i < wsRepeater.count; i++) {
            let item = wsRepeater.itemAt(i);
            if (item && item.isFocused) return i;
        }
        return 0;
    }

    // Pill slides to focused dot position, stretching wider than the dot
    Rectangle {
        id: pill
        width: root.pillWidth
        height: root.dotSize
        radius: root.dotSize / 2
        color: Root.Theme.wsFocused
        anchors.verticalCenter: parent.verticalCenter
        // Center pill on the focused dot within the padded area
        x: root._pillOverflow + root.focusedIndex * (root.dotSize + root.spacing) + root.dotSize / 2 - width / 2
        visible: wsRepeater.count > 0

        Behavior on x {
            NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic }
        }
    }

    // Fixed-position dots — offset by pill overflow
    Row {
        id: dotRow
        x: root._pillOverflow
        spacing: root.spacing
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            id: wsRepeater
            model: niri.workspaces

            Rectangle {
                property bool isFocused: model.isFocused
                property bool isActive: model.isActive

                width: root.dotSize
                height: root.dotSize
                radius: root.dotSize / 2

                color: Root.Theme.textPrimary
                opacity: isFocused ? 0
                       : isActive  ? 0.5
                       :             0.2

                Behavior on opacity {
                    NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: niri.focusWorkspaceById(model.id)
                }
            }
        }
    }

    // Scroll to switch workspaces
    WheelHandler {
        orientation: Qt.Vertical
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real _accum: 0
        onWheel: function(event) {
            _accum += event.angleDelta.y;
            if (Math.abs(_accum) >= 120) {
                let direction = _accum > 0 ? "prev" : "next";
                _accum = 0;
                wsSwitchProc.command = ["niri", "msg", "action", "focus-workspace-" + direction];
                wsSwitchProc.running = true;
            }
            event.accepted = true;
        }
    }

    Process { id: wsSwitchProc }
}
