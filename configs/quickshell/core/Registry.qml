pragma Singleton
import QtQuick

// Central registry of all modules, widgets, services, and views.
// Consumers filter by Config enables. Data-driven UI construction.
QtObject {
    id: registry

    // ── Services ──
    // key: unique id, source: QML file path, consumers: which modules/widgets need it
    readonly property var services: [
        { key: "audio",       consumers: ["bar.audio", "cc", "osd"] },
        { key: "player",      consumers: ["bar.media", "widget.nowPlaying"] },
        { key: "power",       consumers: ["powerMenu"] },
        { key: "notif",       consumers: ["cc"] },
        { key: "wifi",        consumers: ["bar.network", "cc"] },
        { key: "bluetooth",   consumers: ["bar.bluetooth", "cc"] },
        { key: "brightness",  consumers: ["osd"] },
        { key: "window",      consumers: ["widgetOverlay"] },
        { key: "idleInhibit", consumers: ["cc"] },
        { key: "weather",     consumers: ["bar.weather", "widget.weather"] },
        { key: "systemStats", consumers: ["bar.resource", "widget.system"] },
        { key: "hooks",       consumers: ["all"] }
    ]

    // ── Bar modules ──
    // key: unique id, label: display name, section: left/center/right, file: true if file-based
    readonly property var barModules: [
        { key: "power",     label: "Power",     section: "left",   file: "modules/barmodules/PowerModule.qml",     group: "power" },
        { key: "workspace", label: "Workspace", section: "left",   file: "modules/barmodules/WorkspaceModule.qml", group: "nav" },
        { key: "time",      label: "Time",      section: "left",   file: "modules/barmodules/TimeModule.qml",      group: "nav" },
        { key: "weather",   label: "Weather",   section: "left",   file: "modules/barmodules/WeatherModule.qml",   group: "weather", services: ["weather"] },
        { key: "window",    label: "Window",    section: "left",   file: "modules/barmodules/WindowModule.qml",    group: "window" },
        { key: "media",     label: "Media",     section: "center", file: "modules/barmodules/MediaModule.qml",     group: "media", services: ["player"] },
        { key: "resource",  label: "Resources", section: "right",  file: "modules/barmodules/ResourceModule.qml",  group: "stats" },
        { key: "audio",     label: "Audio",     section: "right",  file: "modules/barmodules/AudioModule.qml",     group: "conn", services: ["audio"] },
        { key: "network",   label: "Network",   section: "right",  file: "modules/barmodules/NetworkModule.qml",   group: "conn", services: ["wifi"] },
        { key: "bluetooth", label: "Bluetooth", section: "right",  file: "modules/barmodules/BluetoothModule.qml", group: "conn", services: ["bluetooth"] },
        { key: "vpn",       label: "VPN",       section: "right",  file: "modules/barmodules/VpnModule.qml",       group: "conn" },
        { key: "battery",   label: "Battery",   section: "right",  file: "modules/barmodules/BatteryModule.qml",   group: "battery" },
        { key: "caffeine",  label: "Caffeine",  section: "right",  file: "modules/barmodules/CaffeineModule.qml",  group: "utils", services: ["idleInhibit"] },
        { key: "tray",      label: "Tray",      section: "right",  file: "modules/barmodules/TrayModule.qml",      group: "utils" },
        { key: "gear",      label: "Settings",  section: "right",  file: "modules/barmodules/GearModule.qml",      group: "utils" }
    ]

    // ── Widgets ──
    readonly property var widgets: [
        { key: "clock",      label: "Clock",       file: "widgets/ClockWidget.qml",      configKey: "clock",      positionKey: "clockWidgetPosition",      defaultPos: "bottom-right" },
        { key: "weather",    label: "Weather",      file: "widgets/WeatherWidget.qml",    configKey: "weather",    positionKey: "weatherWidgetPosition",    defaultPos: "top-right",    services: ["weather"] },
        { key: "system",     label: "System",       file: "widgets/SystemWidget.qml",     configKey: "system",     positionKey: "systemWidgetPosition",     defaultPos: "top-left" },
        { key: "quote",      label: "Quote",        file: "widgets/QuoteWidget.qml",      configKey: "quote",      positionKey: "quoteWidgetPosition",      defaultPos: "bottom-center" },
        { key: "nowPlaying", label: "Now Playing",  file: "widgets/NowPlayingWidget.qml", configKey: "nowPlaying", positionKey: "nowPlayingWidgetPosition", defaultPos: "bottom-left",  services: ["player"] },
        { key: "calendar",   label: "Calendar",     file: "widgets/CalendarWidget.qml",   configKey: "calendar",   positionKey: "calendarWidgetPosition",   defaultPos: "center-left" },
        { key: "stock",      label: "Stocks",       file: "widgets/StockWidget.qml",      configKey: "stock",      positionKey: "stockWidgetPosition",      defaultPos: "center-right" }
    ]

    // ── Spotlight views ──
    readonly property var spotlightViews: [
        { key: "launcher",   label: "Apps",       icon: "󰍃", configKey: "enableClipboardHistory" },
        { key: "clipboard",  label: "Clipboard",  icon: "󰅍", configKey: "enableClipboardHistory" },
        { key: "wallpaper",  label: "Wallpaper",  icon: "󰸉", configKey: "enableWallpaperSelector" },
        { key: "calculator", label: "Calculator", icon: "󰃬", configKey: "" },
        { key: "emoji",      label: "Emoji",      icon: "󰞅", configKey: "" }
    ]

    // ── Control Center cards (scaffold) ──
    // Declarative registry of pluggable "cards" that render inside the
    // Control Center panel (below the tab bar content). Consumers resolve
    // `file` via a Loader. Cards opt in via Config.cc.cards[key] and are
    // rendered in the order specified by Config.cc.layout.
    //
    // Contract per card:
    //   key:         unique id, used as Config.cc.cards[key] enable flag
    //   label:       human-readable name (for Settings page listing)
    //   icon:        nerd-font glyph
    //   file:        path to the QML component (relative to quickshell/ root)
    //   services:    service keys this card needs — CC will lazy-load them
    //   settingsPage: optional — right-clicking the card header opens this page
    //
    // This is a scaffold: no consumer wired yet. See ControlCenter.qml
    // integration marker `CC_CARDS_AREA` for where the Repeater will land.
    readonly property var ccCards: [
        { key: "profile",    label: "Profile",    icon: "󰀄", file: "components/ProfileCard.qml",                    services: ["systemStats"] },
        { key: "network",    label: "Network",    icon: "󰤨", file: "modules/controlcenter/cards/NetworkCard.qml",    services: ["wifi"],        settingsPage: "connections" },
        { key: "bluetooth",  label: "Bluetooth",  icon: "󰂯", file: "modules/controlcenter/cards/BluetoothCard.qml",  services: ["bluetooth"],   settingsPage: "connections" },
        { key: "nightLight", label: "Night Light", icon: "󰽥", file: "modules/controlcenter/cards/NightLightCard.qml", services: [],              settingsPage: "display" },
        { key: "player",        label: "Now Playing",    icon: "󰎆", file: "modules/controlcenter/cards/PlayerCard.qml",        services: ["player"] },
        { key: "systemMonitor", label: "System Monitor", icon: "󰍹", file: "modules/controlcenter/cards/SystemMonitorCard.qml", services: ["systemStats"] },
        { key: "weather",       label: "Weather",        icon: "󰖙", file: "modules/controlcenter/cards/WeatherCard.qml",       services: ["weather"] },
        { key: "calendar",      label: "Calendar",       icon: "󰃶", file: "modules/controlcenter/cards/CalendarCard.qml",      services: [] },
        { key: "serverStatus", label: "Server Status",  icon: "󰒋", file: "modules/controlcenter/cards/ServerStatusCard.qml",  services: [] }
    ]

    // ── Quick toggles (for ControlCenter) ──
    // stateProp: which service property reflects the toggle state
    // invertState: if true, isOn = !service[stateProp] (e.g. audio: isOn when NOT muted)
    // settingsPage: optional — right-click opens this Settings page id
    readonly property var quickToggles: [
        { key: "wifi",      iconOn: "󰤨", iconOff: "󰤭", accent: "domainNetwork",       service: "wifi",        action: "toggle",     stateProp: "enabled",                       settingsPage: "connections" },
        { key: "dnd",       iconOn: "󰂛", iconOff: "󰂚", accent: "domainNotifications", service: "notif",       action: "toggleDnd",  stateProp: "dnd",                           settingsPage: "preferences" },
        { key: "mute",      iconOn: "󰕾", iconOff: "󰖁", accent: "domainMedia",         service: "audio",       action: "toggleMute", stateProp: "muted", invertState: true },
        { key: "bluetooth", iconOn: "󰂯", iconOff: "󰂲", accent: "domainNetwork",       service: "bluetooth",   action: "toggle",     stateProp: "enabled",                       settingsPage: "connections" },
        { key: "caffeine",  iconOn: "󰛊", iconOff: "󰛩", accent: "caffeineAccent",      service: "idleInhibit", action: "toggle",     stateProp: "inhibited",                     settingsPage: "preferences" },
        { key: "powerProfile", iconOn: "󰗑", iconOff: "󰌪", accent: "domainPower",    service: "powerProfile", action: "cycleProfile", stateProp: "profile", requireProp: "available", settingsPage: "preferences" }
    ]
}
