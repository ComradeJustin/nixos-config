import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".." as Root
import "spotlight" as Views

// Unified popup (rofi-style) with switchable views.
// Toggle via IPC:
//   qs ipc call quickshell-bar launcher
//   qs ipc call quickshell-bar clipboard
Scope {
    id: spot

    Root.Theme { id: theme }

    property bool showing: false
    property string activeView: "launcher"  // "launcher" | "clipboard"

    function open(view) {
        activeView = view;
        showing = true;
        spotPanel.visible = true;

        if (view === "launcher") {
            launcherView.resetSearch();
            searchInput.forceActiveFocus();
        } else if (view === "clipboard") {
            clipboardView.refresh();
            searchInput.forceActiveFocus();
        }
    }

    function close() {
        showing = false;
    }

    function toggle(view) {
        if (showing && activeView === view)
            close();
        else
            open(view);
    }

    // ══════════════════════════════════
    // ── Full-screen overlay ──
    // ══════════════════════════════════
    PanelWindow {
        id: spotPanel
        visible: false

        anchors { top: true; bottom: true; left: true; right: true }

        WlrLayershell.namespace: "quickshell-spotlight"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        // ── Scrim ──
        Rectangle {
            anchors.fill: parent
            color: theme.scrimColor
            opacity: spot.showing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            MouseArea { anchors.fill: parent; onClicked: spot.close() }
        }

        // ── Centered box ──
        Rectangle {
            id: box
            width: spot.activeView === "launcher" ? theme.launchWidth : theme.clipWidth
            height: Math.min(boxContent.implicitHeight, theme.launchMaxHeight)
            anchors.centerIn: parent
            radius: theme.notifRadius
            color: theme.barBackground

            scale: spot.showing ? 1 : 0.95
            opacity: spot.showing ? 1 : 0

            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

            onOpacityChanged: {
                if (!spot.showing && opacity <= 0.01)
                    spotPanel.visible = false;
            }

            Column {
                id: boxContent
                width: parent.width
                spacing: 0

                // ── Search bar ──
                RowLayout {
                    width: parent.width
                    height: 46

                    Text {
                        text: theme.iconSearch
                        color: theme.textDimmed
                        font { family: theme.fontFamily; pixelSize: theme.iconSize }
                        Layout.leftMargin: theme.notifPadding
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        color: theme.textPrimary
                        font { family: theme.fontFamily; pixelSize: 15 }
                        clip: true; selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        onTextChanged: {
                            if (spot.activeView === "launcher") {
                                launcherView.searchText = text;
                                launcherView.selectedIndex = 0;
                                launcherView.updateFilter();
                            }
                        }

                        Text {
                            anchors.fill: parent
                            text: spot.activeView === "launcher" ? "Search applications…" : "Clipboard history"
                            color: theme.textDimmed; font: parent.font
                            visible: parent.text.length === 0
                            verticalAlignment: Text.AlignVCenter
                        }

                        Connections {
                            target: spot
                            function onShowingChanged() {
                                if (spot.showing) {
                                    searchInput.text = "";
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }

                        Keys.onEscapePressed: spot.close()

                        Keys.onReturnPressed: {
                            if (spot.activeView === "launcher")
                                launcherView.launchSelected();
                        }

                        Keys.onDownPressed: {
                            if (spot.activeView === "launcher")
                                launcherView.moveDown();
                        }

                        Keys.onUpPressed: {
                            if (spot.activeView === "launcher")
                                launcherView.moveUp();
                        }

                        Keys.onTabPressed: {
                            if (spot.activeView === "launcher") {
                                launcherView.moveDown();
                            }
                        }
                    }

                    // ── Tab switcher ──
                    Row {
                        Layout.rightMargin: theme.notifPadding
                        spacing: 4

                        Rectangle {
                            width: 28; height: 28; radius: 6
                            color: spot.activeView === "launcher"
                                ? Qt.rgba(theme.textAccent.r, theme.textAccent.g, theme.textAccent.b, 0.15)
                                : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: theme.iconLaunch; color: spot.activeView === "launcher" ? theme.textAccent : theme.textDimmed
                                font { family: theme.fontFamily; pixelSize: theme.iconSize - 2 }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spot.open("launcher") }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 6
                            color: spot.activeView === "clipboard"
                                ? Qt.rgba(theme.textAccent.r, theme.textAccent.g, theme.textAccent.b, 0.15)
                                : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: theme.iconClipboard; color: spot.activeView === "clipboard" ? theme.textAccent : theme.textDimmed
                                font { family: theme.fontFamily; pixelSize: theme.iconSize - 2 }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spot.open("clipboard") }
                        }
                    }
                }

                Rectangle {
                    width: parent.width - theme.notifPadding * 2; height: 1
                    color: theme.textDimmed; opacity: 0.3
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // ── Views ──
                Views.LauncherView {
                    id: launcherView
                    visible: spot.activeView === "launcher"
                    width: parent.width
                    onLaunched: spot.close()
                }

                Views.ClipboardView {
                    id: clipboardView
                    visible: spot.activeView === "clipboard"
                    width: parent.width
                    onItemSelected: spot.close()
                }
            }
        }
    }
}
