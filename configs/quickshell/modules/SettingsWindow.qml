import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import Qt5Compat.GraphicalEffects
import ".." as Root
import "../components" as Components
import "../core" as Core

// Standalone settings window — multi-page app with left nav rail.
// Toggle via: settingsWindow.toggle()
// Dismiss via: click outside the card, or press Escape.
PanelWindow {
    id: win

    visible: false
    anchors { top: true; left: true; right: true; bottom: true }
    implicitWidth: Screen.width
    implicitHeight: Screen.height

    WlrLayershell.namespace: "quickshell-settings-window"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // ── Public API ──────────────────────────────────────────────────────

    function toggle() {
        if (visible) {
            _close();
        } else {
            _open();
        }
    }

    // ── Internal state ───────────────────────────────────────────────────
    property int _activePage: 0
    property int _pendingPage: -1         // page waiting for transition
    property bool _contentVisible: true   // drives fade in/out
    property bool _showing: false         // drives open/close animation

    // Page definitions — icon uses Nerd Font codepoints matching the spec
    readonly property var _pages: [
        { id: "bar",        label: "Bar",        icon: "󰍹" },
        { id: "widgets",    label: "Widgets",     icon: "󰕰" },
        { id: "features",   label: "Features",    icon: "󰒓" },
        { id: "appearance", label: "Appearance",  icon: "󰏘" },
        { id: "about",      label: "About",       icon: "󰋽" }
    ]

    function _open() {
        visible = true;
        _contentVisible = true;
        _activePage = 0;
        _showing = true;
    }

    function _close() {
        _showing = false;
        // visible set to false after close animation completes
    }

    function _switchPage(idx) {
        if (idx === _activePage) return;
        _pendingPage = idx;
        _contentVisible = false;
        // Swap happens in the opacity Behavior's onRunningChanged via pageSwapTimer
    }

    // ── Scrim — dismiss on background click + Escape key ──────────────
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, win._showing ? 0.35 : 0)

        Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: win._close()
            onClicked: win._close()
        }
    }

    // ── Centered card ────────────────────────────────────────────────────
    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 700
        height: 550

        radius: Root.Theme.radiusMedium
        color: Root.Theme.barBackground
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor

        opacity: win._showing ? 1 : 0
        scale: win._showing ? 1 : 0.92

        Behavior on opacity {
            NumberAnimation {
                duration: win._showing ? 250 : 150
                easing.type: win._showing ? Easing.OutCubic : Easing.InCubic
                onRunningChanged: {
                    if (!running && !win._showing) win.visible = false;
                }
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: win._showing ? 250 : 150
                easing.type: win._showing ? Easing.OutCubic : Easing.InCubic
            }
        }

        // Block background clicks from propagating to the scrim
        MouseArea { anchors.fill: parent }

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            color: Qt.rgba(0, 0, 0, 0.55)
            radius: 28
            samples: 57
            verticalOffset: 6
            horizontalOffset: 0
        }

        // ── Layout: nav rail (left) + content (right) ──────────────────
        Row {
            anchors.fill: parent

            // ── Navigation rail ─────────────────────────────────────────
            Rectangle {
                id: navRail
                width: 80
                height: parent.height
                color: Qt.rgba(
                    Root.Theme.base01.r,
                    Root.Theme.base01.g,
                    Root.Theme.base01.b,
                    0.5
                )
                // Left-side rounding only (top-left + bottom-left)
                radius: Root.Theme.radiusMedium

                // Clip trick: overlay a rectangle on the right to square those corners
                Rectangle {
                    anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
                    width: parent.radius
                    color: parent.color
                }

                Column {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: 20
                    }
                    spacing: 4

                    Repeater {
                        model: win._pages

                        // Nav item
                        Item {
                            required property var modelData
                            required property int index

                            width: navRail.width
                            height: 64

                            property bool active: win._activePage === index

                            // Hover detection
                            MouseArea {
                                id: navMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win._switchPage(index)
                            }

                            // Active / hover pill
                            Rectangle {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 8
                                    rightMargin: 8
                                }
                                height: 52
                                radius: 10

                                color: {
                                    if (active)
                                        return Qt.rgba(
                                            Root.Theme.accentPrimary.r,
                                            Root.Theme.accentPrimary.g,
                                            Root.Theme.accentPrimary.b,
                                            0.12
                                        )
                                    if (navMouse.containsMouse)
                                        return Qt.rgba(
                                            Root.Theme.textPrimary.r,
                                            Root.Theme.textPrimary.g,
                                            Root.Theme.textPrimary.b,
                                            0.06
                                        )
                                    return "transparent"
                                }

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.icon
                                        color: active
                                            ? Root.Theme.accentPrimary
                                            : (navMouse.containsMouse
                                                ? Root.Theme.textPrimary
                                                : Root.Theme.textDimmed)
                                        font {
                                            family: Root.Theme.fontFamily
                                            pixelSize: 18
                                        }

                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: active
                                            ? Root.Theme.accentPrimary
                                            : (navMouse.containsMouse
                                                ? Root.Theme.textPrimary
                                                : Root.Theme.textDimmed)
                                        font {
                                            family: Root.Theme.fontFamily
                                            pixelSize: 9
                                        }

                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Content area ─────────────────────────────────────────────
            Item {
                id: contentArea
                width: card.width - navRail.width
                height: card.height

                // Fade + 8px vertical slide transition
                opacity: win._contentVisible ? 1.0 : 0.0
                transform: Translate {
                    y: win._contentVisible ? 0 : 8
                    Behavior on y {
                        NumberAnimation { duration: win._contentVisible ? 200 : 100; easing.type: Easing.OutCubic }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: win._contentVisible ? 200 : 100
                        easing.type: Easing.OutCubic
                        onRunningChanged: {
                            // When fade-out completes, swap page then fade in
                            if (!running && !win._contentVisible && win._pendingPage >= 0) {
                                win._activePage = win._pendingPage;
                                win._pendingPage = -1;
                                win._contentVisible = true;
                            }
                        }
                    }
                }

                // ── Page header ─────────────────────────────────────────
                Item {
                    id: pageHeader
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: 20
                        leftMargin: 20
                        rightMargin: 16
                    }
                    height: 36

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: win._pages[win._activePage] ? win._pages[win._activePage].label : ""
                        color: Root.Theme.textPrimary
                        font {
                            family: Root.Theme.fontFamily
                            pixelSize: 16
                            bold: true
                        }
                    }

                    // Close button
                    Rectangle {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 28; height: 28
                        radius: Root.Theme.radiusSmall
                        color: closeMouse.containsMouse
                            ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1)
                            : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: Root.Icons.cancel
                            color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: 16 }
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win._close()
                        }
                    }
                }

                // Thin separator under header
                Rectangle {
                    id: headerSep
                    anchors {
                        top: pageHeader.bottom
                        left: pageHeader.left
                        right: pageHeader.right
                        topMargin: 8
                    }
                    height: 1
                    color: Root.Theme.borderColor
                    opacity: 0.5
                }

                // ── Scrollable page content ──────────────────────────────
                Components.SmoothFlickable {
                    id: pageScroll
                    anchors {
                        top: headerSep.bottom
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        topMargin: 12
                        leftMargin: 20
                        rightMargin: 16
                        bottomMargin: 16
                    }
                    contentHeight: pageLoader.height
                    clip: true

                    Loader {
                        id: pageLoader
                        width: pageScroll.width
                        sourceComponent: {
                            switch (win._activePage) {
                                case 0: return barPage
                                case 1: return widgetsPage
                                case 2: return featuresPage
                                case 3: return appearancePage
                                case 4: return aboutPage
                                default: return null
                            }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // ── Page components ─────────────────────────────────────────────────
    // ════════════════════════════════════════════════════════════════════

    // ── Bar page ─────────────────────────────────────────────────────────
    Component {
        id: barPage
        Column {
            width: parent ? parent.width : 0
            spacing: 16

            Components.SettingSection {
                title: "MODULES"
                width: parent.width

                Repeater {
                    model: Core.Registry.barModules
                    Components.SettingToggle {
                        required property var modelData
                        label: modelData.label
                        isOn: Root.Config.isBarModuleEnabled(modelData.key)
                        onToggled: Root.Config.toggleBarModule(modelData.key, modelData.section)
                    }
                }

                // Spacer before reorder button
                Item { width: 1; height: 4 }

                // Reorder button
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Root.Theme.radiusSmall
                    color: reorderMouse.containsMouse
                        ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.15)
                        : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.08)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: Root.Icons.drag
                            color: reorderMouse.containsMouse ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        Text {
                            text: "Reorder Bar"
                            color: reorderMouse.containsMouse ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }

                    MouseArea {
                        id: reorderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win._close()
                            let bar = Core.ServiceManager.bar; if (bar) bar.toggleBarEdit()
                        }
                    }
                }
            }

            Components.SettingSection {
                title: "BAR BEHAVIOR"
                width: parent.width

                Components.SettingToggle {
                    label: "Auto-hide bar in fullscreen"
                    description: "Hide the bar when a window goes fullscreen"
                    isOn: Root.Config.features.autoHideBarInFullscreen
                    onToggled: {
                        Root.Config.features.autoHideBarInFullscreen = !Root.Config.features.autoHideBarInFullscreen
                        Root.Config.save()
                    }
                }
            }

            Components.SettingSection {
                title: "BAR STYLE"
                width: parent.width

                Components.SettingToggle {
                    label: "Floating bar"
                    description: "Detach bar from screen edge with rounded corners"
                    isOn: Root.Config.bar.style === "float"
                    onToggled: {
                        Root.Config.bar.style = Root.Config.bar.style === "float" ? "flat" : "float"
                        Root.Config.save()
                    }
                }

                Components.SettingToggle {
                    label: "Module groups"
                    description: "Show card backgrounds around bar module groups"
                    isOn: Root.Config.bar.showGroups
                    onToggled: {
                        Root.Config.bar.showGroups = !Root.Config.bar.showGroups
                        Root.Config.save()
                    }
                }

                Components.SettingToggle {
                    label: "CPU sparkline"
                    description: "Show mini graph next to CPU usage"
                    isOn: Root.Config.bar.showCpuGraph
                    onToggled: {
                        Root.Config.bar.showCpuGraph = !Root.Config.bar.showCpuGraph
                        Root.Config.save()
                    }
                }
            }

            // Bottom padding
            Item { width: 1; height: 8 }
        }
    }

    // ── Widgets page ──────────────────────────────────────────────────────
    Component {
        id: widgetsPage
        Column {
            width: parent ? parent.width : 0
            spacing: 16

            Components.SettingSection {
                title: "DESKTOP WIDGETS"
                width: parent.width

                Repeater {
                    model: Core.Registry.widgets
                    Components.SettingToggle {
                        required property var modelData
                        label: modelData.label
                        isOn: Root.Config.widgets[modelData.configKey] || false
                        onToggled: Root.Config.toggleWidget(modelData.configKey)
                    }
                }

                Components.SettingToggle {
                    label: "Auto-hide widgets when windows present"
                    isOn: Root.Config.features.autoHideWidgets
                    onToggled: {
                        Root.Config.features.autoHideWidgets = !Root.Config.features.autoHideWidgets
                        Root.Config.save()
                    }
                }

                Components.SettingToggle {
                    label: "Wallpaper widgets"
                    description: "Render widgets directly on the wallpaper layer"
                    isOn: Root.Config.features.wallpaperWidgets
                    onToggled: {
                        Root.Config.features.wallpaperWidgets = !Root.Config.features.wallpaperWidgets
                        Root.Config.save()
                    }
                }

                // Spacer before edit layout button
                Item { width: 1; height: 4 }

                // Edit widget layout button
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Root.Theme.radiusSmall
                    color: widgetEditMouse.containsMouse
                        ? Qt.rgba(Root.Theme.domainSettings.r, Root.Theme.domainSettings.g, Root.Theme.domainSettings.b, 0.15)
                        : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.08)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: Root.Icons.widgets
                            color: widgetEditMouse.containsMouse ? Root.Theme.domainSettings : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        Text {
                            text: "Edit Widget Layout"
                            color: widgetEditMouse.containsMouse ? Root.Theme.domainSettings : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }

                    MouseArea {
                        id: widgetEditMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win._close()
                            let wo = Core.ServiceManager.widgetOverlay; if (wo) wo.toggleEditMode()
                        }
                    }
                }
            }

            Components.SettingSection {
                title: "CLOCK"
                width: parent.width

                Components.SettingSlider {
                    label: "Font size"
                    value: Root.Config.clockConfig.fontSize
                    minValue: 12; maxValue: 72; suffix: "px"
                    onSliderUpdated: newValue => {
                        Root.Config.clockConfig.fontSize = Math.round(newValue)
                        Root.Config.save()
                    }
                }
                Components.SettingToggle {
                    label: "Show seconds"
                    isOn: Root.Config.clockConfig.showSeconds
                    onToggled: {
                        Root.Config.clockConfig.showSeconds = !Root.Config.clockConfig.showSeconds
                        Root.Config.save()
                    }
                }
                Components.SettingToggle {
                    label: "Show date"
                    isOn: Root.Config.clockConfig.showDate
                    onToggled: {
                        Root.Config.clockConfig.showDate = !Root.Config.clockConfig.showDate
                        Root.Config.save()
                    }
                }
            }

            Components.SettingSection {
                title: "WEATHER"
                width: parent.width

                Components.SettingToggle {
                    label: "Use metric units"
                    isOn: Root.Config.weatherConfig.useMetric
                    onToggled: {
                        Root.Config.weatherConfig.useMetric = !Root.Config.weatherConfig.useMetric
                        Root.Config.save()
                    }
                }
                Components.SettingSlider {
                    label: "Font size"
                    value: Root.Config.weatherConfig.fontSize
                    minValue: 12; maxValue: 48; suffix: "px"
                    onSliderUpdated: newValue => {
                        Root.Config.weatherConfig.fontSize = Math.round(newValue)
                        Root.Config.save()
                    }
                }
            }

            Components.SettingSection {
                title: "SYSTEM"
                width: parent.width

                Components.SettingToggle {
                    label: "Show CPU"
                    isOn: Root.Config.systemConfig.showCpu
                    onToggled: {
                        Root.Config.systemConfig.showCpu = !Root.Config.systemConfig.showCpu
                        Root.Config.save()
                    }
                }
                Components.SettingToggle {
                    label: "Show RAM"
                    isOn: Root.Config.systemConfig.showRam
                    onToggled: {
                        Root.Config.systemConfig.showRam = !Root.Config.systemConfig.showRam
                        Root.Config.save()
                    }
                }
                Components.SettingSlider {
                    label: "Font size"
                    value: Root.Config.systemConfig.fontSize
                    minValue: 12; maxValue: 48; suffix: "px"
                    onSliderUpdated: newValue => {
                        Root.Config.systemConfig.fontSize = Math.round(newValue)
                        Root.Config.save()
                    }
                }
            }

            Components.SettingSection {
                title: "NOW PLAYING"
                width: parent.width

                Components.SettingToggle {
                    label: "Show album art"
                    isOn: Root.Config.nowPlayingConfig.showArt
                    onToggled: {
                        Root.Config.nowPlayingConfig.showArt = !Root.Config.nowPlayingConfig.showArt
                        Root.Config.save()
                    }
                }
                Components.SettingSlider {
                    label: "Art size"
                    value: Root.Config.nowPlayingConfig.artSize
                    minValue: 40; maxValue: 160; suffix: "px"
                    onSliderUpdated: newValue => {
                        Root.Config.nowPlayingConfig.artSize = Math.round(newValue)
                        Root.Config.save()
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }

    // ── Features page ─────────────────────────────────────────────────────
    Component {
        id: featuresPage
        Column {
            width: parent ? parent.width : 0
            spacing: 16

            Components.SettingSection {
                title: "POPUPS & OVERLAYS"
                width: parent.width

                Components.SettingToggle {
                    label: "Media popup"
                    description: "Floating media controls overlay"
                    isOn: Root.Config.features.mediaPopup
                    onToggled: {
                        Root.Config.features.mediaPopup = !Root.Config.features.mediaPopup
                        Root.Config.save()
                    }
                }
                Components.SettingToggle {
                    label: "Clipboard history"
                    description: "Track and browse clipboard entries"
                    isOn: Root.Config.features.clipboardHistory
                    onToggled: {
                        Root.Config.features.clipboardHistory = !Root.Config.features.clipboardHistory
                        Root.Config.save()
                    }
                }
                Components.SettingToggle {
                    label: "Wallpaper selector"
                    description: "Enable wallpaper picker in Spotlight"
                    isOn: Root.Config.features.wallpaperSelector
                    onToggled: {
                        Root.Config.features.wallpaperSelector = !Root.Config.features.wallpaperSelector
                        Root.Config.save()
                    }
                }
            }

            Components.SettingSection {
                title: "BEHAVIOR"
                width: parent.width

                Components.SettingToggle {
                    label: "Auto-hide widgets"
                    description: "Hide desktop widgets when windows are present"
                    isOn: Root.Config.features.autoHideWidgets
                    onToggled: {
                        Root.Config.features.autoHideWidgets = !Root.Config.features.autoHideWidgets
                        Root.Config.save()
                    }
                }
                Components.SettingToggle {
                    label: "Auto-hide bar in fullscreen"
                    description: "Hide the bar when a window goes fullscreen"
                    isOn: Root.Config.features.autoHideBarInFullscreen
                    onToggled: {
                        Root.Config.features.autoHideBarInFullscreen = !Root.Config.features.autoHideBarInFullscreen
                        Root.Config.save()
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }

    // ── Appearance page ───────────────────────────────────────────────────
    Component {
        id: appearancePage
        Column {
            width: parent ? parent.width : 0
            spacing: 16

            Components.SettingSection {
                title: "INTERVALS"
                width: parent.width

                // Weather interval: stored in ms, display in minutes (1–30)
                Components.SettingSlider {
                    label: "Weather update"
                    value: Math.round(Root.Config.behavior.weatherUpdateInterval / 60000)
                    minValue: 1; maxValue: 30; suffix: " min"
                    onSliderUpdated: newValue => {
                        Root.Config.behavior.weatherUpdateInterval = Math.round(newValue) * 60000
                        Root.Config.save()
                    }
                }

                // System stats interval: stored in ms, display in seconds (1–10)
                Components.SettingSlider {
                    label: "System stats"
                    value: Math.round(Root.Config.behavior.systemStatsInterval / 1000)
                    minValue: 1; maxValue: 10; suffix: " sec"
                    onSliderUpdated: newValue => {
                        Root.Config.behavior.systemStatsInterval = Math.round(newValue) * 1000
                        Root.Config.save()
                    }
                }

                // Notification timeout: stored in ms, display in seconds (1–15)
                Components.SettingSlider {
                    label: "Notification timeout"
                    value: Math.round(Root.Config.behavior.notificationTimeout / 1000)
                    minValue: 1; maxValue: 15; suffix: " sec"
                    onSliderUpdated: newValue => {
                        Root.Config.behavior.notificationTimeout = Math.round(newValue) * 1000
                        Root.Config.save()
                    }
                }
            }

            Components.SettingSection {
                title: "LIMITS"
                width: parent.width

                Components.SettingSlider {
                    label: "Max clipboard items"
                    value: Root.Config.behavior.maxClipboardItems
                    minValue: 10; maxValue: 100
                    onSliderUpdated: newValue => {
                        Root.Config.behavior.maxClipboardItems = Math.round(newValue)
                        Root.Config.save()
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }

    // ── About page ────────────────────────────────────────────────────────
    Component {
        id: aboutPage
        Column {
            width: parent ? parent.width : 0
            spacing: 24

            // Hero block
            Column {
                width: parent.width
                spacing: 6
                topPadding: 12

                Text {
                    text: "QuickShell"
                    color: Root.Theme.textPrimary
                    font {
                        family: Root.Theme.fontFamily
                        pixelSize: 28
                        bold: true
                    }
                }
                Text {
                    text: "Desktop Shell for Niri"
                    color: Root.Theme.textDimmed
                    font {
                        family: Root.Theme.fontFamily
                        pixelSize: Root.Theme.fontSizeLarge
                    }
                }
            }

            // Info block
            Rectangle {
                width: parent.width
                height: infoCol.implicitHeight + 24
                radius: Root.Theme.radiusMedium
                color: Qt.rgba(Root.Theme.base01.r, Root.Theme.base01.g, Root.Theme.base01.b, 0.6)
                border.width: Root.Theme.borderWidth
                border.color: Root.Theme.borderColor

                Column {
                    id: infoCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 12
                    }
                    spacing: 8

                    // Config path row
                    Row {
                        spacing: 8
                        width: parent.width

                        Text {
                            text: "Config path"
                            color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                            width: 90
                        }
                        Text {
                            text: Root.Theme.configBase + "/configs/quickshell"
                            color: Root.Theme.textPrimary
                            font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeSmall }
                            elide: Text.ElideLeft
                            width: parent.width - 98
                        }
                    }

                    // Theming row
                    Row {
                        spacing: 8
                        width: parent.width

                        Text {
                            text: "Theming"
                            color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                            width: 90
                        }
                        Text {
                            text: "Base16 / Stylix"
                            color: Root.Theme.textPrimary
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                        }
                    }
                }
            }

            // Open config button
            Rectangle {
                width: parent.width
                height: 36
                radius: Root.Theme.radiusSmall
                color: openMouse.containsMouse
                    ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.18)
                    : Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.10)
                border.width: Root.Theme.borderWidth
                border.color: Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.3)

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: Root.Icons.edit + "  Open Config Folder"
                    color: Root.Theme.accentPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                }

                MouseArea {
                    id: openMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: openConfigProc.running = true
                }
            }

            Item { width: 1; height: 8 }
        }
    }

    // ── Process: open config folder ──────────────────────────────────────
    Process {
        id: openConfigProc
        command: [
            "xdg-open",
            Root.Theme.configBase + "/configs/quickshell"
        ]
    }
}
