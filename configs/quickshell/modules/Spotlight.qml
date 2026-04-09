import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import ".." as Root
import "../core" as Core
import "spotlight" as Views

// Unified popup (rofi-style) with switchable views.
// Toggle via IPC:
//   qs ipc call quickshell-bar launcher
//   qs ipc call quickshell-bar clipboard
//   qs ipc call quickshell-bar wallpaper
Scope {
    id: spot

    // Theme is now a singleton - access via Root.Theme.propertyName

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
        if (activeView === "wallpaper") return Root.Theme.wpWidth;
        if (activeView === "launcher") return Root.Theme.launchWidth;
        return Root.Theme.clipWidth;
    }

    // Max height varies per view
    property int boxMaxHeight: {
        if (activeView === "wallpaper") return Root.Theme.wpMaxHeight;
        return Root.Theme.launchMaxHeight;
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
            color: Root.Theme.scrimColor
            opacity: spot.showing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration } }
            MouseArea { anchors.fill: parent; onClicked: spot.close() }
        }

        // ── Centered box (cozy) ──
        Rectangle {
            id: box
            width: spot.boxWidth
            height: Math.min(boxContent.implicitHeight, spot.boxMaxHeight)
            anchors.centerIn: parent
            radius: Root.Theme.radiusMedium
            color: Root.Theme.barBackground
            border.width: Root.Theme.borderWidth
            border.color: Root.Theme.borderColor

            scale: spot.showing ? 1 : 0.95
            opacity: spot.showing ? 1 : 0

            Behavior on scale { NumberAnimation { duration: Root.Theme.anim.bounceDuration; easing.type: Easing.OutBack; easing.overshoot: 0.3 } }
            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Root.Theme.anim.resizeDuration; easing.type: Easing.InOutCubic } }

            layer.enabled: spot.showing
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.5)
                shadowBlur: 1.0
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }

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
                        text: Root.Icons.search
                        color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
                        Layout.leftMargin: Root.Theme.notifPadding
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: 15 }
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
                                wallpaperView.onSearchTextChanged();
                            }
                        }

                        Text {
                            anchors.fill: parent
                            text: {
                                if (spot.activeView === "launcher") return "Search applications…";
                                if (spot.activeView === "wallpaper") return "Search wallpapers…";
                                return "Clipboard history";
                            }
                            color: Root.Theme.textDimmed; font: parent.font
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

                    // ── Tab switcher with sliding indicator (data-driven) ──
                    Item {
                        id: spotTabBar
                        Layout.rightMargin: Root.Theme.notifPadding
                        implicitWidth: spotTabRow.implicitWidth
                        implicitHeight: 28

                        readonly property var views: Core.Registry.spotlightViews
                        property int activeIdx: {
                            for (let i = 0; i < views.length; i++)
                                if (views[i].key === spot.activeView) return i;
                            return 0;
                        }

                        // Sliding underline
                        Rectangle {
                            y: spotTabBar.height - 2
                            width: 16; height: 2
                            radius: 1
                            color: Root.Theme.textAccent
                            x: spotTabBar.activeIdx * (24 + 8) + (24 - 16) / 2

                            Behavior on x { NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic } }
                        }

                        Row {
                            id: spotTabRow
                            spacing: 8

                            Repeater {
                                model: spotTabBar.views

                                Item {
                                    required property var modelData
                                    width: 24; height: 28
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        color: spot.activeView === modelData.key ? Root.Theme.textAccent : Root.Theme.textDimmed
                                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize - 2 }
                                        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spot.open(modelData.key) }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width - Root.Theme.notifPadding * 2; height: 1
                    color: Root.Theme.textDimmed; opacity: 0.3
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
