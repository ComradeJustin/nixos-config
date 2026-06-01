import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import ".." as Root
import "../components" as Components

// Monitor configuration dialog — centered modal over the shared OverlayPanel base.
Components.OverlayPanel {
    id: panel

    namespace: "quickshell-monitors"
    scrimOpacity: 0.35

    property var monitors: []
    property bool loading: false

    // Reload the monitor list each time the dialog opens.
    onAboutToOpen: panel.refresh()

    function refresh() {
        loading = true;
        loadProc.running = true;
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
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowBlur: 1.0
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
        }

        MouseArea { anchors.fill: parent } // block clicks through

        ColumnLayout {
            id: contentCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: Root.Theme.spacingM

            // Header
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: Root.Icons.monitor + "  Monitors"
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize3XL; bold: true }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 28; height: 28; radius: Root.Theme.radiusSmall
                    color: refreshMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1) : "transparent"
                    Text {
                        anchors.centerIn: parent; text: "󰑓"; color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize2XL }
                    }
                    MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.refresh() }
                }
                Rectangle {
                    width: 28; height: 28; radius: Root.Theme.radiusSmall
                    color: closeMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1) : "transparent"
                    Text {
                        anchors.centerIn: parent; text: Root.Icons.cancel; color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize2XL }
                    }
                    MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.close() }
                }
            }

            // Loading state
            Text {
                visible: panel.loading
                text: "Loading..."
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeL }
            }

            // No monitors
            Text {
                visible: !panel.loading && panel.monitors.length === 0
                text: "No monitors detected"
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeL }
            }

            // Monitor list
            Repeater {
                model: panel.monitors

                Rectangle {
                    id: monitorEntry
                    // Capture this monitor row's data so the inner scale Repeater
                    // (whose own index/modelData are the scale VALUE, not the
                    // monitor) can address the correct, per-row monitor.
                    readonly property var monitor: modelData
                    readonly property int monitorIndex: index
                    // Optimistic highlight: reflect a just-clicked scale instantly,
                    // then defer to niri's authoritative value once it reloads.
                    property real pendingScale: 0
                    onMonitorChanged: pendingScale = 0

                    Layout.fillWidth: true
                    height: monitorRow.implicitHeight + 20
                    radius: Root.Theme.radiusSmall
                    color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.15)

                    RowLayout {
                        id: monitorRow
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Root.Theme.spacingM }
                        spacing: Root.Theme.spacingM

                        // Monitor visual
                        Rectangle {
                            width: 48; height: 32; radius: 3
                            color: "transparent"
                            border.width: 2; border.color: Root.Theme.accentPrimary

                            Text {
                                anchors.centerIn: parent
                                text: (index + 1).toString()
                                color: Root.Theme.accentPrimary
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXL; bold: true }
                            }
                        }

                        // Info
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2

                            Text {
                                text: modelData.name
                                color: Root.Theme.textPrimary
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXL; bold: true }
                            }
                            Text {
                                text: {
                                    let m = modelData.mode;
                                    let desc = modelData.make || "";
                                    if (m) desc += (desc ? " - " : "") + m.width + "x" + m.height + " @ " + Math.round(m.refresh / 1000) + "Hz";
                                    return desc;
                                }
                                color: Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                            }
                        }

                        // Scale selector
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: "Scale"
                                color: Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Row {
                                spacing: Root.Theme.spacingXS
                                Repeater {
                                    model: [1.0, 1.25, 1.5, 1.75, 2.0]
                                    Rectangle {
                                        width: 36; height: 24; radius: Root.Theme.radiusSmall
                                        property bool active: {
                                            const current = monitorEntry.pendingScale > 0
                                                ? monitorEntry.pendingScale
                                                : (monitorEntry.monitor ? monitorEntry.monitor.scale : 1.0);
                                            return Math.abs(modelData - current) < 0.01;
                                        }

                                        color: active ? Root.Theme.accentPrimary
                                            : scaleMouse.containsMouse ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.2)
                                            : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.1)

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData + "x"
                                            color: parent.active ? Root.Theme.barBackground : Root.Theme.textPrimary
                                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS; bold: parent.active }
                                        }

                                        MouseArea {
                                            id: scaleMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                let mon = monitorEntry.monitor;
                                                if (mon) {
                                                    monitorEntry.pendingScale = modelData;
                                                    applyScale(mon.name, modelData);
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
