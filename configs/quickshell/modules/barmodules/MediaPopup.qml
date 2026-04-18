import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../.." as Root
import "../../core" as Core

// Cava visualizer panel — slides down from bar when toggled.
// Media controls have moved to MediaModule's click popup.
PanelWindow {
    id: popup

    property var playerService: Core.ServiceManager.player
    property bool showCava: false
    property bool barHidden: false

    readonly property bool cavaWanted: showCava && !barHidden

    onCavaWantedChanged: {
        if (cavaWanted) visible = true;
    }

    visible: false

    anchors { top: true }
    implicitWidth: Root.Theme.cavaWidth
    margins.top: Root.Config.bar.style === "float" ? Root.Theme.barHeight + 12 : Root.Theme.barHeight
    implicitHeight: Root.Theme.cavaHeight + 6

    WlrLayershell.namespace: "quickshell-cava"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: cavaRect
            width: parent.width
            height: Root.Theme.cavaHeight
            radius: 0
            color: Root.Theme.cavaBackground
            border.width: Root.Theme.borderWidth
            border.color: Root.Theme.borderColor

            layer.enabled: popup.cavaWanted
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.4)
                shadowBlur: 0.9
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 4
            }

            y: popup.cavaWanted ? 6 : -(Root.Theme.cavaHeight + 6)

            Behavior on y {
                NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
            }

            onYChanged: {
                if (!popup.cavaWanted && y <= -(Root.Theme.cavaHeight + 5))
                    popup.visible = false;
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            // Cava bars
            Row {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 1

                Repeater {
                    model: Root.Theme.cavaBars
                    Rectangle {
                        width: Math.max(1, (Root.Theme.cavaWidth - Root.Theme.cavaBars) / Root.Theme.cavaBars)
                        height: {
                            let vals = popup.playerService ? popup.playerService.cavaBars : [];
                            if (!vals || index >= vals.length) return 2;
                            return Math.max(2, vals[index] * parent.height);
                        }
                        radius: 0
                        anchors.bottom: parent.bottom
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(Root.Theme.cavaBarColor, 1.4) }
                            GradientStop { position: 1.0; color: Root.Theme.cavaBarColor }
                        }
                        Behavior on height { NumberAnimation { duration: 50 } }
                    }
                }
            }
        }
    }
}
