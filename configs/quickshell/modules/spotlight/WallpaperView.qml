import QtQuick
import QtQuick.Effects
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

// Wallpaper selector view for the Spotlight popup.
// Scans directory once at startup, applies wallpapers via awww.
// Thumbnails are cached to ~/.cache/quickshell/wallpaper-thumbs/
SpotlightProvider {
    id: root
    implicitWidth: parent ? parent.width : 560
    implicitHeight: wpInner.implicitHeight

    // ── Provider identity ──
    providerKey: "wallpaper"
    providerLabel: "Wallpaper"
    providerIcon: "󰸉"
    hasSearch: true
    hasGrid: true
    preferredWidth: Root.Theme.wpWidth
    preferredMaxHeight: Root.Theme.wpMaxHeight

    // ── Provider interface ──
    function activate() { resetSearch(); refresh(); scrollToCurrent(); }
    function deactivate() {}
    function handleSearchText(text) {
        searchText = text;
        selectedIndex = 0;
        updateFilter();
        onSearchTextChanged();
    }
    // Grid nav: wallpaper uses 2D movement
    function moveUp() { if (selectedIndex >= columns) selectedIndex -= columns; ensureVisible(); }
    function moveDown() { if (selectedIndex + columns < filteredIndices.length) selectedIndex += columns; else selectedIndex = filteredIndices.length - 1; ensureVisible(); }
    function moveLeft() { if (selectedIndex > 0) selectedIndex--; ensureVisible(); }
    function moveRight() { if (selectedIndex < filteredIndices.length - 1) selectedIndex++; ensureVisible(); }
    function accept() { applySelected(); }

    // Theme is now a singleton - access via Root.Theme.propertyName

    signal wallpaperSet()
    signal searchRequested(string text)

    // When a tag pill is clicked, switch search to tag ID syntax
    function tagClicked(tagId, tagName) {
        let newSearch = "id:" + tagId;
        searchText = newSearch;
        selectedIndex = 0;
        searchOnline(newSearch);
        searchRequested(newSearch);
    }

    // ── Wallpaper service (data/IO lives here; this view is pure UI) ──
    readonly property var wpService: Core.ServiceManager.wallpaper

    // Read-only proxies so the UI bindings below reach the service unchanged.
    readonly property var wpModel: wpService ? wpService.wallpapers : null
    readonly property string currentWallpaper: wpService ? wpService.currentWallpaper : ""
    readonly property bool scanned: wpService ? wpService.scanned : false
    readonly property var onlineResults: wpService ? wpService.onlineResults : []
    readonly property bool onlineSearching: wpService ? wpService.onlineSearching : false
    readonly property string onlineQuery: wpService ? wpService.onlineQuery : ""
    readonly property int onlinePage: wpService ? wpService.onlinePage : 1
    readonly property int onlineTotalPages: wpService ? wpService.onlineTotalPages : 1
    readonly property bool onlineLoadingMore: wpService ? wpService.onlineLoadingMore : false
    readonly property var tagSuggestions: wpService ? wpService.tagSuggestions : []

    // ── View-local UI state ──
    property string searchText: ""
    property int selectedIndex: 0
    property var filteredIndices: []
    property string mode: "local"  // "local" or "online"

    // ── Wallhaven search-form options (passed to the service per query) ──
    property bool catGeneral: true     // categories bitmask: General=1
    property bool catAnime: true       // Anime=2
    property bool catPeople: false     // People=4
    property bool purSfw: true         // purity bitmask: SFW=1
    property bool purSketchy: false    // Sketchy=2
    property string minResolution: "1920x1080"
    property bool showSettings: false
    property string onlineSorting: "relevance"  // relevance|date_added|random|views|favorites|toplist|hot

    // React to service-side scan completion / wallpaper application.
    Connections {
        target: root.wpService
        function onRescanned() { root.updateFilter(); root.scrollToCurrent(); }
        function onWallpaperApplied() { root.wallpaperSet(); }
    }

    // Called when the view opens.
    function refresh() {
        if (!wpService) return;
        if (wpService.scanned) updateFilter();
        else wpService.ensureScanned();   // emits rescanned() → updateFilter()
        wpService.queryCurrent();
    }

    function updateFilter() {
        let indices = [];
        let query = searchText.toLowerCase();
        let model = wpModel;
        let count = model ? model.count : 0;
        for (let i = 0; i < count; i++) {
            let label = model.get(i).wpLabel.toLowerCase();
            if (query.length === 0 || label.indexOf(query) !== -1)
                indices.push(i);
        }
        filteredIndices = indices;
        resultCount = indices.length;
        totalCount = count;
        if (selectedIndex >= indices.length)
            selectedIndex = Math.max(0, indices.length - 1);
    }

    function resetSearch() {
        searchText = "";
        selectedIndex = 0;
        updateFilter();
        if (wpService) wpService.resetOnline();
    }

    // Scroll to and select the current wallpaper in the filtered list
    function scrollToCurrent() {
        if (currentWallpaper.length === 0 || filteredIndices.length === 0) return;
        for (let i = 0; i < filteredIndices.length; i++) {
            let item = wpModel.get(filteredIndices[i]);
            if (item && item.wpPath === currentWallpaper) {
                selectedIndex = i;
                ensureVisible();
                return;
            }
        }
    }

    // Debounced online search trigger — call when searchText changes in online mode
    function onSearchTextChanged() {
        if (mode === "online") {
            onlineDebounce.restart();
            // Also trigger tag suggestions for short queries
            if (searchText.trim().length >= 2 && searchText.trim().length <= 20)
                tagDebounce.restart();
            else if (wpService)
                wpService.clearTags();
        }
    }

    Timer {
        id: onlineDebounce
        interval: 400
        onTriggered: {
            if (root.mode === "online" && root.searchText.trim().length > 0)
                root.searchOnline(root.searchText, 1);
        }
    }

    // Tag suggestion lookup — searches Wallhaven's tag endpoint
    Timer {
        id: tagDebounce
        interval: 300
        onTriggered: {
            if (root.mode === "online" && root.searchText.trim().length >= 2 && root.wpService)
                root.wpService.searchTags(root.searchText);
        }
    }

    property int columns: Math.max(1, Math.floor((root.width - Root.Theme.notifPadding * 2 + Root.Theme.wpSpacing) / (Root.Theme.wpThumbWidth + Root.Theme.wpSpacing)))

    function applySelected() {
        if (filteredIndices.length === 0 || !wpService) return;
        let idx = filteredIndices[selectedIndex];
        let item = wpModel.get(idx);
        if (item) wpService.apply(item.wpPath);   // → wallpaperApplied → wallpaperSet
    }

    function ensureVisible() {
        let itemH = Root.Theme.wpThumbHeight + 24;  // Must match wpCard height
        let row = Math.floor(selectedIndex / columns);
        let y = row * (itemH + Root.Theme.wpSpacing);
        if (y < wpFlick.contentY)
            wpFlick.contentY = y;
        else if (y + itemH > wpFlick.contentY + wpFlick.height)
            wpFlick.contentY = y + itemH - wpFlick.height;
    }

    // Online search — delegates to the wallpaper service.
    function searchOnline(query, page) {
        let p = page || 1;
        if (p === 1) selectedIndex = 0;
        if (wpService)
            wpService.searchOnline(query, p, {
                categories: whCategories(),
                purity: whPurity(),
                resolution: minResolution,
                sorting: onlineSorting
            });
    }

    // Load next page of results — delegates to the service.
    function loadMoreOnline() {
        if (wpService)
            wpService.loadMore({
                categories: whCategories(),
                purity: whPurity(),
                resolution: minResolution,
                sorting: onlineSorting
            });
    }

    // Build Wallhaven API filter strings from the search-form toggles.
    function whCategories() { return (catGeneral ? "1" : "0") + (catAnime ? "1" : "0") + (catPeople ? "1" : "0"); }
    function whPurity() { return (purSfw ? "1" : "0") + (purSketchy ? "1" : "0") + "0"; }

    // Download online wallpaper then apply — delegates to the service.
    function downloadAndApply(url) {
        if (wpService) wpService.downloadAndApply(url);
    }

    Column {
        id: wpInner
        width: parent.width
        spacing: 0

        // Mode toggle: Local | Online | Settings gear
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Root.Theme.spacingXS
            height: 28
            topPadding: 4
            bottomPadding: 4

            Rectangle {
                width: 70; height: 24; radius: Root.Theme.radiusSmall
                color: root.mode === "local" ? Root.Theme.accentPrimary : "transparent"
                Text {
                    anchors.centerIn: parent; text: "Local"
                    color: root.mode === "local" ? Root.Theme.barBackground : Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS; bold: root.mode === "local" }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mode = "local" }
            }
            Rectangle {
                width: 70; height: 24; radius: Root.Theme.radiusSmall
                color: root.mode === "online" ? Root.Theme.accentPrimary : "transparent"
                Text {
                    anchors.centerIn: parent; text: "Online"
                    color: root.mode === "online" ? Root.Theme.barBackground : Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS; bold: root.mode === "online" }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mode = "online" }
            }

            // Settings gear (online mode only)
            Rectangle {
                visible: root.mode === "online"
                width: 24; height: 24; radius: Root.Theme.radiusSmall
                color: root.showSettings
                    ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.15)
                    : "transparent"
                Text {
                    anchors.centerIn: parent; text: "󰒓"
                    color: root.showSettings ? Root.Theme.textAccent : Root.Theme.textDimmed
                    font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSizeM }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.showSettings = !root.showSettings }
            }
        }

        // ── Wallhaven filter settings panel ──
        Column {
            id: settingsPanel
            visible: root.mode === "online" && root.showSettings
            width: parent.width
            spacing: 6
            topPadding: 4
            bottomPadding: 8
            leftPadding: Root.Theme.notifPadding
            rightPadding: Root.Theme.notifPadding

            // Categories row
            Row {
                spacing: 6
                Text {
                    text: "Category"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                    width: 55; y: 3
                }
                Repeater {
                    model: [
                        { label: "General", prop: "catGeneral" },
                        { label: "Anime",   prop: "catAnime" },
                        { label: "People",  prop: "catPeople" }
                    ]
                    Rectangle {
                        required property var modelData
                        width: labelText.implicitWidth + 14; height: 20; radius: 10
                        color: root[modelData.prop]
                            ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.2)
                            : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.1)
                        border.width: root[modelData.prop] ? 1 : 0
                        border.color: Root.Theme.textAccent
                        Text {
                            id: labelText; anchors.centerIn: parent
                            text: modelData.label
                            color: root[modelData.prop] ? Root.Theme.textAccent : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root[modelData.prop] = !root[modelData.prop]
                        }
                    }
                }
            }

            // Purity row
            Row {
                spacing: 6
                Text {
                    text: "Purity"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                    width: 55; y: 3
                }
                Repeater {
                    model: [
                        { label: "SFW",     prop: "purSfw" },
                        { label: "Sketchy", prop: "purSketchy" }
                    ]
                    Rectangle {
                        required property var modelData
                        width: purLabel.implicitWidth + 14; height: 20; radius: 10
                        color: root[modelData.prop]
                            ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.2)
                            : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.1)
                        border.width: root[modelData.prop] ? 1 : 0
                        border.color: Root.Theme.textAccent
                        Text {
                            id: purLabel; anchors.centerIn: parent
                            text: modelData.label
                            color: root[modelData.prop] ? Root.Theme.textAccent : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root[modelData.prop] = !root[modelData.prop]
                        }
                    }
                }
            }

            // Resolution row
            Row {
                spacing: 6
                Text {
                    text: "Min res"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                    width: 55; y: 3
                }
                Repeater {
                    model: ["1920x1080", "2560x1440", "3840x2160"]
                    Rectangle {
                        required property string modelData
                        width: resLabel.implicitWidth + 14; height: 20; radius: 10
                        property bool active: root.minResolution === modelData
                        color: active
                            ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.2)
                            : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.1)
                        border.width: active ? 1 : 0
                        border.color: Root.Theme.textAccent
                        Text {
                            id: resLabel; anchors.centerIn: parent
                            text: modelData === "1920x1080" ? "1080p" : modelData === "2560x1440" ? "1440p" : "4K"
                            color: active ? Root.Theme.textAccent : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.minResolution = modelData
                        }
                    }
                }
            }

            // Sort row
            Row {
                spacing: 6
                Text {
                    text: "Sort"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                    width: 55; y: 3
                }
                Repeater {
                    model: [
                        { label: "Relevant", value: "relevance" },
                        { label: "Hot",      value: "hot" },
                        { label: "Latest",   value: "date_added" },
                        { label: "Random",   value: "random" },
                        { label: "Top",      value: "toplist" }
                    ]
                    Rectangle {
                        required property var modelData
                        property bool active: root.onlineSorting === modelData.value
                        width: sortLabel.implicitWidth + 14; height: 20; radius: 10
                        color: active
                            ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.2)
                            : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.1)
                        border.width: active ? 1 : 0
                        border.color: Root.Theme.textAccent
                        Text {
                            id: sortLabel; anchors.centerIn: parent
                            text: modelData.label
                            color: active ? Root.Theme.textAccent : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.onlineSorting = modelData.value
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width - Root.Theme.notifPadding * 2; height: 1
                color: Root.Theme.textDimmed; opacity: 0.15
            }
        }

        // ── Tag suggestions (shown when typing in online mode) ──
        Flow {
            visible: root.mode === "online" && root.tagSuggestions.length > 0 && root.searchText.trim().length >= 2
            width: parent.width - Root.Theme.notifPadding * 2
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Root.Theme.spacingXS
            topPadding: 4
            bottomPadding: 4

            Text {
                text: "Tags:"
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXXS }
                height: 18
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: root.tagSuggestions.length
                Rectangle {
                    property var tag: root.tagSuggestions[index]
                    width: tagName.implicitWidth + 10; height: 18; radius: 9
                    color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.1)
                    Text {
                        id: tagName; anchors.centerIn: parent
                        text: tag ? tag.name : ""
                        color: tagMouse.containsMouse ? Root.Theme.textAccent : Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXXS }
                    }
                    MouseArea {
                        id: tagMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Clicking a tag replaces the search with the tag ID syntax
                            let tag = root.tagSuggestions[index];
                            if (tag) root.tagClicked(tag.id, tag.name);
                        }
                    }
                }
            }
        }

        // Online results grid
        Item {
            visible: root.mode === "online"
            width: parent.width
            height: visible ? onlineContent.height : 0

            Column {
                id: onlineContent
                width: parent.width
                spacing: 0

                Text {
                    visible: root.onlineSearching
                    text: "Searching..."
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.notifBodySize }
                    width: parent.width; height: 60
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }

                Text {
                    visible: !root.onlineSearching && root.onlineResults.length === 0 && root.onlineQuery.length > 0
                    text: "No results"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.notifBodySize }
                    width: parent.width; height: 60
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }

                Text {
                    visible: !root.onlineSearching && root.onlineResults.length === 0 && root.onlineQuery.length === 0
                    text: "Type a search to find wallpapers"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.notifBodySize }
                    width: parent.width; height: 60
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }

                Components.SmoothFlickable {
                    id: onlineFlick
                    visible: root.onlineResults.length > 0
                    width: parent.width
                    height: Math.min(onlineGridCol.height + Root.Theme.wpSpacing * 2, root.maxContentHeight - 28 - (root.showSettings ? settingsPanel.height : 0) - (root.tagSuggestions.length > 0 ? 30 : 0) - 20)
                    contentHeight: onlineGridCol.height + Root.Theme.wpSpacing * 2
                    clip: true

                    Column {
                        id: onlineGridCol
                        y: Root.Theme.wpSpacing
                        width: parent.width
                        spacing: Root.Theme.wpSpacing

                        Grid {
                            id: onlineGrid
                            columns: root.columns
                            spacing: Root.Theme.wpSpacing
                            property int gridWidth: columns * Root.Theme.wpThumbWidth + (columns - 1) * Root.Theme.wpSpacing
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: gridWidth

                            Repeater {
                                model: root.onlineResults.length

                                Rectangle {
                                    id: onlineCard
                                    width: Root.Theme.wpThumbWidth
                                    height: Root.Theme.wpThumbHeight + 24
                                    radius: 8

                                    property var entry: root.onlineResults[index]
                                    property bool isSelected: root.mode === "online" && index === root.selectedIndex

                                    color: isSelected
                                        ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.12)
                                        : onlineMouse.containsMouse
                                          ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06)
                                          : "transparent"

                                    Column {
                                        anchors.fill: parent; anchors.margins: Root.Theme.spacingXS; spacing: 2

                                        Item {
                                            width: parent.width; height: Root.Theme.wpThumbHeight

                                            Rectangle {
                                                anchors.fill: parent; radius: 6
                                                color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.15)
                                            }

                                            Rectangle {
                                                id: onlineMask
                                                anchors.fill: parent; radius: 6; visible: false
                                                layer.enabled: true
                                            }

                                            Image {
                                                id: onlineThumb
                                                anchors.fill: parent
                                                source: onlineCard.entry ? onlineCard.entry.thumbUrl : ""
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true; smooth: true
                                                sourceSize.width: Root.Theme.wpThumbWidth * 2
                                                sourceSize.height: Root.Theme.wpThumbHeight * 2
                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    maskEnabled: true
                                                    maskSource: onlineMask
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent; color: "transparent"; radius: 6
                                                border.width: onlineCard.isSelected ? 2 : 0
                                                border.color: Root.Theme.textAccent
                                            }
                                        }

                                        Text {
                                            width: parent.width
                                            text: onlineCard.entry ? onlineCard.entry.resolution : ""
                                            color: onlineCard.isSelected ? Root.Theme.textPrimary : Root.Theme.textDimmed
                                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                                            elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        id: onlineMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedIndex = index;
                                            if (onlineCard.entry) root.downloadAndApply(onlineCard.entry.url);
                                        }
                                        onPositionChanged: root.selectedIndex = index
                                    }
                                }
                            }
                        }

                        // "Load more" button — appears at the bottom of the grid
                        Rectangle {
                            visible: root.onlinePage < root.onlineTotalPages && !root.onlineSearching
                            width: 120; height: 28; radius: 14
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: loadMoreMouse.containsMouse
                                ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.2)
                                : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.1)
                            border.width: 1
                            border.color: loadMoreMouse.containsMouse ? Root.Theme.textAccent : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.2)

                            Text {
                                anchors.centerIn: parent
                                text: root.onlineLoadingMore ? "Loading…" : "Load more (" + root.onlinePage + "/" + root.onlineTotalPages + ")"
                                color: loadMoreMouse.containsMouse ? Root.Theme.textAccent : Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                            }

                            MouseArea {
                                id: loadMoreMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.loadMoreOnline()
                            }
                        }
                    }
                }
            }
        }

        // Local view
        Text {
            visible: root.mode === "local" && filteredIndices.length === 0
            text: !root.scanned ? "Scanning…" : "No matches"
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.notifBodySize }
            width: parent.width; height: 60
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Components.SmoothFlickable {
            id: wpFlick
            visible: root.mode === "local" && filteredIndices.length > 0
            width: parent.width
            height: Math.min(gridContent.height + Root.Theme.wpSpacing * 2, root.maxContentHeight - 48)  // 28px mode toggle + 20px footer
            contentHeight: gridContent.height + Root.Theme.wpSpacing * 2
            clip: true

            Grid {
                id: gridContent
                y: Root.Theme.wpSpacing
                columns: root.columns
                spacing: Root.Theme.wpSpacing
                // Center the grid horizontally
                property int gridWidth: columns * Root.Theme.wpThumbWidth + (columns - 1) * Root.Theme.wpSpacing
                anchors.horizontalCenter: parent.horizontalCenter
                width: gridWidth

                Repeater {
                    model: root.filteredIndices.length

                    Rectangle {
                        id: wpCard
                        width: Root.Theme.wpThumbWidth
                        height: Root.Theme.wpThumbHeight + 24
                        radius: 8

                        property int sourceIndex: root.filteredIndices[index] ?? -1
                        property var entry: sourceIndex >= 0 ? wpModel.get(sourceIndex) : null
                        property bool isCurrent: entry ? entry.wpPath === root.currentWallpaper : false
                        property bool isSelected: index === root.selectedIndex

                        color: isSelected
                            ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.12)
                            : wpMouse.containsMouse
                              ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06)
                              : "transparent"

                        Column {
                            anchors.fill: parent
                            anchors.margins: Root.Theme.spacingXS
                            spacing: 2

                            Item {
                                id: thumbContainer
                                width: parent.width
                                height: Root.Theme.wpThumbHeight

                                // Background placeholder
                                Rectangle {
                                    id: thumbBg
                                    anchors.fill: parent
                                    radius: 6
                                    color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.15)
                                }

                                // Mask used by MultiEffect for rounded corners
                                Rectangle {
                                    id: thumbMask
                                    anchors.fill: parent
                                    radius: 6
                                    visible: false
                                    layer.enabled: true
                                }

                                // Thumbnail image with rounded corners via MultiEffect
                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    source: wpCard.entry ? "file://" + (wpCard.entry.wpThumb || wpCard.entry.wpPath) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                    sourceSize.width: Root.Theme.wpThumbWidth * 2
                                    sourceSize.height: Root.Theme.wpThumbHeight * 2
                                    cache: true
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: thumbMask
                                    }
                                }

                                // Border overlays
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"; radius: 6
                                    border.width: wpCard.isCurrent ? 2 : 0
                                    border.color: Root.Theme.textAccent
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"; radius: 6
                                    border.width: wpCard.isSelected ? 2 : 0
                                    border.color: Root.Theme.textPrimary
                                    opacity: 0.5
                                    visible: wpCard.isSelected && !wpCard.isCurrent
                                }
                            }

                            Text {
                                width: parent.width
                                text: wpCard.entry ? wpCard.entry.wpLabel : ""
                                color: wpCard.isCurrent ? Root.Theme.textAccent
                                     : wpCard.isSelected ? Root.Theme.textPrimary
                                     : Root.Theme.textDimmed
                                font {
                                    family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS
                                    bold: wpCard.isCurrent || wpCard.isSelected
                                }
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            id: wpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.selectedIndex = index; root.applySelected(); }
                            onPositionChanged: root.selectedIndex = index
                        }
                    }
                }
            }
        }

        // ── Result count footer ──
        Text {
            visible: (root.mode === "local" && filteredIndices.length > 0) ||
                     (root.mode === "online" && onlineResults.length > 0)
            text: {
                if (root.mode === "online") {
                    let s = onlineResults.length + " results";
                    if (root.onlineTotalPages > 1)
                        s += " · page " + root.onlinePage + "/" + root.onlineTotalPages;
                    return s;
                }
                return searchText.length > 0
                    ? filteredIndices.length + " of " + wpModel.count + " wallpapers"
                    : wpModel.count + " wallpapers";
            }
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
            width: parent.width; height: 20
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: 0.6
        }
    }
}
