import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import ".." as Root
import "../components" as Components
import "../core" as Core
import "controlcenter" as CCTabs
import "controlcenter/cards" as CCCards

Scope {
    id: cc

    property bool showing: false
    property string activeTab: "notifications"
    // Accordion-style tab content: collapsed by default, clicking the
    // active tab toggles expansion; clicking an inactive tab switches
    // and forces expanded. Reset to false on close so every open
    // starts compact.
    property bool tabExpanded: false
    property bool showHistory: showing

    // Self-wired via ServiceManager
    readonly property var audioService: Core.ServiceManager.audio
    readonly property var brightnessService: Core.ServiceManager.brightness
    readonly property var notifService: Core.ServiceManager.notif
    readonly property var idleInhibitService: Core.ServiceManager.idleInhibit

    // Effective bar height including floating margins
    readonly property int _barTotal: Root.Config.bar.style === "float" ? Root.Theme.barHeight + 12 : Root.Theme.barHeight

    function toggle() {
        showing = !showing;
        if (showing) {
            ccPanel.visible = true;
            if (notifService) notifService.unreadCount = 0;
            if (audioService) { audioService.refreshApps(); audioService.refreshDevices(); }
            if (notifService) notifService.rebuildStacks();
        } else {
            // Reset accordion state so the next open starts collapsed.
            tabExpanded = false;
        }
    }
    function toggleHistory() { toggle(); }

    Timer {
        interval: 2000
        running: cc.showing && cc.activeTab === "volume"
        onTriggered: { if (cc.audioService) cc.audioService.refreshApps(); }
    }

    // ── Toast popups (stacked by app) ──
    // Panel is flush to the right screen edge so toasts can slide
    // in from off-screen, matching the CC's enter/exit style.
    // notifMarginRight is applied as internal padding instead.
    PanelWindow {
        id: toastPanel
        visible: cc.notifService ? cc.notifService.popupStacks.count > 0 : false
        anchors { top: true; right: true }
        margins.top: cc._barTotal + Root.Theme.notifMarginTop
        margins.right: 0
        implicitWidth: Root.Theme.notifWidth + Root.Theme.notifMarginRight
        implicitHeight: toastCol.implicitHeight
        WlrLayershell.namespace: "quickshell-toasts"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        Column {
            id: toastCol
            width: parent.width
            spacing: Root.Theme.notifSpacing

            Repeater {
                model: cc.notifService ? cc.notifService.popupStacks : null

                Item {
                    id: toastItem
                    width: toastCol.width
                    // Collapse height smoothly when dismissing
                    implicitHeight: toastCard.height
                    height: implicitHeight
                    clip: true

                    property string appKey: model.appName
                    // Resting x: inset by the right margin so card doesn't touch screen edge
                    readonly property real _restX: 0
                    // Off-screen x: card fully past the right edge of the panel
                    readonly property real _offX: toastItem.width

                    Component.onCompleted: {
                        toastCard.x = _offX;
                        toastItem.opacity = 0;
                        if (model.dismissing) {
                            toastItem.opacity = 0;
                        } else {
                            appearAnim.start();
                        }
                    }

                    // Slide in from the screen edge
                    ParallelAnimation {
                        id: appearAnim
                        NumberAnimation { target: toastCard; property: "x"; to: toastItem._restX; duration: Root.Theme.anim.slideDuration; easing.type: Easing.OutCubic }
                        NumberAnimation { target: toastItem; property: "opacity"; to: 1; duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic }
                    }

                    // Slide back out to the edge, then collapse height
                    SequentialAnimation {
                        id: dismissAnim
                        ParallelAnimation {
                            NumberAnimation { target: toastCard; property: "x"; to: toastItem._offX; duration: Root.Theme.anim.slideDuration; easing.type: Easing.InOutCubic }
                            NumberAnimation { target: toastItem; property: "opacity"; to: 0; duration: Root.Theme.anim.slideDuration; easing.type: Easing.InCubic }
                        }
                        NumberAnimation { target: toastItem; property: "height"; to: 0; duration: Root.Theme.animFast; easing.type: Easing.InCubic }
                        ScriptAction { script: { if (cc.notifService) cc.notifService.removePopupApp(toastItem.appKey); } }
                    }

                    property bool isDismissing: model.dismissing
                    onIsDismissingChanged: { if (isDismissing && !dismissAnim.running) dismissAnim.start(); }

                    Rectangle {
                        id: toastCard
                        width: Root.Theme.notifWidth
                        height: toastContent.implicitHeight
                        radius: Root.Theme.notifRadius
                        color: Root.Theme.notifBackground
                        property int _urg: model.urgency !== undefined ? model.urgency : 1
                        border.width: _urg !== 1 ? 2 : Root.Theme.borderWidth
                        border.color: _urg === 2 ? Root.Theme.notifUrgentBorder
                                    : _urg === 0 ? Root.Theme.notifLowBorder
                                    : Root.Theme.borderColor

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.rgba(0, 0, 0, 0.35)
                            shadowBlur: 1.0
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }

                        Components.NotificationCard {
                            id: toastContent
                            width: parent.width
                            appName: model.appName
                            summary: model.summary
                            body: model.body
                            imagePath: model.imagePath
                            count: model.count
                            compact: false
                        }

                        MouseArea {
                            id: toastMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (cc.notifService) cc.notifService.dismissPopupApp(model.appName); }
                            onEntered: {
                                countdownBar.paused = true;
                                countdownAnim.pause();
                                if (cc.notifService) cc.notifService.pausePopups(model.appName);
                            }
                            onExited: {
                                countdownBar.paused = false;
                                countdownAnim.resume();
                                if (cc.notifService) cc.notifService.resumePopups(model.appName);
                            }
                        }

                        // Auto-dismiss countdown — depletes left→right over the
                        // toast's lifetime, then freezes while hovered (toastMouse).
                        Rectangle {
                            id: countdownBar
                            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 10; bottomMargin: 5 }
                            width: Math.max(0, (toastCard.width - 20) * fraction)
                            height: 3
                            radius: 1.5
                            visible: model.expiry !== undefined && model.expiry > 0 && !toastItem.isDismissing
                            color: toastCard._urg === 2 ? Root.Theme.notifUrgentBorder
                                 : toastCard._urg === 0 ? Root.Theme.notifLowBorder
                                 : Root.Theme.accentPrimary
                            opacity: 0.8

                            property real fraction: 1
                            property bool paused: false
                            property int _total: 5000

                            // Refill + restart when a new notification joins the
                            // group (a higher count extends the underlying expiry).
                            property int trackCount: model.count
                            onTrackCountChanged: if (!paused) countdownBar.restart()

                            Component.onCompleted: countdownBar.restart()
                            function restart() {
                                var rem = Math.max(1, (model.expiry || (Date.now() + 5000)) - Date.now());
                                countdownAnim.stop();
                                countdownBar._total = rem;
                                countdownBar.fraction = 1;
                                countdownAnim.start();
                                if (countdownBar.paused) countdownAnim.pause();
                            }

                            NumberAnimation {
                                id: countdownAnim
                                target: countdownBar
                                property: "fraction"
                                from: 1; to: 0
                                duration: countdownBar._total
                                easing.type: Easing.Linear
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Click-outside dismiss scrim ──
    PanelWindow {
        id: ccScrim
        visible: cc.showing
        anchors { top: true; bottom: true; left: true; right: true }
        // Push below the bar so clicks on bar modules (gear, etc.)
        // reach the bar surface instead of being swallowed here.
        margins.top: cc._barTotal
        WlrLayershell.namespace: "quickshell-cc-scrim"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: cc.showing = false
        }
    }

    // ── Panel ──
    PanelWindow {
        id: ccPanel
        visible: false
        anchors { top: true; right: true; bottom: true }
        margins.top: cc._barTotal + 6
        margins.bottom: 6
        margins.right: 0
        implicitWidth: Root.Theme.ccWidth + 6
        WlrLayershell.namespace: "quickshell-cc"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        FocusScope {
            anchors.fill: parent
            focus: cc.showing

            Keys.onEscapePressed: cc.showing = false
            // Left/Right: switch tabs without changing expand state
            Keys.onLeftPressed: {
                let idx = tabBar.activeIndex;
                if (idx > 0) cc.activeTab = tabBar.tabs[idx - 1].tab;
            }
            Keys.onRightPressed: {
                let idx = tabBar.activeIndex;
                if (idx < tabBar.tabs.length - 1) cc.activeTab = tabBar.tabs[idx + 1].tab;
            }
            // Up/Down: expand/collapse the active tab's accordion
            Keys.onUpPressed: cc.tabExpanded = false
            Keys.onDownPressed: cc.tabExpanded = true

            // ── Notification keyboard navigation ──
            // j/k = move selection, d = dismiss, Enter = expand/collapse
            Keys.onPressed: function(event) {
                if (cc.activeTab !== "notifications" || !cc.tabExpanded) return;
                if (event.key === Qt.Key_J) {
                    notifTab.moveDown(); event.accepted = true;
                } else if (event.key === Qt.Key_K) {
                    notifTab.moveUp(); event.accepted = true;
                } else if (event.key === Qt.Key_D) {
                    notifTab.dismissSelected(); event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    notifTab.activateSelected(); event.accepted = true;
                }
            }

            Rectangle {
                id: ccRect
                width: Root.Theme.ccWidth
                // Top-anchored and auto-sized to content, but capped
                // to panel height so the card never overflows the
                // screen edge — this keeps the footer visible and
                // bottom corners rounded.
                anchors.top: parent.top
                height: Math.min(mainLayout.implicitHeight + Root.Theme.ccPadding * 2 + ccFooter._reservedHeight, parent.height - 6)

                // Animation driver for tab content expansion. contentFactor
                // smoothly interpolates 0→1 when cc.tabExpanded flips, and
                // the tab content Item below binds its Layout.preferredHeight
                // and opacity to this single scalar. Everything downstream —
                // mainLayout.implicitHeight, ccRect.height, the visible
                // growing card — follows automatically through the binding
                // chain. One Behavior, whole layout animates.
                property real contentFactor: cc.tabExpanded ? 1 : 0
                Behavior on contentFactor { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                // Height of the footer row when visible (count + clear button)
                readonly property int _footerHeight: ccFooter.visible ? 34 : 0
                // Computed max height for the tab content. We take the
                // tab content's y position (set by the layout engine)
                // once it's rendered to know exactly how much vertical
                // space sits above it, then subtract from the panel.
                // tabContentItem.y is relative to mainLayout, add ccPadding for the layout's top margin
                readonly property int maxTabContentHeight: Math.max(120, parent.height - tabContentItem.y - Root.Theme.ccPadding * 2 - _footerHeight)

                radius: Root.Theme.radiusMedium
                color: Root.Theme.barBackground
                x: cc.showing ? 0 : (Root.Theme.ccWidth + 6)
                Behavior on x { NumberAnimation { duration: Root.Theme.anim.slideDuration; easing.type: Easing.OutCubic } }
                onXChanged: { if (!cc.showing && x >= Root.Theme.ccWidth + 5) ccPanel.visible = false; }

                // Left-edge shadow: a gradient strip instead of
                // MultiEffect so there's no corner bleed on the
                // transparent panel window.
                Rectangle {
                    anchors { right: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 6
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.25) }
                    }
                }

                // ── CC body ──
                // ColumnLayout lets the tab content area use Layout.fillHeight
                // instead of the fragile `parent.height - 289 - ...` math the
                // old plain Column required. That in turn lets us freely add
                // new sections (cards, banners, etc.) without re-tuning a
                // magic number every time.
                ColumnLayout {
                    id: mainLayout
                    // Top-anchored only (not fill) so our implicit height
                    // can flow upward to ccRect. `anchors.fill: parent`
                    // would make ColumnLayout a slave to parent height,
                    // which would itself depend on our implicit height —
                    // a circular dependency.
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: Root.Theme.ccPadding
                    }
                    // 10px is the "major rhythm" spacing between CCSections;
                    // inner Columns (slider stack, cards column) stay at 6
                    // to create a visible hierarchy of major vs. minor gaps.
                    spacing: 10

                    // ── Profile slot (dedicated top card) ──
                    // Pulled out of the cards area so it has a fixed
                    // position as the CC's "header". Keeping it in
                    // cardLayout would let the user reorder it, but it
                    // consistently makes more sense as the identity
                    // surface at the top of the panel. Visibility still
                    // honors Config.cc.cards.profile for opt-out.
                    Components.ProfileCard {
                        Layout.fillWidth: true
                        compact: true
                        visible: Root.Config.cc.cards.profile
                    }

                    // ── Quick toggles (in a CCSection pill) ──
                    // Noctalia-style: the toggle row sits in its own rounded
                    // strip so it reads as a group rather than floating icons.
                    // Header row is gone — ProfileCard below carries the
                    // Settings/Lock/Power actions, so a separate title bar
                    // would just be redundant chrome.
                    Components.CCSection {
                        Layout.fillWidth: true
                        padding: Root.Theme.spacingXS
                        // Explicit height: QuickToggle is 40x40, plus
                        // 4px padding top+bottom → 48px total. CCSection's
                        // auto-sizing can't feed off anchor-centered
                        // children, so we declare the height directly.
                        implicitHeight: 48

                        Row {
                            anchors.centerIn: parent
                            spacing: Root.Theme.spacingS

                            Repeater {
                                model: Core.Registry.quickToggles
                                Components.QuickToggle {
                                    required property var modelData
                                    property var svc: Core.ServiceManager[modelData.service]
                                    // Hide toggles whose service isn't available (e.g. power profiles on desktops)
                                    visible: !modelData.requireProp || (svc && svc[modelData.requireProp])
                                    isOn: {
                                        if (!svc) return false;
                                        let val = svc[modelData.stateProp];
                                        return modelData.invertState ? !val : !!val;
                                    }
                                    iconOn: modelData.iconOn
                                    iconOff: modelData.iconOff
                                    accent: Root.Theme[modelData.accent]
                                    onToggled: { if (svc && typeof svc[modelData.action] === "function") svc[modelData.action](); }
                                    onSecondaryAction: {
                                        if (!modelData.settingsPage) return;
                                        cc.showing = false;
                                        let sw = Core.ServiceManager.settingsWindow;
                                        if (sw) sw.open(modelData.settingsPage);
                                    }
                                }
                            }
                        }
                    }

                    // ── Always-visible sliders (volume + brightness) ──
                    // CCSliderRow already paints its own ccSectionBg pill so
                    // we don't wrap these in an outer CCSection — the rows
                    // ARE sections, just each in its own strip. Stacking
                    // them in a plain Column preserves the uniform-strip
                    // look without the double-background cost.
                    Column {
                        Layout.fillWidth: true
                        spacing: 6

                        Components.CCSliderRow {
                            width: parent.width
                            icon: (cc.audioService && cc.audioService.muted) ? Root.Icons.volMute : Root.Icons.volHigh
                            iconColor: (cc.audioService && cc.audioService.muted) ? Root.Theme.textDimmed : Root.Theme.domainMedia
                            accentColor: Root.Theme.domainMedia
                            value: cc.audioService ? cc.audioService.volume : 0
                            iconClickable: true
                            onIconClicked: if (cc.audioService) cc.audioService.toggleMute()
                            onValueUpdated: function(v) { if (cc.audioService) cc.audioService.setVolume(Math.round(v)); }
                        }

                        Components.CCSliderRow {
                            width: parent.width
                            visible: cc.brightnessService && cc.brightnessService.available
                            icon: Root.Icons.brightnessIcon(cc.brightnessService ? cc.brightnessService.brightness : 0)
                            iconColor: Root.Theme.domainTime
                            accentColor: Root.Theme.domainTime
                            value: cc.brightnessService ? cc.brightnessService.brightness : 0
                            onValueUpdated: function(v) { if (cc.brightnessService) cc.brightnessService.setBrightness(Math.round(v)); }
                        }
                    }

                    // ── Cards area ──
                    // Moved above the tab bar so the vertical flow reads
                    // header → toggles → sliders → cards → tabs → content.
                    // Previously cards sat between the tab bar and the tab
                    // content which made them look like they belonged to a
                    // specific tab.
                    //
                    // Data-driven: iterates Config.cc.cardLayout, filters by
                    // Config.cc.cards[key] enables, and dispatches each card
                    // key to a local Component via sourceComponent.
                    Column {
                        id: ccCardsCol
                        Layout.fillWidth: true
                        spacing: 6
                        visible: enabledKeys.length > 0

                        // Data-driven enabledKeys with per-card runtime
                        // gating. A card only gets instantiated if:
                        //   (a) the user has it toggled on in Config, AND
                        //   (b) the card's service has something to show.
                        // The service-state access inside this getter is
                        // what makes hiding reactive — QML re-evaluates
                        // the binding when e.g. player.hasMedia flips.
                        readonly property var enabledKeys: {
                            let out = [];
                            let layout = Root.Config.cc.cardLayout || [];
                            for (let i = 0; i < layout.length; i++) {
                                let k = layout[i];
                                if (!Root.Config.cc.cards[k]) continue;
                                // Profile is rendered in a dedicated top
                                // slot above the toggles — don't also
                                // render it inside the cards area.
                                if (k === "profile") continue;
                                // Player card hides when nothing is playing —
                                // no point taking 160px of CC real estate to
                                // say "Nothing playing".
                                if (k === "player") {
                                    let ps = Core.ServiceManager.player;
                                    if (!ps || !ps.hasMedia) continue;
                                }
                                out.push(k);
                            }
                            return out;
                        }

                        // Data-driven card map — adding a card means:
                        //   1. Create the QML file in cards/
                        //   2. Register in cards/qmldir
                        //   3. Add a Component + map entry here
                        // No switch statement to maintain.
                        property var cardComponentMap: ({
                            "player":        playerCardComp,
                            "network":       networkCardComp,
                            "bluetooth":     bluetoothCardComp,
                            "nightLight":    nightLightCardComp,
                            "systemMonitor": systemMonitorCardComp,
                            "serverStatus":  serverStatusCardComp,
                            "weather":       weatherCardComp,
                            "calendar":      calendarCardComp
                        })

                        Repeater {
                            model: ccCardsCol.enabledKeys

                            Components.StaggerReveal {
                                id: cardReveal
                                required property int index
                                required property var modelData
                                width: ccCardsCol.width
                                staggerIndex: index
                                baseDelay: 130          // let the panel slide in first
                                shown: cc.showing

                                Loader {
                                    width: parent.width
                                    height: item ? item.implicitHeight : 0
                                    active: true
                                    sourceComponent: ccCardsCol.cardComponentMap[cardReveal.modelData] || null
                                }
                            }
                        }

                        Component { id: playerCardComp;         CCCards.PlayerCard        {} }
                        Component { id: networkCardComp;        CCCards.NetworkCard       {} }
                        Component { id: bluetoothCardComp;      CCCards.BluetoothCard     {} }
                        Component { id: nightLightCardComp;     CCCards.NightLightCard    {} }
                        Component { id: systemMonitorCardComp;  CCCards.SystemMonitorCard {} }
                        Component { id: serverStatusCardComp;   CCCards.ServerStatusCard  {} }
                        Component { id: weatherCardComp;        CCCards.WeatherCard       {} }
                        Component { id: calendarCardComp;       CCCards.CalendarCard      {} }
                    }

                    // ── Tab bar ──
                    // Pill-style: wrapped in a CCSection so it reads as a
                    // segmented control rather than a jarring underline bar.
                    // The active tab gets a filled rounded background in its
                    // accent color (alpha-ed) instead of the old 2px sliding
                    // underline — more modern, less visually "loud".
                    Components.CCSection {
                        id: tabBar
                        Layout.fillWidth: true
                        padding: Root.Theme.spacingXS

                        // Count hint callable — evaluated at render time
                        // per tab so the labels pick up "Notifications (3)"
                        // or "Mixer (2)" naturally. Returns empty string
                        // when there's nothing to report, so the label
                        // stays clean when counts are zero.
                        function countFor(key) {
                            if (key === "notifications") {
                                let n = cc.notifService ? cc.notifService.items.length : 0;
                                return n > 0 ? " (" + n + ")" : "";
                            }
                            if (key === "volume") {
                                let a = cc.audioService && cc.audioService.appStreams ? cc.audioService.appStreams.count : 0;
                                return a > 0 ? " (" + a + ")" : "";
                            }
                            return "";
                        }

                        property var tabs: [
                            { tab: "notifications", icon: Root.Icons.bell, label: "Notifications", accent: Root.Theme.domainNotifications },
                            { tab: "volume", icon: Root.Icons.volHigh, label: "Mixer", accent: Root.Theme.domainMedia }
                        ]

                        property int activeIndex: {
                            for (let i = 0; i < tabs.length; i++)
                                if (tabs[i].tab === cc.activeTab) return i;
                            return 0;
                        }

                        implicitHeight: 32

                        // Sliding filled pill indicator. The `x` binding
                        // animates as activeIndex changes, giving the same
                        // "slide between segments" feel the old underline
                        // had, but with a filled pill footprint.
                        Rectangle {
                            id: tabPill
                            width: (parent.width - (tabBar.tabs.length - 1) * 2) / tabBar.tabs.length
                            height: parent.height
                            radius: Root.Theme.ccSectionRadius - 2
                            color: Qt.rgba(tabBar.tabs[tabBar.activeIndex].accent.r,
                                           tabBar.tabs[tabBar.activeIndex].accent.g,
                                           tabBar.tabs[tabBar.activeIndex].accent.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(tabBar.tabs[tabBar.activeIndex].accent.r,
                                                  tabBar.tabs[tabBar.activeIndex].accent.g,
                                                  tabBar.tabs[tabBar.activeIndex].accent.b, 0.35)
                            x: tabBar.activeIndex * (width + 2)

                            Behavior on x { NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Root.Theme.anim.moveDuration } }
                            Behavior on border.color { ColorAnimation { duration: Root.Theme.anim.moveDuration } }
                        }

                        Row {
                            anchors.fill: parent
                            spacing: 2

                            Repeater {
                                model: tabBar.tabs

                                Item {
                                    id: tabItem
                                    width: (parent.width - (tabBar.tabs.length - 1) * 2) / tabBar.tabs.length
                                    height: parent.height

                                    // 2F: hover background. Only visible
                                    // on non-active tabs (the active tab
                                    // already has the tabPill behind it)
                                    // to avoid overlapping fills.
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Root.Theme.ccSectionRadius - 2
                                        visible: cc.activeTab !== modelData.tab
                                        opacity: tabMouse.containsMouse ? 1 : 0
                                        color: Root.Theme.layer1Hover
                                        Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.microDuration } }
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.icon
                                            color: cc.activeTab === modelData.tab ? modelData.accent : (tabMouse.containsMouse ? Root.Theme.textPrimary : Root.Theme.textDimmed)
                                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXL }
                                            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            // 1C: append count hint to the label. Zero-count tabs
                                            // get an empty suffix so they don't carry dead weight.
                                            text: modelData.label + tabBar.countFor(modelData.tab)
                                            color: cc.activeTab === modelData.tab ? Root.Theme.textPrimary : (tabMouse.containsMouse ? Root.Theme.textPrimary : Root.Theme.textDimmed)
                                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS; bold: cc.activeTab === modelData.tab }
                                            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                                        }
                                        // 2E: chevron on active tab only. Rotates 180° when
                                        // the accordion is expanded so the affordance is
                                        // obvious at a glance: ▾ collapsed → ▴ expanded.
                                        // Non-active tabs don't show the chevron so the
                                        // active-tab affordance is unambiguous.
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: cc.activeTab === modelData.tab
                                            text: "▾"
                                            color: modelData.accent
                                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                                            rotation: cc.tabExpanded ? 180 : 0
                                            Behavior on rotation { NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabMouse
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (cc.activeTab === modelData.tab) {
                                                // Clicking the already-active tab toggles expansion —
                                                // this is the "accordion" affordance. First click
                                                // opens it, second click closes it.
                                                cc.tabExpanded = !cc.tabExpanded;
                                            } else {
                                                // Switching tabs forces the expansion on, so the
                                                // user always gets visible feedback when moving
                                                // between tabs.
                                                cc.activeTab = modelData.tab;
                                                cc.tabExpanded = true;
                                            }
                                            if (cc.activeTab === "volume" && cc.audioService) {
                                                cc.audioService.refreshApps();
                                                cc.audioService.refreshDevices();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Tab content (accordion) ──
                    // Layout.preferredHeight is driven by ccRect.contentFactor
                    // (0..1 animated scalar). opacity is bound to the same
                    // factor so content fades in as it extends. clip: true
                    // is required to keep the not-yet-revealed content from
                    // bleeding past the shrinking box during the animation.
                    //
                    // Note the inversion here: the old layout had this Item
                    // claim whatever space was left (fillHeight). Now this
                    // Item DECIDES how much space exists (preferredHeight),
                    // and mainLayout.implicitHeight flows the decision all
                    // the way up to ccRect.
                    Item {
                        id: tabContentItem
                        Layout.fillWidth: true
                        Layout.preferredHeight: ccRect.maxTabContentHeight * ccRect.contentFactor
                        clip: true
                        opacity: ccRect.contentFactor
                        visible: opacity > 0.001

                        CCTabs.NotificationsTab {
                            id: notifTab
                            anchors.fill: parent
                            visible: opacity > 0
                            notifService: cc.notifService
                            opacity: cc.activeTab === "notifications" ? 1 : 0
                            transform: Translate {
                                y: cc.activeTab === "notifications" ? 0 : 6
                                Behavior on y { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
                            }
                            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
                        }

                        CCTabs.VolumeTab {
                            anchors.fill: parent
                            visible: opacity > 0
                            audioService: cc.audioService
                            opacity: cc.activeTab === "volume" ? 1 : 0
                            transform: Translate {
                                y: cc.activeTab === "volume" ? 0 : 6
                                Behavior on y { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
                            }
                            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
                        }
                    }

                }

                // ── Footer ──
                // Pinned to the bottom of ccRect, outside mainLayout,
                // so it's never pushed out by tab content overflow.
                Item {
                    id: ccFooter
                    // Total space reserved: height + bottom margin + spacing from content above
                    readonly property int _reservedHeight: visible ? height + Root.Theme.ccPadding + 6 : 0
                    anchors {
                        left: parent.left; right: parent.right; bottom: parent.bottom
                        leftMargin: Root.Theme.ccPadding; rightMargin: Root.Theme.ccPadding
                        bottomMargin: Root.Theme.ccPadding
                    }
                    height: 24
                    visible: cc.activeTab === "notifications" && cc.notifService && cc.notifService.items.length > 0

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: {
                            let c = cc.notifService ? cc.notifService.items.length : 0;
                            return c + " notification" + (c !== 1 ? "s" : "");
                        }
                        color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                    }

                    Rectangle {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: clearText.implicitWidth + 12; height: 22
                        radius: Root.Theme.radiusSmall
                        color: clearMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.08) : "transparent"

                        Text {
                            id: clearText
                            anchors.centerIn: parent
                            text: Root.Icons.trash + " Clear"
                            color: clearMouse.containsMouse ? Root.Theme.textPrimary : Root.Theme.textDimmed
                            font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSizeS }
                        }
                        MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.notifService) cc.notifService.clearAll(); } }
                    }
                }
            }
        }
    }
}
