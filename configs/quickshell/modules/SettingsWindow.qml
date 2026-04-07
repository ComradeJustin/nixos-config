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

    // Open the settings window directly to a specific page by id (e.g.
    // "bar", "widgets", "preferences", "about"). Falls back to the first
    // page if the id is unknown. Used by IPC and from notifications/hooks.
    function open(pageId) {
        let idx = 0;
        for (let i = 0; i < _pages.length; i++) {
            if (_pages[i].id === pageId) { idx = i; break; }
        }
        if (visible) {
            _switchPage(idx);
        } else {
            _open();
            _activePage = idx;
        }
    }

    // ── Internal state ───────────────────────────────────────────────────
    property int _activePage: 0
    property int _pendingPage: -1         // page waiting for transition
    property bool _contentVisible: true   // drives fade in/out
    property bool _showing: false         // drives open/close animation
    property string _searchQuery: ""      // when non-empty, search results replace the page

    // Page definitions — icon uses Nerd Font codepoints matching the spec
    readonly property var _pages: [
        { id: "bar",         label: "Bar",         icon: "󰍹" },
        { id: "widgets",     label: "Widgets",     icon: "󰕰" },
        { id: "preferences", label: "Preferences", icon: "󰒓" },
        { id: "hooks",       label: "Hooks",       icon: "󰢩" },
        { id: "about",       label: "About",       icon: "󰋽" }
    ]

    // ── Search index ──────────────────────────────────────────────────
    // Static index mapping every settable option to its page. Adding a new
    // toggle to a page also requires adding it here so search can find it.
    // keywords are matched in addition to the label.
    readonly property var _searchIndex: [
        // Bar page
        { label: "Modules",            keywords: "bar layout enable disable",        page: 0 },
        { label: "Floating bar",       keywords: "bar style float flat detach",      page: 0 },
        { label: "Module groups",      keywords: "bar groups card background",       page: 0 },
        { label: "CPU sparkline",      keywords: "cpu graph chart resource",         page: 0 },
        { label: "Reorder Bar",        keywords: "bar drag rearrange",               page: 0 },
        // Widgets page
        { label: "Desktop widgets",    keywords: "wallpaper widget enable",          page: 1 },
        { label: "Edit Widget Layout", keywords: "widget drag rearrange position",   page: 1 },
        { label: "Clock font size",    keywords: "clock time fontSize",              page: 1 },
        { label: "Show seconds",       keywords: "clock time seconds",               page: 1 },
        { label: "Show date",          keywords: "clock date",                       page: 1 },
        { label: "Use metric units",   keywords: "weather metric celsius units",     page: 1 },
        { label: "Weather font size",  keywords: "weather fontSize",                 page: 1 },
        { label: "Show CPU",           keywords: "system cpu",                       page: 1 },
        { label: "Show RAM",           keywords: "system ram memory",                page: 1 },
        { label: "System font size",   keywords: "system fontSize",                  page: 1 },
        { label: "Show album art",     keywords: "now playing media art",            page: 1 },
        { label: "Album art size",     keywords: "now playing media art size",       page: 1 },
        // Preferences page
        { label: "Media popup",        keywords: "media popup floating",             page: 2 },
        { label: "Clipboard history",  keywords: "clipboard copy paste history",     page: 2 },
        { label: "Wallpaper selector", keywords: "wallpaper picker spotlight",       page: 2 },
        { label: "Wallpaper widgets",  keywords: "wallpaper widget layer",           page: 2 },
        { label: "Auto-hide widgets",  keywords: "auto hide widget windows",         page: 2 },
        { label: "Auto-hide bar",      keywords: "auto hide bar fullscreen",         page: 2 },
        { label: "Weather update",     keywords: "weather interval refresh timing",  page: 2 },
        { label: "System stats",       keywords: "system stats interval timing",     page: 2 },
        { label: "Notification timeout", keywords: "notification timeout timing",    page: 2 },
        { label: "Max clipboard items", keywords: "clipboard max history",           page: 2 },
        // Hooks page
        { label: "Hooks events",        keywords: "hooks events list signal scripts", page: 3 },
        { label: "Recent fires",        keywords: "hooks debug log fires history",    page: 3 },
        { label: "Edit hooks.json",     keywords: "hooks edit json open file",        page: 3 },
        { label: "Reload hooks",        keywords: "hooks reload refresh",             page: 3 },
        // About page
        { label: "Open Config Folder", keywords: "config folder open path",          page: 4 }
    ]

    // Reactive — re-evaluates whenever _searchQuery changes.
    readonly property var _filteredResults: {
        let q = _searchQuery.trim().toLowerCase();
        if (q.length === 0) return [];
        let out = [];
        for (let i = 0; i < _searchIndex.length; i++) {
            let e = _searchIndex[i];
            let hay = (e.label + " " + (e.keywords || "")).toLowerCase();
            if (hay.indexOf(q) !== -1) out.push(e);
        }
        return out;
    }

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
            Keys.onUpPressed: { if (win._activePage > 0) win._switchPage(win._activePage - 1); }
            Keys.onDownPressed: { if (win._activePage < win._pages.length - 1) win._switchPage(win._activePage + 1); }
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

                    // Page title (hidden while searching to give the input space)
                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: win._searchQuery.length > 0
                              ? "Search"
                              : (win._pages[win._activePage] ? win._pages[win._activePage].label : "")
                        color: Root.Theme.textPrimary
                        font {
                            family: Root.Theme.fontFamily
                            pixelSize: 16
                            bold: true
                        }
                    }

                    // ── Search box ──
                    Rectangle {
                        id: searchBox
                        anchors {
                            verticalCenter: parent.verticalCenter
                            right: closeBtn.left
                            rightMargin: 8
                        }
                        width: 200
                        height: 28
                        radius: Root.Theme.radiusSmall
                        color: Qt.rgba(Root.Theme.base01.r, Root.Theme.base01.g, Root.Theme.base01.b, 0.7)
                        border.width: 1
                        border.color: searchInput.activeFocus
                            ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.5)
                            : Root.Theme.borderColor

                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Root.Icons.search
                                color: Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: 12 }
                            }

                            TextInput {
                                id: searchInput
                                width: parent.width - 24
                                anchors.verticalCenter: parent.verticalCenter
                                color: Root.Theme.textPrimary
                                font { family: Root.Theme.fontFamily; pixelSize: 12 }
                                selectByMouse: true
                                clip: true
                                onTextChanged: win._searchQuery = text
                                Keys.onEscapePressed: {
                                    if (text.length > 0) { text = ""; }
                                    else win._close();
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Search settings"
                                    color: Root.Theme.textDimmed
                                    font: searchInput.font
                                    visible: searchInput.text.length === 0
                                }
                            }
                        }
                    }

                    Components.IconButton {
                        id: closeBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        icon: Root.Icons.cancel
                        iconColor: Root.Theme.textDimmed
                        tooltipText: "Close (Esc)"
                        onClicked: win._close()
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
                            if (win._searchQuery.length > 0) return searchResultsPage;
                            switch (win._activePage) {
                                case 0: return barPage
                                case 1: return widgetsPage
                                case 2: return preferencesPage
                                case 3: return hooksPage
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

    // ── Search results page ──────────────────────────────────────────────
    Component {
        id: searchResultsPage
        Column {
            id: searchCol
            width: parent ? parent.width : 0
            spacing: 6

            Text {
                visible: win._filteredResults.length === 0
                text: "No matches"
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                topPadding: 12
                leftPadding: 4
            }

            Repeater {
                model: win._filteredResults

                Rectangle {
                    required property var modelData
                    width: searchCol.width
                    height: 44
                    radius: Root.Theme.radiusSmall
                    color: resultMouse.containsMouse
                        ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.10)
                        : Qt.rgba(Root.Theme.base01.r, Root.Theme.base01.g, Root.Theme.base01.b, 0.5)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors {
                            left: parent.left; leftMargin: 12
                            right: pageBadge.left; rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 2

                        Text {
                            text: modelData.label
                            color: Root.Theme.textPrimary
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: modelData.keywords
                            color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    // Page indicator pill
                    Rectangle {
                        id: pageBadge
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        width: pageBadgeText.implicitWidth + 14
                        height: 20
                        radius: 10
                        color: Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.18)

                        Text {
                            id: pageBadgeText
                            anchors.centerIn: parent
                            text: win._pages[modelData.page] ? win._pages[modelData.page].label : ""
                            color: Root.Theme.accentPrimary
                            font { family: Root.Theme.fontFamily; pixelSize: 10; bold: true }
                        }
                    }

                    MouseArea {
                        id: resultMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Jump to the page and clear the search.
                            win._switchPage(modelData.page);
                            win._searchQuery = "";
                            searchInput.text = "";
                        }
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }

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
                title: "BAR STYLE"
                width: parent.width
                resetCallback: () => Root.Config.resetSection("bar")

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

                Components.SettingToggle {
                    label: "Always show caffeine"
                    description: "Keep caffeine bar icon visible even when idle inhibit is off"
                    isOn: Root.Config.bar.showCaffeineWhenOff
                    onToggled: {
                        Root.Config.bar.showCaffeineWhenOff = !Root.Config.bar.showCaffeineWhenOff
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
                resetCallback: () => Root.Config.resetSection("clock")

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
                resetCallback: () => Root.Config.resetSection("weather")

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
                resetCallback: () => Root.Config.resetSection("system")

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
                resetCallback: () => Root.Config.resetSection("nowPlaying")

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

    // ── Preferences page (merged Features + Appearance) ─────────────────
    Component {
        id: preferencesPage
        Column {
            width: parent ? parent.width : 0
            spacing: 16

            Components.SettingSection {
                title: "FEATURES"
                width: parent.width
                resetCallback: () => Root.Config.resetSection("features")

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
                Components.SettingToggle {
                    label: "Wallpaper widgets"
                    description: "Render widgets directly on the wallpaper layer"
                    isOn: Root.Config.features.wallpaperWidgets
                    onToggled: {
                        Root.Config.features.wallpaperWidgets = !Root.Config.features.wallpaperWidgets
                        Root.Config.save()
                    }
                }
            }

            Components.SettingSection {
                title: "BEHAVIOR"
                width: parent.width
                resetCallback: () => Root.Config.resetSection("features")

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

            Components.SettingSection {
                title: "TIMING"
                width: parent.width
                resetCallback: () => Root.Config.resetSection("behavior")

                Components.SettingSlider {
                    label: "Weather update"
                    value: Math.round(Root.Config.behavior.weatherUpdateInterval / 60000)
                    minValue: 1; maxValue: 30; suffix: " min"
                    onSliderUpdated: newValue => {
                        Root.Config.behavior.weatherUpdateInterval = Math.round(newValue) * 60000
                        Root.Config.save()
                    }
                }
                Components.SettingSlider {
                    label: "System stats"
                    value: Math.round(Root.Config.behavior.systemStatsInterval / 1000)
                    minValue: 1; maxValue: 10; suffix: " sec"
                    onSliderUpdated: newValue => {
                        Root.Config.behavior.systemStatsInterval = Math.round(newValue) * 1000
                        Root.Config.save()
                    }
                }
                Components.SettingSlider {
                    label: "Notification timeout"
                    value: Math.round(Root.Config.behavior.notificationTimeout / 1000)
                    minValue: 1; maxValue: 15; suffix: " sec"
                    onSliderUpdated: newValue => {
                        Root.Config.behavior.notificationTimeout = Math.round(newValue) * 1000
                        Root.Config.save()
                    }
                }
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

    // ── Hooks page ───────────────────────────────────────────────────────
    // Discovery + debug surface for HooksService.
    // Lists every known event with its current binding (or "—") and shows
    // a live tail of the most recent fires for "why isn't my hook firing?"
    // troubleshooting.
    Component {
        id: hooksPage
        Column {
            id: hooksCol
            width: parent ? parent.width : 0
            spacing: 16

            // Service handle — picked up reactively from ServiceManager.
            property var hooksSvc: Core.ServiceManager.hooks

            // ── Header / actions ────────────────────────────────────────
            Components.SettingSection {
                title: "HOOKS"
                width: parent.width

                Text {
                    text: "Hooks bind shell events to shell commands.\nEdit ~/.config/quickshell/hooks.json — changes are picked up automatically."
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
                    wrapMode: Text.WordWrap
                    width: parent.width
                    bottomPadding: 8
                }

                Row {
                    width: parent.width
                    spacing: 8

                    // Edit button
                    Rectangle {
                        width: 140; height: 32
                        radius: Root.Theme.radiusSmall
                        color: editMouse.containsMouse
                            ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.18)
                            : Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.10)
                        border.width: Root.Theme.borderWidth
                        border.color: Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.3)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: Root.Icons.edit + "  Edit hooks.json"
                            color: Root.Theme.accentPrimary
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
                        }
                        MouseArea {
                            id: editMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: openHooksProc.running = true
                        }
                    }

                    // Reload button
                    Rectangle {
                        width: 110; height: 32
                        radius: Root.Theme.radiusSmall
                        color: reloadMouse.containsMouse
                            ? Qt.rgba(Root.Theme.base01.r, Root.Theme.base01.g, Root.Theme.base01.b, 0.95)
                            : Qt.rgba(Root.Theme.base01.r, Root.Theme.base01.g, Root.Theme.base01.b, 0.6)
                        border.width: Root.Theme.borderWidth
                        border.color: Root.Theme.borderColor
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: Root.Icons.reset + "  Reload"
                            color: Root.Theme.textPrimary
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
                        }
                        MouseArea {
                            id: reloadMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (hooksCol.hooksSvc) hooksCol.hooksSvc.reload(); }
                        }
                    }
                }
            }

            // ── Known events list ────────────────────────────────────────
            Components.SettingSection {
                title: "AVAILABLE EVENTS"
                width: parent.width

                Repeater {
                    model: hooksCol.hooksSvc ? hooksCol.hooksSvc.knownEvents : []

                    Rectangle {
                        required property var modelData
                        width: parent.width
                        height: eventCol.implicitHeight + 14
                        radius: Root.Theme.radiusSmall
                        color: Qt.rgba(Root.Theme.base01.r, Root.Theme.base01.g, Root.Theme.base01.b, 0.5)

                        // Reactive bound state — re-checks whenever the
                        // hook table reloads from disk.
                        readonly property bool isBound: hooksCol.hooksSvc
                            && hooksCol.hooksSvc._table[modelData.name] !== undefined

                        Column {
                            id: eventCol
                            anchors {
                                left: parent.left; leftMargin: 12
                                right: boundBadge.left; rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 2

                            Row {
                                spacing: 8
                                Text {
                                    text: modelData.name
                                    color: Root.Theme.textPrimary
                                    font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeSmall; bold: true }
                                }
                                Text {
                                    text: "(" + modelData.args + ")"
                                    color: Root.Theme.textDimmed
                                    font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeSmall }
                                }
                            }
                            Text {
                                text: modelData.desc
                                color: Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
                                wrapMode: Text.WordWrap
                                width: eventCol.width
                            }
                        }

                        // Bound / unbound pill
                        Rectangle {
                            id: boundBadge
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            width: boundBadgeText.implicitWidth + 14
                            height: 20
                            radius: 10
                            color: parent.isBound
                                ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.20)
                                : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.15)

                            Text {
                                id: boundBadgeText
                                anchors.centerIn: parent
                                text: parent.parent.isBound ? "bound" : "—"
                                color: parent.parent.isBound ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: 10; bold: true }
                            }
                        }
                    }
                }
            }

            // ── Recent fires ─────────────────────────────────────────────
            Components.SettingSection {
                title: "RECENT FIRES"
                width: parent.width

                Text {
                    visible: !hooksCol.hooksSvc || hooksCol.hooksSvc.recentFires.length === 0
                    text: "No events fired yet."
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
                }

                Repeater {
                    // Reverse so newest is on top.
                    model: hooksCol.hooksSvc
                        ? hooksCol.hooksSvc.recentFires.slice().reverse().slice(0, 10)
                        : []

                    Row {
                        required property var modelData
                        width: parent.width
                        height: 22
                        spacing: 8

                        Text {
                            text: Qt.formatTime(new Date(modelData.ts), "hh:mm:ss")
                            color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeSmall }
                            anchors.verticalCenter: parent.verticalCenter
                            width: 60
                        }
                        Text {
                            text: modelData.event
                            color: modelData.bound ? Root.Theme.accentPrimary : Root.Theme.textPrimary
                            font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeSmall }
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.args && modelData.args.length > 0
                                ? "[" + modelData.args.join(", ") + "]"
                                : ""
                            color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeSmall }
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }

    // Process: open hooks.json in $EDITOR (or fall back to xdg-open)
    Process {
        id: openHooksProc
        command: [
            "sh", "-c",
            "f=\"$HOME/.config/quickshell/hooks.json\"; " +
            "mkdir -p \"$HOME/.config/quickshell\"; " +
            "[ -f \"$f\" ] || echo '{}' > \"$f\"; " +
            "xdg-open \"$f\""
        ]
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
