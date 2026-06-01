import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import ".." as Root
import "../core" as Core
import "spotlight" as Views

// Unified popup (rofi-style) with switchable providers.
// Toggle via IPC:
//   qs ipc call quickshell-bar launcher
//   qs ipc call quickshell-bar clipboard
//   qs ipc call quickshell-bar wallpaper
//
// The provider architecture: each view (LauncherView, ClipboardView,
// WallpaperView) extends SpotlightProvider and exposes a uniform API
// (activate, deactivate, handleSearchText, moveUp/Down/Left/Right,
// accept). Spotlight dispatches all search text and keyboard events
// through the activeProvider without knowing its internals.
Scope {
    id: spot

    property bool showing: false
    property string activeView: "launcher"

    // ── Provider resolution ──
    // Map from key → provider instance. Adding a new provider is:
    //   1. Create FooView.qml extending SpotlightProvider
    //   2. Instantiate it below
    //   3. Add its key here
    //   4. Register in Registry.spotlightViews for the tab icon
    readonly property var providerMap: ({
        "launcher": launcherView,
        "clipboard": clipboardView,
        "wallpaper": wallpaperView,
        "calculator": calculatorView,
        "emoji": emojiView
    })

    readonly property var activeProvider: providerMap[activeView] || launcherView

    function open(view) {
        // Deactivate the old provider before switching
        let switching = activeView !== view;
        if (switching && providerMap[activeView])
            providerMap[activeView].deactivate();

        activeView = view;
        showing = true;
        spotPanel.visible = true;

        // Clear search text when switching tabs so the new provider
        // starts fresh instead of receiving the previous query
        if (switching)
            searchInput.text = "";

        activeProvider.activate();
        searchInput.forceActiveFocus();
    }

    function close() {
        showing = false;
        activeProvider.deactivate();
    }

    function toggle(view) {
        if (showing && activeView === view)
            close();
        else
            open(view);
    }

    // Dimensions driven by the active provider — no per-view if/else.
    property int boxWidth: activeProvider.preferredWidth
    property int boxMaxHeight: activeProvider.preferredMaxHeight

    // Height budget the active view can use. Accounts for the search
    // bar (46px) and divider (1px) that sit above the view in
    // boxContent. Views bind their flickable heights to this instead
    // of hardcoding magic deductions.
    readonly property int viewBudget: boxMaxHeight - 47

    // ════��═════════════════════════════
    // ── Full-screen overlay ──
    // ═══════════��══════════════════════
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
            clip: true
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
                        font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.iconSize }
                        Layout.leftMargin: Root.Theme.notifPadding
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.leftMargin: Root.Theme.spacingS
                        Layout.rightMargin: Root.Theme.spacingS
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: 15 }
                        clip: true; selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        // All search dispatch goes through the provider API
                        onTextChanged: spot.activeProvider.handleSearchText(text)

                        Text {
                            anchors.fill: parent
                            text: "Search " + spot.activeProvider.providerLabel.toLowerCase() + "…"
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
                        Keys.onReturnPressed: spot.activeProvider.accept()
                        Keys.onDownPressed: spot.activeProvider.moveDown()
                        Keys.onUpPressed: spot.activeProvider.moveUp()

                        // Ctrl+1..5 to switch tabs, Shift+Delete to remove item
                        Keys.onPressed: function(event) {
                            if (event.modifiers & Qt.ControlModifier) {
                                let views = Core.Registry.spotlightViews;
                                let idx = -1;
                                if (event.key === Qt.Key_1) idx = 0;
                                else if (event.key === Qt.Key_2) idx = 1;
                                else if (event.key === Qt.Key_3) idx = 2;
                                else if (event.key === Qt.Key_4) idx = 3;
                                else if (event.key === Qt.Key_5) idx = 4;
                                if (idx >= 0 && idx < views.length) {
                                    spot.open(views[idx].key);
                                    event.accepted = true;
                                }
                            }
                            // Shift+Delete: delete selected item (clipboard, etc.)
                            if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                                spot.activeProvider.deleteSelected();
                                event.accepted = true;
                            }
                        }

                        Keys.onLeftPressed: function(event) {
                            if (spot.activeProvider.hasGrid)
                                spot.activeProvider.moveLeft();
                            else
                                event.accepted = false;
                        }

                        Keys.onRightPressed: function(event) {
                            if (spot.activeProvider.hasGrid)
                                spot.activeProvider.moveRight();
                            else
                                event.accepted = false;
                        }

                        Keys.onTabPressed: {
                            if (spot.activeProvider.hasGrid)
                                spot.activeProvider.moveRight();
                            else
                                spot.activeProvider.moveDown();
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
                            spacing: Root.Theme.spacingS

                            Repeater {
                                model: spotTabBar.views

                                Item {
                                    required property var modelData
                                    width: 24; height: 28

                                    property var provider: spot.providerMap[modelData.key] || null
                                    property bool hasFilter: provider && provider.resultCount > 0 && provider.resultCount < provider.totalCount

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        color: spot.activeView === modelData.key ? Root.Theme.textAccent : Root.Theme.textDimmed
                                        font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.iconSize - 2 }
                                        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                                    }

                                    // Result count badge (visible when actively filtering)
                                    Rectangle {
                                        visible: parent.hasFilter && spot.activeView === modelData.key
                                        anchors { top: parent.top; right: parent.right; topMargin: 1; rightMargin: -4 }
                                        width: Math.max(badgeText.implicitWidth + 6, 14); height: 12
                                        radius: 6
                                        color: Root.Theme.textAccent

                                        Text {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: parent.parent.provider ? parent.parent.provider.resultCount.toString() : ""
                                            color: Root.Theme.barBackground
                                            font { family: Root.Theme.fontFamily; pixelSize: 8; bold: true }
                                        }
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
                // Each view extends SpotlightProvider and is shown/hidden
                // based on activeView. The provider API handles all
                // lifecycle, search, and navigation — no per-view logic
                // leaks into Spotlight.qml.
                Views.LauncherView {
                    id: launcherView
                    visible: spot.activeView === "launcher"
                    width: parent.width
                    maxContentHeight: spot.viewBudget
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Root.Theme.animFast; easing.type: Easing.OutCubic } }
                    onLaunched: spot.close()
                }

                Views.ClipboardView {
                    id: clipboardView
                    visible: spot.activeView === "clipboard"
                    width: parent.width
                    maxContentHeight: spot.viewBudget
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Root.Theme.animFast; easing.type: Easing.OutCubic } }
                    onItemSelected: spot.close()
                }

                Views.WallpaperView {
                    id: wallpaperView
                    visible: spot.activeView === "wallpaper"
                    width: parent.width
                    maxContentHeight: spot.viewBudget
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Root.Theme.animFast; easing.type: Easing.OutCubic } }
                    onWallpaperSet: spot.close()
                    onSearchRequested: text => { searchInput.text = text; }
                }

                Views.CalculatorView {
                    id: calculatorView
                    visible: spot.activeView === "calculator"
                    width: parent.width
                    maxContentHeight: spot.viewBudget
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Root.Theme.animFast; easing.type: Easing.OutCubic } }
                }

                Views.EmojiView {
                    id: emojiView
                    visible: spot.activeView === "emoji"
                    width: parent.width
                    maxContentHeight: spot.viewBudget
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Root.Theme.animFast; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
