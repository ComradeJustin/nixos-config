.pragma library

// Sample content for the shell mockup: the ring's stations, every page that
// can open inside the ring, and the notifications. Nothing here is read from
// the system.
//
// A page is { title, field, rows }.
//   field   optional line of text input at the top of the page:
//           { hint, filters, secret }. `filters` narrows the rows to those
//           that contain the typed text; `secret` shows dots instead of it.
//   rows    the lines of the page. Each is { label, kind, ... }:
//     kind "text"    label, then `value`
//     kind "line"    `label` across the whole width (no value)
//     kind "level"   a bar (`level` 0 to 1), then `value` at the right edge
//     kind "graph"   a history (`samples` 0 to 1), then `value` at the right edge
//     kind "switch"  on or off (`on`), then `value`
//     kind "signal"  signal bars (`level` 0 to 1), then `value`
//     kind "busy"    a spinner, then `value`
//   Any row may also have:
//     note    dim text at the right edge, e.g. an age
//     opens   the name of the page that enter opens (shown as "›")
//     does    "back" or "lock": what enter does instead of opening a page
//     alert   true when something is wrong; the value is in the alert colour

// The names on the ring, clockwise, and the page each one opens.
var stations = [
    { name: "Launch", page: "launch" },
    { name: "Clipboard", page: "clipboard" },
    { name: "System", page: "system" },
    { name: "Network", page: "network" },
    { name: "Media", page: "media" },
    { name: "Inbox", page: "inbox" },
    { name: "Session", page: "session" },
];

// The notifications the "notify" button cycles through.
var toasts = [
    { app: "Vesktop", title: "Mara", body: "are you still coming tonight?", actions: "reply · mark read", alert: false },
    { app: "nh", title: "Rebuild finished", body: "nixlaptop is on generation 412", actions: "show log", alert: false },
    { app: "Battery", title: "12% left", body: "about 25 minutes, plug in soon", actions: "power saver", alert: true },
];

// A made-up history for a graph: `count` samples from 0 to 1 in a wave that
// takes about `period` samples to rise and fall.
function history(count, period) {
    var samples = [];
    for (var index = 0; index < count; index++)
        samples.push(0.5 + 0.5 * Math.sin(index / period) * Math.cos(index / (period * 2.7)));
    return samples;
}

