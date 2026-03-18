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
//   qs ipc call quickshell-bar wallpaper
Scope {
    id: spot

    Root.Theme { id: theme }

    property bool showing: false
    property string activeView: "launcher"  // "launcher" | "clipboard" | "wallpaper"

    function open(view) {
        activeView = view;
        showing = true;
        spotPanel.visible = true;

        if (view === "launcher") {
            launcherView.resetSearch();
        } else if (view === "clipboard") {
            clipboardView.refresh();
        } else if (view === "wallpaper") {
            wallpaperView.resetSearch();
            wallpaperView.refresh();
        }
        searchInput.forceActiveFocus();
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

    // Box width varies per view
    property int boxWidth: {
        if (activeView === "wallpaper") return theme.wpWidth;
        if (activeView === "launcher") return theme.launchWidth;
        return theme.clipWidth;
    }

    // Max height varies per view
    property int boxMaxHeight: {
        if (activeView === "wallpaper") return theme.wpMaxHeight;
        return theme.launchMaxHeight;
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

        // ── Centered box (brutalist) ──
        Rectangle {
            id: box
            width: spot.boxWidth
            height: Math.min(boxContent.implicitHeight, spot.boxMaxHeight)
            anchors.centerIn: parent
            radius: 0
            color: theme.barBackground
            border.width: theme.borderWidth
            border.color: theme.borderColor

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
                            } else if (spot.activeView === "wallpaper") {
                                wallpaperView.searchText = text;
                                wallpaperView.selectedIndex = 0;
                                wallpaperView.updateFilter();
                            }
                        }

                        Text {
                            anchors.fill: parent
                            text: {
                                if (spot.activeView === "launcher") return "Search applications…";
                                if (spot.activeView === "wallpaper") return "Search wallpapers…";
                                return "Clipboard history";
                            }
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
                            else if (spot.activeView === "wallpaper")
                                wallpaperView.applySelected();
                        }

                        Keys.onDownPressed: {
                            if (spot.activeView === "launcher")
                                launcherView.moveDown();
                            else if (spot.activeView === "wallpaper")
                                wallpaperView.moveDown();
                        }

                        Keys.onUpPressed: {
                            if (spot.activeView === "launcher")
                                launcherView.moveUp();
                            else if (spot.activeView === "wallpaper")
                                wallpaperView.moveUp();
                        }

                        Keys.onLeftPressed: function(event) {
                            if (spot.activeView === "wallpaper")
                                wallpaperView.moveLeft();
                            else
                                event.accepted = false;
                        }

                        Keys.onRightPressed: function(event) {
                            if (spot.activeView === "wallpaper")
                                wallpaperView.moveRight();
                            else
                                event.accepted = false;
                        }

                        Keys.onTabPressed: {
                            if (spot.activeView === "launcher") {
                                launcherView.moveDown();
                            } else if (spot.activeView === "wallpaper") {
                                wallpaperView.moveRight();
                            }
                        }
                    }

                    // ── Tab switcher (underline indicator) ──
                    Row {
                        Layout.rightMargin: theme.notifPadding
                        spacing: 8

                        // Launcher tab
                        Item {
                            width: 24; height: 28
                            Text {
                                anchors.centerIn: parent
                                text: theme.iconLaunch
                                color: spot.activeView === "launcher" ? theme.textAccent : theme.textDimmed
                                font { family: theme.fontFamily; pixelSize: theme.iconSize - 2 }
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 16; height: 2
                                color: spot.activeView === "launcher" ? theme.textAccent : "transparent"
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spot.open("launcher") }
                        }

                        // Clipboard tab
                        Item {
                            width: 24; height: 28
                            Text {
                                anchors.centerIn: parent
                                text: theme.iconClipboard
                                color: spot.activeView === "clipboard" ? theme.textAccent : theme.textDimmed
                                font { family: theme.fontFamily; pixelSize: theme.iconSize - 2 }
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 16; height: 2
                                color: spot.activeView === "clipboard" ? theme.textAccent : "transparent"
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spot.open("clipboard") }
                        }

                        // Wallpaper tab
                        Item {
                            width: 24; height: 28
                            Text {
                                anchors.centerIn: parent
                                text: theme.iconWallpaper
                                color: spot.activeView === "wallpaper" ? theme.textAccent : theme.textDimmed
                                font { family: theme.fontFamily; pixelSize: theme.iconSize - 2 }
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 16; height: 2
                                color: spot.activeView === "wallpaper" ? theme.textAccent : "transparent"
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spot.open("wallpaper") }
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

                Views.WallpaperView {
                    id: wallpaperView
                    visible: spot.activeView === "wallpaper"
                    width: parent.width
                    onWallpaperSet: spot.close()
                }
            }
        }
    }
}
