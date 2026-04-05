import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import ".." as Root

PanelWindow {
    id: panel

    visible: false
    anchors { top: true; left: true; right: true; bottom: true }
    implicitWidth: Screen.width
    implicitHeight: Screen.height

    WlrLayershell.namespace: "quickshell-monitors"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    property var monitors: []
    property bool loading: false

    function toggle() {
        if (visible) { visible = false; return; }
        refresh();
        visible = true;
    }

    function refresh() {
        loading = true;
        loadProc.running = true;
    }

    // Dismiss on background click
    MouseArea {
        anchors.fill: parent
        onClicked: panel.visible = false
    }

    // Center card
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(600, parent.width - 80)
        height: contentCol.implicitHeight + 40
        radius: Root.Theme.radiusMedium
        color: Root.Theme.notifBackground
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true; color: Qt.rgba(0, 0, 0, 0.5)
            radius: 16; samples: 33; verticalOffset: 4
        }

        MouseArea { anchors.fill: parent } // block clicks through

        ColumnLayout {
            id: contentCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: Root.Icons.monitor + "  Monitors"
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: 18; bold: true }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 28; height: 28; radius: Root.Theme.radiusSmall
                    color: refreshMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1) : "transparent"
                    Text {
                        anchors.centerIn: parent; text: "󰑓"; color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: 16 }
                    }
                    MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.refresh() }
                }
                Rectangle {
                    width: 28; height: 28; radius: Root.Theme.radiusSmall
                    color: closeMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1) : "transparent"
                    Text {
                        anchors.centerIn: parent; text: Root.Icons.cancel; color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: 16 }
                    }
                    MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.visible = false }
                }
            }

            // Loading state
            Text {
                visible: panel.loading
                text: "Loading..."
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 13 }
            }

            // No monitors
            Text {
                visible: !panel.loading && panel.monitors.length === 0
                text: "No monitors detected"
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 13 }
            }

            // Monitor list
            Repeater {
                model: panel.monitors

                Rectangle {
                    Layout.fillWidth: true
                    height: monitorRow.implicitHeight + 20
                    radius: Root.Theme.radiusSmall
                    color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.15)

                    RowLayout {
                        id: monitorRow
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                        spacing: 12

                        // Monitor visual
                        Rectangle {
                            width: 48; height: 32; radius: 3
                            color: "transparent"
                            border.width: 2; border.color: Root.Theme.accentPrimary

                            Text {
                                anchors.centerIn: parent
                                text: (index + 1).toString()
                                color: Root.Theme.accentPrimary
                                font { family: Root.Theme.fontFamily; pixelSize: 14; bold: true }
                            }
                        }

                        // Info
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2

                            Text {
                                text: modelData.name
                                color: Root.Theme.textPrimary
                                font { family: Root.Theme.fontFamily; pixelSize: 14; bold: true }
                            }
                            Text {
                                text: {
                                    let m = modelData.mode;
                                    let desc = modelData.make || "";
                                    if (m) desc += (desc ? " - " : "") + m.width + "x" + m.height + " @ " + Math.round(m.refresh / 1000) + "Hz";
                                    return desc;
                                }
                                color: Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: 11 }
                            }
                        }

                        // Scale selector
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: "Scale"
                                color: Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: 10 }
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Row {
                                spacing: 4
                                Repeater {
                                    model: [1.0, 1.25, 1.5, 1.75, 2.0]
                                    Rectangle {
                                        width: 36; height: 24; radius: Root.Theme.radiusSmall
                                        property bool active: Math.abs(modelData - (panel.monitors[index] ? panel.monitors[index].scale : 1.0)) < 0.01

                                        color: active ? Root.Theme.accentPrimary
                                            : scaleMouse.containsMouse ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.2)
                                            : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.1)

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData + "x"
                                            color: parent.active ? Root.Theme.barBackground : Root.Theme.textPrimary
                                            font { family: Root.Theme.fontFamily; pixelSize: 10; bold: parent.active }
                                        }

                                        // Need the outer repeater's index
                                        property int monitorIdx: index

                                        MouseArea {
                                            id: scaleMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                let mon = panel.monitors[parent.monitorIdx];
                                                if (mon) applyScale(mon.name, modelData);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function applyScale(outputName, scale) {
        scaleProc.command = ["niri", "msg", "output", outputName, "scale", scale.toString()];
        scaleProc.running = true;
    }

    Process {
        id: scaleProc
        onExited: {
            // Refresh after applying
            Qt.callLater(function() { panel.refresh(); });
        }
    }

    Process {
        id: loadProc
        property string _buf: ""
        command: ["niri", "msg", "-j", "outputs"]

        stdout: SplitParser {
            onRead: line => { loadProc._buf += line + "\n"; }
        }

        onExited: (code) => {
            panel.loading = false;
            if (code !== 0) { loadProc._buf = ""; return; }
            try {
                let d = JSON.parse(loadProc._buf);
                let list = [];
                for (let name in d) {
                    let o = d[name];
                    let mode = o.current_mode !== null && o.current_mode !== undefined && o.modes
                        ? o.modes[o.current_mode] : null;
                    list.push({
                        name: name,
                        make: o.make || "",
                        model: o.model || "",
                        mode: mode ? { width: mode.width, height: mode.height, refresh: mode.refresh_rate } : null,
                        scale: o.logical ? o.logical.scale : 1.0,
                        x: o.logical ? o.logical.x : 0,
                        y: o.logical ? o.logical.y : 0
                    });
                }
                panel.monitors = list;
            } catch(e) {
                console.log("MonitorPanel: parse error:", e);
            }
            loadProc._buf = "";
        }
    }
}