// Every page, by name. `state` holds the few values the mockup's buttons
// change: { volume, muted, brightness, battery, charging, online }.
function pages(state) {
    var batteryPercent = Math.round(state.battery * 100) + "%";
    var batteryLow = state.battery <= 0.2 && !state.charging;
    var batteryTime = state.charging ? "full in 50 min" : batteryLow ? "25 min left" : "2 h 10 min left";

    return {
        launch: {
            title: "Launch",
            field: { hint: "search apps", filters: true, secret: false },
            rows: [
                { label: "Firefox", kind: "text", value: "browser" },
                { label: "Ghostty", kind: "text", value: "terminal" },
                { label: "Cursor", kind: "text", value: "editor" },
                { label: "Files", kind: "text", value: "file manager" },
                { label: "Vesktop", kind: "text", value: "chat" },
                { label: "Spotify", kind: "text", value: "music" },
                { label: "Obsidian", kind: "text", value: "notes" },
                { label: "Steam", kind: "text", value: "games" },
                { label: "GIMP", kind: "text", value: "image editor" },
                { label: "mpv", kind: "text", value: "video player" },
                { label: "Calculator", kind: "text", value: "utility" },
                { label: "Settings", kind: "text", value: "this shell", opens: "settings" },
            ],
        },

        clipboard: {
            title: "Clipboard",
            field: { hint: "filter clipboard", filters: true, secret: false },
            rows: [
                { label: "git push -u origin shell-redesign", kind: "line", note: "1m" },
                { label: "readonly property int wipeMs: 140", kind: "line", note: "4m" },
                { label: "are you still coming tonight?", kind: "line", note: "9m" },
                { label: "sudo tailscale up --exit-node=nixpc", kind: "line", note: "22m" },
                { label: "#f1ae97", kind: "line", note: "31m" },
                { label: "journalctl --user -u shell-mockup", kind: "line", note: "40m" },
                { label: "image 1920 × 1080 png", kind: "line", note: "1h" },
                { label: "nixos-rebuild switch --flake .#nixpc", kind: "line", note: "1h" },
                { label: "192.168.1.24", kind: "line", note: "2h" },
                { label: "departuremono.com", kind: "line", note: "2h" },
                { label: "The quick brown fox jumps over the lazy dog", kind: "line", note: "3h" },
                { label: "Home-5G", kind: "line", note: "5h" },
                { label: "todo: lock screen", kind: "line", note: "6h" },
                { label: "nix build nixpkgs#nerd-fonts.departure-mono", kind: "line", note: "8h" },
            ],
        },

        system: {
            title: "System",
            rows: [
                { label: "Volume", kind: "level", value: state.muted ? "mute" : String(state.volume), level: state.muted ? 0 : state.volume / 100, alert: state.muted },
                { label: "Mixer", kind: "text", value: "3 apps playing", opens: "mixer" },
                { label: "Brightness", kind: "level", value: String(state.brightness), level: state.brightness / 100 },
                { label: "CPU", kind: "graph", value: "12%", samples: history(40, 3) },
                { label: "Power", kind: "text", value: batteryPercent + " · " + batteryTime, opens: "power", alert: batteryLow },
                { label: "Night light", kind: "switch", value: "until 07:00", on: true },
                { label: "Do not disturb", kind: "switch", value: "off", on: false },
                { label: "Keep awake", kind: "switch", value: "off", on: false },
                { label: "Settings", kind: "text", value: "", opens: "settings" },
            ],
        },

        mixer: {
            title: "Mixer",
            rows: [
                { label: "Spotify", kind: "level", value: "80", level: 0.8 },
                { label: "Firefox", kind: "level", value: "45", level: 0.45 },
                { label: "Vesktop", kind: "level", value: "100", level: 1 },
                { label: "Microphone", kind: "level", value: "60", level: 0.6 },
                { label: "Output", kind: "text", value: "Built-in speakers" },
                { label: "Input", kind: "text", value: "Built-in microphone" },
            ],
        },

        power: {
            title: "Power",
            rows: [
                { label: "Battery", kind: "level", value: batteryPercent, level: state.battery, alert: batteryLow },
                { label: "Time", kind: "text", value: batteryTime, alert: batteryLow },
                { label: "Charger", kind: "text", value: state.charging ? "plugged in, 45 W" : "not plugged in" },
                { label: "Power saver", kind: "switch", value: "", on: false },
                { label: "Balanced", kind: "switch", value: "", on: true },
                { label: "Performance", kind: "switch", value: "", on: false },
                { label: "Health", kind: "text", value: "91% of design capacity" },
            ],
        },

        settings: {
            title: "Settings",
            rows: [
                { label: "Wallpaper", kind: "text", value: "forest-mist.png", opens: "wallpaper" },
                { label: "Bar", kind: "text", value: "8 segments shown", opens: "barSegments" },
                { label: "Key bindings", kind: "text", value: "", opens: "keys" },
                { label: "Notifications", kind: "text", value: "shown for 4.5 s" },
                { label: "Lock", kind: "text", value: "after 3 min idle" },
                { label: "Suspend", kind: "text", value: "after 10 min idle" },
                { label: "Night light", kind: "text", value: "sunset to 07:00" },
                { label: "Font", kind: "text", value: "Departure Mono, 11 px" },
                { label: "About", kind: "text", value: "nixlaptop · NixOS 26.11" },
            ],
        },

        barSegments: {
            title: "Bar",
            rows: [
                { label: "Workspaces", kind: "switch", value: "left", on: true },
                { label: "Window title", kind: "switch", value: "left", on: true },
                { label: "Playing track", kind: "switch", value: "left", on: true },
                { label: "Notifications", kind: "switch", value: "left", on: true },
                { label: "Clock", kind: "switch", value: "centre", on: true },
                { label: "Network", kind: "switch", value: "right", on: true },
                { label: "Volume", kind: "switch", value: "right", on: true },
                { label: "Battery", kind: "switch", value: "right", on: true },
                { label: "CPU", kind: "switch", value: "right", on: false },
                { label: "Memory", kind: "switch", value: "right", on: false },
                { label: "Weather", kind: "switch", value: "centre", on: false },
                { label: "Tray", kind: "switch", value: "right", on: false },
            ],
        },

        wallpaper: {
            title: "Wallpaper",
            field: { hint: "filter wallpapers", filters: true, secret: false },
            rows: [
                { label: "forest-mist.png", kind: "line", note: "current" },
                { label: "dunes-at-dusk.jpg", kind: "line", note: "" },
                { label: "harbour-fog.jpg", kind: "line", note: "" },
                { label: "paper-cranes.png", kind: "line", note: "" },
                { label: "terminal-grid.png", kind: "line", note: "" },
                { label: "night-train.jpg", kind: "line", note: "" },
                { label: "red-cliffs.jpg", kind: "line", note: "" },
                { label: "snow-line.jpg", kind: "line", note: "" },
                { label: "tide-pools.jpg", kind: "line", note: "" },
                { label: "city-from-above.jpg", kind: "line", note: "" },
                { label: "dithered-moon.png", kind: "line", note: "" },
            ],
        },

        keys: {
            title: "Key bindings",
            field: { hint: "filter bindings", filters: true, secret: false },
            rows: [
                { label: "Mod+Space", kind: "text", value: "summon the ring" },
                { label: "Mod+Return", kind: "text", value: "open a terminal" },
                { label: "Mod+B", kind: "text", value: "open Firefox" },
                { label: "Mod+D", kind: "text", value: "clipboard history" },
                { label: "Mod+M", kind: "text", value: "settings" },
                { label: "Mod+P", kind: "text", value: "wallpaper" },
                { label: "Mod+N", kind: "text", value: "system page" },
                { label: "Mod+Escape", kind: "text", value: "session page" },
                { label: "Mod+Shift+Slash", kind: "text", value: "this list" },
                { label: "Super+Alt+L", kind: "text", value: "lock the screen" },
                { label: "Mod+W", kind: "text", value: "close window" },
                { label: "Mod+O", kind: "text", value: "overview" },
                { label: "Mod+H / L", kind: "text", value: "focus column left / right" },
                { label: "Mod+J / K", kind: "text", value: "focus window down / up" },
                { label: "Mod+Ctrl+H / L", kind: "text", value: "move column left / right" },
                { label: "Mod+Ctrl+J / K", kind: "text", value: "move window down / up" },
                { label: "Mod+Home / End", kind: "text", value: "first / last column" },
                { label: "Mod+Shift+H / L", kind: "text", value: "focus monitor left / right" },
                { label: "Mod+U / I", kind: "text", value: "workspace down / up" },
                { label: "Mod+Tab", kind: "text", value: "next window" },
                { label: "Mod+grave", kind: "text", value: "next window of this app" },
                { label: "Volume keys", kind: "text", value: "volume up, down, mute" },
                { label: "Brightness keys", kind: "text", value: "brightness up, down" },
            ],
        },

        network: {
            title: "Network",
            rows: [
                { label: "Wi-Fi", kind: "signal", value: state.online ? "Home-5G" : "not connected", level: state.online ? 0.75 : 0, opens: "wifi", alert: !state.online },
                { label: "Bluetooth", kind: "text", value: "2 devices connected", opens: "bluetooth" },
                { label: "Exit node", kind: "switch", value: "nixpc", on: state.online },
                { label: "Tailnet", kind: "text", value: state.online ? "4 devices online" : "unreachable", alert: !state.online },
                { label: "Traffic", kind: "graph", value: state.online ? "1.2M/s" : "0", samples: state.online ? history(40, 5) : [] },
            ],
        },

        wifi: {
            title: "Wi-Fi",
            rows: [
                { label: "Home-5G", kind: "signal", value: "connected", level: 0.75 },
                { label: "Home-2G", kind: "signal", value: "saved", level: 1 },
                { label: "Cafe-Guest", kind: "signal", value: "secured", level: 0.75, opens: "wifiPassword" },
                { label: "Library", kind: "signal", value: "open", level: 0.5 },
                { label: "Neighbour-5G", kind: "signal", value: "secured", level: 0.5, opens: "wifiPassword" },
                { label: "Printer-Setup", kind: "signal", value: "open", level: 0.5 },
                { label: "Flat-12", kind: "signal", value: "secured", level: 0.25, opens: "wifiPassword" },
                { label: "Office-Guest", kind: "signal", value: "secured", level: 0.25, opens: "wifiPassword" },
                { label: "Phone-Hotspot", kind: "signal", value: "secured", level: 0.25, opens: "wifiPassword" },
                { label: "Train-WiFi", kind: "signal", value: "open", level: 0.25 },
                { label: "Scan again", kind: "busy", value: "scanning" },
            ],
        },

        wifiPassword: {
            title: "Join Cafe-Guest",
            field: { hint: "password", filters: false, secret: true },
            rows: [
                { label: "Connect", kind: "text", value: "", does: "back" },
                { label: "Show password", kind: "switch", value: "", on: false },
                { label: "Cancel", kind: "text", value: "", does: "back" },
            ],
        },

        bluetooth: {
            title: "Bluetooth",
            rows: [
                { label: "Bluetooth", kind: "switch", value: "on", on: true },
                { label: "WH-1000XM5", kind: "text", value: "connected", note: "80%" },
                { label: "MX Master 3", kind: "text", value: "connected", note: "55%" },
                { label: "Keychron K2", kind: "text", value: "paired" },
                { label: "Pixel 9", kind: "text", value: "paired" },
                { label: "Find devices", kind: "busy", value: "scanning" },
            ],
        },

        media: {
            title: "Media",
            rows: [
                { label: "Shelter", kind: "level", value: "1:32/3:38", level: 0.42 },
                { label: "Artist", kind: "text", value: "Porter Robinson & Madeon" },
                { label: "Player", kind: "text", value: "Spotify" },
                { label: "Pause", kind: "text", value: "" },
                { label: "Next track", kind: "text", value: "" },
                { label: "Previous track", kind: "text", value: "" },
            ],
        },

        inbox: {
            title: "Inbox",
            rows: [
                { label: "Mara", kind: "text", value: "are you still coming tonight?", note: "2m" },
                { label: "nh", kind: "busy", value: "Rebuilding nixlaptop" },
                { label: "Vesktop", kind: "text", value: "3 new messages in #general", note: "14m" },
                { label: "Tailscale", kind: "text", value: "nixpc came online", note: "1h" },
                { label: "Battery", kind: "text", value: "12% left", note: "2h", alert: true },
                { label: "Firefox", kind: "text", value: "Download finished", note: "3h" },
                { label: "Do not disturb", kind: "switch", value: "off", on: false },
                { label: "Dismiss all", kind: "text", value: "" },
            ],
        },

        session: {
            title: "Session",
            rows: [
                { label: "Lock", kind: "text", value: "", does: "lock" },
                { label: "Suspend", kind: "text", value: "" },
                { label: "Log out", kind: "text", value: "", opens: "confirmLogOut" },
                { label: "Restart", kind: "text", value: "", opens: "confirmRestart" },
                { label: "Power off", kind: "text", value: "", opens: "confirmPowerOff" },
            ],
        },

        // Anything that ends the session asks first, with "Cancel" selected.
        confirmLogOut: {
            title: "Log out?",
            rows: [
                { label: "Cancel", kind: "text", value: "", does: "back" },
                { label: "Log out now", kind: "text", value: "3 windows will close", does: "back", alert: true },
            ],
        },

        confirmRestart: {
            title: "Restart?",
            rows: [
                { label: "Cancel", kind: "text", value: "", does: "back" },
                { label: "Restart now", kind: "text", value: "3 windows will close", does: "back", alert: true },
            ],
        },

        confirmPowerOff: {
            title: "Power off?",
            rows: [
                { label: "Cancel", kind: "text", value: "", does: "back" },
                { label: "Power off now", kind: "text", value: "3 windows will close", does: "back", alert: true },
            ],
        },
    };
}
