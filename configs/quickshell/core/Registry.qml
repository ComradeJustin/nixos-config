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
        { key: "systemStats", consumers: ["bar.resource", "widget.system"] }
    ]

    // ── Bar modules ──
    // key: unique id, label: display name, section: left/center/right, file: true if file-based
    readonly property var barModules: [
        { key: "power",     label: "Power",     section: "left",   file: true, group: "power" },
        { key: "workspace", label: "Workspace", section: "left",   file: true, group: "nav" },
        { key: "time",      label: "Time",      section: "left",   file: true, group: "nav" },
        { key: "weather",   label: "Weather",   section: "left",   file: true, group: "weather", services: ["weather"] },
        { key: "window",    label: "Window",    section: "left",   file: true, group: "window" },
        { key: "media",     label: "Media",     section: "center", file: true, group: "media", services: ["player"] },
        { key: "resource",  label: "Resources", section: "right",  file: true, group: "stats" },
        { key: "audio",     label: "Audio",     section: "right",  file: true, group: "conn", services: ["audio"] },
        { key: "network",   label: "Network",   section: "right",  file: true, group: "conn", services: ["wifi"] },
        { key: "bluetooth", label: "Bluetooth", section: "right",  file: true, group: "conn", services: ["bluetooth"] },
        { key: "battery",   label: "Battery",   section: "right",  file: true, group: "battery" },
        { key: "tray",      label: "Tray",      section: "right",  file: true, group: "utils" },
        { key: "gear",      label: "Settings",  section: "right",  file: true, group: "utils" }
    ]

    // ── Widgets ──
    readonly property var widgets: [
        { key: "clock",      label: "Clock",       configKey: "clock",      positionKey: "clockWidgetPosition",      defaultPos: "bottom-right" },
        { key: "weather",    label: "Weather",      configKey: "weather",    positionKey: "weatherWidgetPosition",    defaultPos: "top-right",    services: ["weather"] },
        { key: "system",     label: "System",       configKey: "system",     positionKey: "systemWidgetPosition",     defaultPos: "top-left" },
        { key: "quote",      label: "Quote",        configKey: "quote",      positionKey: "quoteWidgetPosition",      defaultPos: "bottom-center" },
        { key: "nowPlaying", label: "Now Playing",  configKey: "nowPlaying", positionKey: "nowPlayingWidgetPosition", defaultPos: "bottom-left",  services: ["player"] },
        { key: "calendar",   label: "Calendar",     configKey: "calendar",   positionKey: "calendarWidgetPosition",   defaultPos: "center-left" },
        { key: "stock",      label: "Stocks",       configKey: "stock",      positionKey: "stockWidgetPosition",      defaultPos: "center-right" }
    ]

    // ── Spotlight views ──
    readonly property var spotlightViews: [
        { key: "launcher",  label: "Apps",      icon: "󰍃", configKey: "enableClipboardHistory" },
        { key: "clipboard", label: "Clipboard", icon: "󰅍", configKey: "enableClipboardHistory" },
        { key: "wallpaper", label: "Wallpaper", icon: "󰸉", configKey: "enableWallpaperSelector" }
    ]

    // ── Quick toggles (for ControlCenter) ──
    // stateProp: which service property reflects the toggle state
    // invertState: if true, isOn = !service[stateProp] (e.g. audio: isOn when NOT muted)
    readonly property var quickToggles: [
        { key: "wifi",      iconOn: "󰤨", iconOff: "󰤭", accent: "domainNetwork",       service: "wifi",        action: "toggle",     stateProp: "enabled" },
        { key: "dnd",       iconOn: "󰂛", iconOff: "󰂚", accent: "domainNotifications", service: "notif",       action: "toggleDnd",  stateProp: "dnd" },
        { key: "mute",      iconOn: "󰕾", iconOff: "󰖁", accent: "domainMedia",         service: "audio",       action: "toggleMute", stateProp: "muted", invertState: true },
        { key: "bluetooth", iconOn: "󰂯", iconOff: "󰂲", accent: "domainNetwork",       service: "bluetooth",   action: "toggle",     stateProp: "enabled" },
        { key: "caffeine",  iconOn: "󰛊", iconOff: "󰛩", accent: "caffeineAccent",      service: "idleInhibit", action: "toggle",     stateProp: "inhibited" }
    ]
}
