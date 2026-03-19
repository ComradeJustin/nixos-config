import Quickshell
import Quickshell.Wayland
import QtQuick
import ".." as Root
import "../widgets" as Widgets

// Desktop widget overlay - displays background widgets on each monitor
Scope {
    id: root

    // Window service for occlusion detection
    property var windowService: null

    // Position calculation helper
    function getPosition(posStr, itemWidth, itemHeight, areaWidth, areaHeight, marginX, marginY) {
        let x = 0, y = 0;

        // Horizontal
        if (posStr.indexOf("left") !== -1) {
            x = marginX;
        } else if (posStr.indexOf("right") !== -1) {
            x = areaWidth - itemWidth - marginX;
        } else {
            x = (areaWidth - itemWidth) / 2;
        }

        // Vertical
        if (posStr.indexOf("top") !== -1) {
            y = marginY + Root.Theme.barHeight;  // Account for bar
        } else if (posStr.indexOf("bottom") !== -1) {
            y = areaHeight - itemHeight - marginY;
        } else {
            y = (areaHeight - itemHeight) / 2;
        }

        return Qt.point(x, y);
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            property var modelData

            screen: modelData
            anchors { top: true; left: true; right: true; bottom: true }
            implicitWidth: screen ? screen.width : 1920
            implicitHeight: screen ? screen.height : 1080

            WlrLayershell.namespace: "quickshell-widgets"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            color: "transparent"
            visible: Root.Config.enableWallpaperWidgets

            // Computed visibility: config enabled AND (auto-hide disabled OR no windows blocking)
            property bool widgetsShown: Root.Config.showClockWidget &&
                (!Root.Config.autoHideWidgets || (root.windowService ? root.windowService.widgetsVisible : true))

            // Clock Widget
            Widgets.ClockWidget {
                id: clockWidget
                visible: opacity > 0
                opacity: overlay.widgetsShown ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }

                timeFormat: Root.Config.clockShowSeconds
                    ? Root.Config.clockTimeFormat.replace("mm", "mm:ss")
                    : Root.Config.clockTimeFormat
                dateFormat: Root.Config.clockDateFormat
                showDate: Root.Config.clockShowDate
                showSeconds: Root.Config.clockShowSeconds
                clockFontSize: Root.Config.clockFontSize

                Component.onCompleted: updatePosition()
                onImplicitWidthChanged: updatePosition()
                onImplicitHeightChanged: updatePosition()

                function updatePosition() {
                    if (!overlay.screen) return;
                    let pos = root.getPosition(
                        Root.Config.clockWidgetPosition,
                        implicitWidth, implicitHeight,
                        overlay.screen.width, overlay.screen.height,
                        Root.Config.widgetMarginX, Root.Config.widgetMarginY
                    );
                    x = pos.x;
                    y = pos.y;
                }

                Connections {
                    target: overlay.screen
                    function onWidthChanged() { clockWidget.updatePosition(); }
                    function onHeightChanged() { clockWidget.updatePosition(); }
                }
            }
        }
    }
}
