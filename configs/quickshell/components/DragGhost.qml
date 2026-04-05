import QtQuick
import ".." as Root

// Draggable ghost rectangle for widget edit mode
Rectangle {
    id: ghost

    property string widgetName
    property string label: ""
    property string positionKey: widgetName + "WidgetPosition"
    property size widgetSize: Qt.size(160, 90)
    property var overlay: null  // Reference to edit overlay panel
    property var widgetRoot: null  // Reference to WidgetOverlay root Scope

    width: widgetSize.width
    height: widgetSize.height
    radius: Root.Theme.widgetRadius
    color: Root.Theme.widgetBackground
    border.width: 2
    border.color: dragArea.drag.active ? Root.Theme.textAccent : Root.Theme.editModeBorder

    property string posStr: widgetRoot ? widgetRoot.getEffectivePosition(positionKey, "") : ""
    property point targetPos: {
        if (!overlay || !widgetRoot) return Qt.point(0, 0);
        return widgetRoot.getPosition(posStr, width, height, overlay.width, overlay.height,
            Root.Config.widgets.marginX, Root.Config.widgets.marginY);
    }

    x: dragArea.drag.active ? x : targetPos.x
    y: dragArea.drag.active ? y : targetPos.y
    Behavior on x { enabled: !dragArea.drag.active; NumberAnimation { duration: Root.Theme.anim.springDuration; easing.type: Easing.OutBack; easing.overshoot: 0.3 } }
    Behavior on y { enabled: !dragArea.drag.active; NumberAnimation { duration: Root.Theme.anim.springDuration; easing.type: Easing.OutBack; easing.overshoot: 0.3 } }

    Text {
        anchors.centerIn: parent
        text: ghost.label
        color: Root.Theme.widgetText
        font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true }
    }

    // Position captured at drag start — all swaps reference this, not the live position
    property string dragStartPosition: ""

    Timer {
        id: swapDebounce
        interval: 300
        property string pendingSnap: ""
        onTriggered: {
            if (widgetRoot && pendingSnap !== "")
                widgetRoot.handleSwap(ghost.positionKey, pendingSnap, ghost.dragStartPosition);
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        drag.target: parent
        drag.smoothed: false
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onPressed: {
            if (overlay) {
                overlay.isDragging = true;
                overlay.draggedSize = Qt.size(parent.width, parent.height);
            }
            // Capture position at drag start and snapshot pending state
            if (widgetRoot) {
                ghost.dragStartPosition = widgetRoot.getEffectivePosition(ghost.positionKey,
                    widgetRoot.getDefaultPosition(ghost.positionKey));
                widgetRoot.beginDrag(ghost.positionKey);
            }
        }

        onPositionChanged: {
            if (drag.active && overlay) {
                overlay.updateNearestSnap(parent.x, parent.y, parent.width, parent.height);
                let snap = overlay.nearestSnap;
                if (snap !== "" && snap !== ghost.dragStartPosition && snap !== swapDebounce.pendingSnap) {
                    swapDebounce.pendingSnap = snap;
                    swapDebounce.restart();
                }
            }
        }

        onReleased: {
            swapDebounce.stop();
            if (overlay) {
                overlay.isDragging = false;
                overlay.nearestSnap = "";
            }
            if (widgetRoot && overlay) {
                let newPos = widgetRoot.findSnapPosition(parent.x, parent.y, parent.width, parent.height,
                    overlay.width, overlay.height);
                widgetRoot.handleSwap(ghost.positionKey, newPos, ghost.dragStartPosition);
            }
            swapDebounce.pendingSnap = "";
            ghost.dragStartPosition = "";
        }
    }
}
