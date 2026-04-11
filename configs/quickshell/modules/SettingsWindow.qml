import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import ".." as Root
import "../components" as Components
import "../core" as Core
import "settings" as SettingsPages

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
        { id: "connections", label: "Connections", icon: "󰀂" },
        { id: "display",     label: "Display",     icon: "󰃠" },
        { id: "preferences", label: "Preferences", icon: "󰒓" },
        { id: "hooks",       label: "Hooks",       icon: "󰢩" },
        { id: "about",       label: "About",       icon: "󰋽" }
    ]

    // ── Search index ──────────────────────────────────────────────────
    // Static index mapping every settable option to its page by STRING id.
    // Adding a new page does not require touching any other entries — the
    // id decouples search from `_pages` array position.
    readonly property var _searchIndex: [
        // Bar page
        { label: "Modules",            keywords: "bar layout enable disable",        page: "bar" },
        { label: "Floating bar",       keywords: "bar style float flat detach",      page: "bar" },
        { label: "Module groups",      keywords: "bar groups card background",       page: "bar" },
        { label: "CPU sparkline",      keywords: "cpu graph chart resource",         page: "bar" },
        { label: "Reorder Bar",        keywords: "bar drag rearrange",               page: "bar" },
        // Widgets page
        { label: "Desktop widgets",    keywords: "wallpaper widget enable",          page: "widgets" },
        { label: "Edit Widget Layout", keywords: "widget drag rearrange position",   page: "widgets" },
        { label: "Clock font size",    keywords: "clock time fontSize",              page: "widgets" },
        { label: "Show seconds",       keywords: "clock time seconds",               page: "widgets" },
        { label: "Show date",          keywords: "clock date",                       page: "widgets" },
        { label: "Use metric units",   keywords: "weather metric celsius units",     page: "widgets" },
        { label: "Weather font size",  keywords: "weather fontSize",                 page: "widgets" },
        { label: "Show CPU",           keywords: "system cpu",                       page: "widgets" },
        { label: "Show RAM",           keywords: "system ram memory",                page: "widgets" },
        { label: "System font size",   keywords: "system fontSize",                  page: "widgets" },
        { label: "Show album art",     keywords: "now playing media art",            page: "widgets" },
        { label: "Album art size",     keywords: "now playing media art size",       page: "widgets" },
        // Connections page
        { label: "Wi-Fi",              keywords: "wifi wireless network connect ssid password",        page: "connections" },
        { label: "Saved networks",     keywords: "wifi saved forget networks",                         page: "connections" },
        { label: "Hidden network",     keywords: "wifi hidden ssid manual connect",                    page: "connections" },
        { label: "Bluetooth",          keywords: "bluetooth pair device audio headphones",             page: "connections" },
        { label: "Rescan devices",     keywords: "bluetooth rescan discover refresh",                  page: "connections" },
        // Display page
        { label: "Night light",        keywords: "night light blue filter color temperature wlsunset", page: "display" },
        { label: "Day temperature",    keywords: "night light day kelvin temperature", page: "display" },
        { label: "Night temperature",  keywords: "night light night kelvin temperature", page: "display" },
        // Preferences page — CC cards
        { label: "CC Cards",           keywords: "control center cards toggle reorder", page: "preferences" },
        { label: "System monitor card", keywords: "cc card system monitor cpu ram",    page: "preferences" },
        { label: "Weather card",       keywords: "cc card weather temperature",        page: "preferences" },
        { label: "Calendar card",      keywords: "cc card calendar date month",        page: "preferences" },
        { label: "Player card",        keywords: "cc card player media music",         page: "preferences" },
        { label: "Network card",       keywords: "cc card network wifi",               page: "preferences" },
        // Preferences page — features
        { label: "Media popup",        keywords: "media popup floating",             page: "preferences" },
        { label: "Clipboard history",  keywords: "clipboard copy paste history",     page: "preferences" },
        { label: "Wallpaper selector", keywords: "wallpaper picker spotlight",       page: "preferences" },
        { label: "Wallpaper widgets",  keywords: "wallpaper widget layer",           page: "preferences" },
        { label: "Auto-hide widgets",  keywords: "auto hide widget windows",         page: "preferences" },
        { label: "Auto-hide bar",      keywords: "auto hide bar fullscreen",         page: "preferences" },
        { label: "Weather update",     keywords: "weather interval refresh timing",  page: "preferences" },
        { label: "System stats",       keywords: "system stats interval timing",     page: "preferences" },
        { label: "Notification timeout", keywords: "notification timeout timing",    page: "preferences" },
        { label: "Max clipboard items", keywords: "clipboard max history",           page: "preferences" },
        // Hooks page
        { label: "Hooks events",        keywords: "hooks events list signal scripts", page: "hooks" },
        { label: "Recent fires",        keywords: "hooks debug log fires history",    page: "hooks" },
        { label: "Edit hooks.json",     keywords: "hooks edit json open file",        page: "hooks" },
        { label: "Reload hooks",        keywords: "hooks reload refresh",             page: "hooks" },
        // About page
        { label: "Open Config Folder", keywords: "config folder open path",          page: "about" }
    ]

    // ── Page component registry ──
    // String id → Component. Inserting a new page means adding ONE entry
    // here and ONE entry in `_pages` — no switch cases, no search shifts.
    readonly property var _pageComponents: ({
        "bar":         barPage,
        "widgets":     widgetsPage,
        "connections": connectionsPage,
        "display":     displayPage,
        "preferences": preferencesPage,
        "hooks":       hooksPage,
        "about":       aboutPage
    })

    // Look up a page's numeric index from its id (for nav rail selection
    // state, which still uses int internally because the Repeater iterates
    // the ordered `_pages` array).
    function _pageIndexForId(id) {
        for (let i = 0; i < _pages.length; i++) {
            if (_pages[i].id === id) return i;
        }
        return -1;
    }

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
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: 1.0
            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
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
                            let page = win._pages[win._activePage];
                            return page ? (win._pageComponents[page.id] || null) : null;
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
                            text: {
                                let idx = win._pageIndexForId(modelData.page);
                                return idx >= 0 ? win._pages[idx].label : "";
                            }
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
                            // Jump to the page (looked up by id) and clear the search.
                            let idx = win._pageIndexForId(modelData.page);
                            if (idx >= 0) win._switchPage(idx);
                            win._searchQuery = "";
                            searchInput.text = "";
                        }
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }

    // ── Page component wrappers ─────────────────────────────────────────
    // Thin Components that instantiate the actual page files under
    // modules/settings/. Keeping them in SettingsWindow.qml (rather than
    // inlining in the Loader) lets the Loader pick one by key from
    // `_pageComponents` without re-creating the Component on every switch.
    Component { id: barPage;         SettingsPages.BarPage {} }
    Component { id: widgetsPage;     SettingsPages.WidgetsPage {} }
    Component { id: connectionsPage; SettingsPages.ConnectionsPage {} }
    Component { id: displayPage;     SettingsPages.DisplayPage {} }
    Component { id: preferencesPage; SettingsPages.PreferencesPage {} }
    Component { id: hooksPage;       SettingsPages.HooksPage {} }
    Component { id: aboutPage;       SettingsPages.AboutPage {} }
}
