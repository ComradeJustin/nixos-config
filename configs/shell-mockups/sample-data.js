.pragma library

// Sample content for the shell mockup: the ring's stations, every page that
// can open inside the ring, the notifications, the dialogs, the monitor's
// applets and the desktop widgets.
// Nothing here is read from the system.
//
// A page is { title, field, rows, empty }.
//   empty   what to say when the page has no rows to show
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
//     does    what enter does instead of opening a page: "back", "lock",
//             "monitor" (open the monitor) or "dismissAll" (empty the inbox)
//     image   a picture to preview beside the page while the row is selected
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

// The wallpapers in this repository, for the wallpaper page. The paths are
// relative to this directory.
var wallpaperFolder = "../../assets/wallpapers/";
var wallpapers = [
    "wallpaper.png",
    "moon.jpg",
    "paper-airplane-balcony.jpg",
    "glt_gruvbox.png",
    "frute.jpg",
    "sparkle.jpg",
    "albertep.jpg",
    "wallhaven-pk6g1j.jpg",
    "wallhaven-l3d1mp.jpg",
    "wallhaven-6klm2w.jpg",
    "wallhaven-x8ylyd.jpg",
    "wallhaven-3qweed.jpg",
];

function wallpaperRows() {
    var rows = [];
    for (var index = 0; index < wallpapers.length; index++)
        rows.push({ label: wallpapers[index], kind: "line", note: index === 0 ? "current" : "", image: wallpaperFolder + wallpapers[index] });
    return rows;
}

// Every page, by name. `state` holds the few values the mockup's buttons
// change: { volume, muted, brightness, battery, charging, online, trouble,
// inboxEmpty }. `trouble` is the sample state in which things have gone
// wrong: no network, Bluetooth off, a failed build.
function pages(state) {
    var batteryPercent = Math.round(state.battery * 100) + "%";
    var batteryLow = state.battery <= 0.2 && !state.charging;
    var batteryTime = state.charging ? "full in 50 min" : batteryLow ? "25 min left" : "2 h 10 min left";

    return {
        launch: {
            title: "Launch",
            field: { hint: "search windows and apps", filters: true, secret: false },
            empty: "nothing matches",
            rows: [
                // Open windows come first: enter switches to one.
                { label: "Cursor", kind: "text", value: "nixos-config", note: "window 2" },
                { label: "Firefox", kind: "text", value: "Departure Mono", note: "window 2" },
                { label: "Ghostty", kind: "text", value: "~/nixos-config", note: "window 1" },
                { label: "Vesktop", kind: "text", value: "#general", note: "window 3" },
                // Then apps: enter starts one.
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
            empty: "nothing matches",
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

        // The System station holds controls. Things to watch (processor,
        // memory, battery detail, builds) are in the monitor.
        system: {
            title: "System",
            rows: [
                { label: "Volume", kind: "level", value: state.muted ? "mute" : String(state.volume), level: state.muted ? 0 : state.volume / 100, alert: state.muted },
                { label: "Mixer", kind: "text", value: "3 apps playing", opens: "mixer" },
                { label: "Brightness", kind: "level", value: String(state.brightness), level: state.brightness / 100 },
                { label: "Power profile", kind: "text", value: "balanced", opens: "powerProfile" },
                { label: "Night light", kind: "switch", value: "until 07:00", on: true },
                { label: "Do not disturb", kind: "switch", value: "off", on: false },
                { label: "Keep awake", kind: "switch", value: "off", on: false },
                { label: "Background apps", kind: "text", value: "4 running", opens: "tray" },
                { label: "Settings", kind: "text", value: "", opens: "settings" },
                { label: "Monitor", kind: "text", value: batteryPercent + " battery, 12% processor", does: "monitor", alert: batteryLow },
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

        powerProfile: {
            title: "Power profile",
            rows: [
                { label: "Power saver", kind: "switch", value: "longest battery", on: false },
                { label: "Balanced", kind: "switch", value: "", on: true },
                { label: "Performance", kind: "switch", value: "fans may run", on: false },
            ],
        },

        // The app tray: apps that keep running without a window. Each
        // opens its own menu.
        tray: {
            title: "Background apps",
            empty: "nothing is running in the background",
            rows: [
                { label: "Vesktop", kind: "text", value: "3 unread", opens: "trayMenu" },
                { label: "Tailscale", kind: "text", value: "connected", opens: "trayMenu" },
                { label: "Spotify", kind: "text", value: "playing Shelter", opens: "trayMenu" },
                { label: "Steam", kind: "text", value: "idle", opens: "trayMenu" },
            ],
        },

        trayMenu: {
            title: "Vesktop",
            rows: [
                { label: "Open", kind: "text", value: "", does: "back" },
                { label: "Mute", kind: "switch", value: "notifications", on: false },
                { label: "Check for updates", kind: "text", value: "", does: "back" },
                { label: "Quit", kind: "text", value: "", does: "back" },
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
                { label: "Keyboard", kind: "text", value: "us, caps lock is escape" },
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
            empty: "nothing matches",
            rows: wallpaperRows(),
        },

        keys: {
            title: "Key bindings",
            field: { hint: "filter bindings", filters: true, secret: false },
            empty: "nothing matches",
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
                { label: "Bluetooth", kind: "text", value: state.trouble ? "off" : "2 devices connected", opens: "bluetooth" },
                { label: "Exit node", kind: "switch", value: "nixpc", on: state.online },
                { label: "Tailnet", kind: "text", value: state.online ? "4 devices online" : "unreachable", alert: !state.online },
            ],
        },

        wifi: {
            title: "Wi-Fi",
            empty: "no networks in range",
            rows: state.online ? [
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
            ] : [],
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
            rows: state.trouble ? [
                { label: "Bluetooth", kind: "switch", value: "off", on: false },
                { label: "Turn Bluetooth on to see devices", kind: "line", note: "" },
            ] : [
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
            empty: "no notifications",
            rows: state.inboxEmpty ? [] : [
                { label: "Mara", kind: "text", value: "are you still coming tonight?", note: "2m" },
                { label: "nh", kind: "busy", value: "Rebuilding nixlaptop" },
                { label: "Vesktop", kind: "text", value: "3 new messages in #general", note: "14m" },
                { label: "Tailscale", kind: "text", value: "nixpc came online", note: "1h" },
                { label: "Battery", kind: "text", value: "12% left", note: "2h", alert: true },
                { label: "Firefox", kind: "text", value: "Download finished", note: "3h" },
                { label: "Do not disturb", kind: "switch", value: "off", on: false },
                { label: "Dismiss all", kind: "text", value: "", does: "dismissAll" },
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

// --- Dialogs ---

// Things that interrupt: each is a page shown on its own in the middle of
// the screen (Dialog.qml). `countsDown` means it acts by itself when its
// time runs out; its first row shows the time left as a level.
// `state` is { countdown, refused }: the time left from 1 to 0, and whether
// the last password was turned down.
function dialogs(state) {
    return {
        // An app asks for administrator rights.
        authenticate: {
            title: "Authenticate",
            field: { hint: state.refused ? "wrong password, try again" : "password", filters: false, secret: true },
            countsDown: false,
            alert: state.refused,
            rows: [
                { label: "Wants to run", kind: "text", value: "nixos-rebuild switch" },
                { label: "As", kind: "text", value: "root" },
                { label: "Asked by", kind: "text", value: "nh, in Ghostty" },
            ],
        },

        // The screen is about to lock because nothing has been touched.
        lockSoon: {
            title: "Still there?",
            countsDown: true,
            alert: false,
            rows: [
                { label: "Locking in", kind: "level", value: Math.ceil(state.countdown * 30) + " s", level: state.countdown },
                { label: "Press any key to stay", kind: "line", note: "" },
            ],
        },

        // The battery is nearly empty.
        batteryCritical: {
            title: "Battery at 5%",
            countsDown: true,
            alert: true,
            rows: [
                { label: "Suspending in", kind: "level", value: Math.ceil(state.countdown * 60) + " s", level: state.countdown, alert: true },
                { label: "Plug in, or press any key to keep going", kind: "line", note: "" },
            ],
        },
    };
}

// --- Desktop widgets ---

// Tiles that sit on the desktop, under the windows. Same shape as a
// monitor applet's tile: a title and four summary rows.
var desktopWidgets = [
    {
        title: "Now playing",
        summary: [
            { label: "Track", kind: "text", value: "Shelter" },
            { label: "Artist", kind: "text", value: "Porter Robinson & Madeon" },
            { label: "At", kind: "level", value: "1:32/3:38", level: 0.42 },
            { label: "Player", kind: "text", value: "Spotify" },
        ],
    },
    {
        title: "Today",
        summary: [
            { label: "Weather", kind: "text", value: "12°, light rain" },
            { label: "14:00", kind: "text", value: "dentist" },
            { label: "19:30", kind: "text", value: "dinner with Mara" },
            { label: "Sunset", kind: "text", value: "16:42" },
        ],
    },
];

// --- The monitor ---

// Packages a pretend rebuild works through, in order, again and again.
var derivations = [
    "linux-7.3",
    "firefox-140.0",
    "quickshell-0.3.2",
    "niri-25.11",
    "ghostty-1.3.0",
    "nerd-fonts-departure-mono",
    "vesktop-1.6.1",
    "stylix-theme",
    "home-manager-generation",
    "system-path",
    "etc",
    "nixos-system-nixlaptop-26.11",
];
var buildPhases = ["buildPhase", "unpackPhase", "fixupPhase"];
// How many packages a pretend rebuild builds, and how long it takes.
var buildTotal = 47;
var buildSeconds = 192;

// Seconds as minutes and seconds, e.g. 3m 12s.
function duration(seconds) {
    return Math.floor(seconds / 60) + "m " + (seconds % 60) + "s";
}

// The build applet: four summary rows for its tile, then the rows of its
// expanded view. `state.rebuilding` and `state.rebuildProgress` (0 to 1)
// say how far the pretend rebuild has got.
function buildApplet(state) {
    if (state.trouble && !state.rebuilding) {
        return {
            title: "Build",
            alert: true,
            summary: [
                { label: "Status", kind: "text", value: "failed", alert: true },
                { label: "At", kind: "text", value: "firefox-140.0", alert: true },
                { label: "Built", kind: "level", value: "31/" + buildTotal, level: 31 / buildTotal, alert: true },
                { label: "Took", kind: "text", value: "2m 6s" },
            ],
            rows: [
                { label: "Status", kind: "text", value: "failed, the system was not changed", alert: true },
                { label: "Failed at", kind: "text", value: "firefox-140.0, buildPhase", alert: true },
                { label: "Built", kind: "level", value: "31/" + buildTotal, level: 31 / buildTotal, alert: true },
                { label: "Took", kind: "text", value: "2m 6s" },
                { label: "error: builder for firefox-140.0 failed with exit code 1", kind: "line", note: "" },
                { label: "  > ld: final link failed: No space left on device", kind: "line", note: "" },
                { label: "  > collect2: error: ld returned 1 exit status", kind: "line", note: "" },
                { label: "For the full log: nix log firefox-140.0", kind: "line", note: "" },
                { label: "Generation", kind: "text", value: "412, unchanged" },
            ],
        };
    }
    if (!state.rebuilding) {
        return {
            title: "Build",
            summary: [
                { label: "Status", kind: "text", value: "idle" },
                { label: "Last", kind: "text", value: "today 14:02" },
                { label: "Took", kind: "text", value: duration(buildSeconds) },
                { label: "Gen", kind: "text", value: "412" },
            ],
            rows: [
                { label: "Status", kind: "text", value: "idle, nothing is building" },
                { label: "Last build", kind: "text", value: "nh os switch, today 14:02" },
                { label: "Took", kind: "text", value: duration(buildSeconds) },
                { label: "Result", kind: "text", value: buildTotal + " built, 0 failed" },
                { label: "Generation", kind: "text", value: "412, booted" },
                { label: "Closure", kind: "text", value: "18.8 GiB" },
                { label: "Store", kind: "level", value: "78%", level: 0.78 },
                { label: "Garbage", kind: "text", value: "11 old generations, 6.4 GiB to free" },
            ],
        };
    }

    var built = Math.round(state.rebuildProgress * buildTotal);
    var fetched = Math.min(1, state.rebuildProgress * 1.5);
    var elapsed = duration(Math.round(state.rebuildProgress * buildSeconds));
    var current = derivations[built % derivations.length];
    var rows = [
        { label: "Target", kind: "text", value: "nixlaptop, nh os switch" },
        { label: "Built", kind: "level", value: built + "/" + buildTotal, level: state.rebuildProgress },
        { label: "Fetched", kind: "level", value: Math.round(fetched * 1240) + "M/1.2G", level: fetched },
        { label: "Elapsed", kind: "text", value: elapsed },
    ];
    // The three packages being built now.
    for (var offset = 0; offset < 3; offset++) {
        var running = built + offset;
        if (running < buildTotal)
            rows.push({ label: derivations[running % derivations.length], kind: "busy", value: buildPhases[offset] });
    }
    rows.push({ label: "Queued", kind: "text", value: Math.max(0, buildTotal - built - 3) + " packages" });
    // The ones that finished most recently, newest first.
    for (var back = 1; back <= 6; back++) {
        var done = built - back;
        if (done >= 0)
            rows.push({ label: derivations[done % derivations.length], kind: "text", value: "built", note: (12 + (done * 7) % 50) + "s" });
    }

    return {
        title: "Build",
        summary: [
            { label: "Built", kind: "level", value: built + "/" + buildTotal, level: state.rebuildProgress },
            { label: "Now", kind: "busy", value: current },
            { label: "Queue", kind: "text", value: Math.max(0, buildTotal - built - 3) + " packages" },
            { label: "Time", kind: "text", value: elapsed },
        ],
        rows: rows,
    };
}

// The monitor's applets, in the order they sit in its grid. Each has a
// title, four summary rows for its tile, and the rows of its expanded view.
// The rows are the same kinds a page uses.
function applets(state) {
    return [
        buildApplet(state),
        {
            title: "Processor",
            summary: [
                { label: "Load", kind: "graph", value: "12%", samples: history(32, 3) },
                { label: "Cores", kind: "text", value: "8 at 3.2 GHz" },
                { label: "Average", kind: "text", value: "0.84 0.92 1.10" },
                { label: "Heat", kind: "level", value: "54°", level: 0.54 },
            ],
            rows: [
                { label: "All cores", kind: "graph", value: "12%", samples: history(60, 3) },
                { label: "Core 1", kind: "level", value: "31%", level: 0.31 },
                { label: "Core 2", kind: "level", value: "8%", level: 0.08 },
                { label: "Core 3", kind: "level", value: "22%", level: 0.22 },
                { label: "Core 4", kind: "level", value: "4%", level: 0.04 },
                { label: "Core 5", kind: "level", value: "12%", level: 0.12 },
                { label: "Core 6", kind: "level", value: "6%", level: 0.06 },
                { label: "Core 7", kind: "level", value: "9%", level: 0.09 },
                { label: "Core 8", kind: "level", value: "3%", level: 0.03 },
                { label: "Load average", kind: "text", value: "0.84  0.92  1.10" },
                { label: "Frequency", kind: "text", value: "3.2 GHz, powersave governor" },
                { label: "Temperature", kind: "level", value: "54°", level: 0.54 },
            ],
        },
        {
            title: "Memory",
            summary: [
                { label: "Used", kind: "level", value: "6.2/16G", level: 0.39 },
                { label: "Cache", kind: "level", value: "4.1G", level: 0.26 },
                { label: "Swap", kind: "level", value: "0.3/8G", level: 0.04 },
                { label: "Top", kind: "text", value: "firefox, 1.8G" },
            ],
            rows: [
                { label: "Used", kind: "level", value: "6.2/16G", level: 0.39 },
                { label: "Cache", kind: "level", value: "4.1G", level: 0.26 },
                { label: "Free", kind: "level", value: "5.7G", level: 0.35 },
                { label: "Swap", kind: "level", value: "0.3/8G", level: 0.04 },
                { label: "History", kind: "graph", value: "39%", samples: history(60, 9) },
                { label: "firefox", kind: "level", value: "1.8G", level: 0.11 },
                { label: "cursor", kind: "level", value: "1.4G", level: 0.09 },
                { label: "vesktop", kind: "level", value: "0.7G", level: 0.04 },
                { label: "quickshell", kind: "level", value: "0.2G", level: 0.01 },
            ],
        },
        {
            title: "Network",
            summary: [
                { label: "Down", kind: "graph", value: state.online ? "1.2M/s" : "0", samples: state.online ? history(32, 5) : [] },
                { label: "Up", kind: "graph", value: state.online ? "84K/s" : "0", samples: state.online ? history(32, 2) : [] },
                { label: "Wi-Fi", kind: "signal", value: state.online ? "Home-5G" : "offline", level: state.online ? 0.75 : 0, alert: !state.online },
                { label: "Tailnet", kind: "text", value: state.online ? "4 online" : "unreachable", alert: !state.online },
            ],
            rows: [
                { label: "Download", kind: "graph", value: state.online ? "1.2M/s" : "0", samples: state.online ? history(60, 5) : [] },
                { label: "Upload", kind: "graph", value: state.online ? "84K/s" : "0", samples: state.online ? history(60, 2) : [] },
                { label: "Wi-Fi", kind: "signal", value: state.online ? "Home-5G, 5 GHz, 433 Mbit/s" : "not connected", level: state.online ? 0.75 : 0, alert: !state.online },
                { label: "Address", kind: "text", value: state.online ? "192.168.1.24" : "none" },
                { label: "Exit node", kind: "switch", value: "nixpc", on: state.online },
                { label: "nixpc", kind: "text", value: "online, direct", note: "4 ms" },
                { label: "phone", kind: "text", value: "online, relayed", note: "38 ms" },
                { label: "tablet", kind: "text", value: "offline", note: "2d" },
                { label: "Today", kind: "text", value: "3.4 GiB down, 410 MiB up" },
            ],
        },
        {
            title: "Storage",
            summary: [
                { label: "/", kind: "level", value: "61%", level: 0.61 },
                { label: "/nix", kind: "level", value: "78%", level: 0.78 },
                { label: "/home", kind: "level", value: "44%", level: 0.44 },
                { label: "Busy", kind: "graph", value: "2M/s", samples: history(32, 4) },
            ],
            rows: [
                { label: "/", kind: "level", value: "61% of 64G", level: 0.61 },
                { label: "/nix", kind: "level", value: "78% of 256G", level: 0.78 },
                { label: "/home", kind: "level", value: "44% of 512G", level: 0.44 },
                { label: "/boot", kind: "level", value: "23% of 1G", level: 0.23 },
                { label: "Reading", kind: "graph", value: "2M/s", samples: history(60, 4) },
                { label: "Writing", kind: "graph", value: "0.4M/s", samples: history(60, 7) },
                { label: "Drive", kind: "text", value: "NVMe, 96% health, 38°" },
                { label: "Nix store", kind: "text", value: "11 old generations, 6.4 GiB to free" },
            ],
        },
        {
            title: "Processes",
            summary: [
                { label: "firefox", kind: "text", value: "12.4%", note: "1.8G" },
                { label: "cursor", kind: "text", value: "6.1%", note: "1.4G" },
                { label: "niri", kind: "text", value: "2.3%", note: "0.2G" },
                { label: "nix", kind: "text", value: "1.9%", note: "0.3G" },
            ],
            rows: [
                { label: "firefox", kind: "level", value: "12.4%  1.8G", level: 0.124 },
                { label: "cursor", kind: "level", value: "6.1%  1.4G", level: 0.061 },
                { label: "niri", kind: "level", value: "2.3%  0.2G", level: 0.023 },
                { label: "nix-daemon", kind: "level", value: "1.9%  0.3G", level: 0.019 },
                { label: "vesktop", kind: "level", value: "1.2%  0.7G", level: 0.012 },
                { label: "quickshell", kind: "level", value: "0.6%  0.2G", level: 0.006 },
                { label: "pipewire", kind: "level", value: "0.4%  0.1G", level: 0.004 },
                { label: "ghostty", kind: "level", value: "0.3%  0.1G", level: 0.003 },
                { label: "tailscaled", kind: "level", value: "0.2%  0.1G", level: 0.002 },
                { label: "systemd", kind: "level", value: "0.1%  0.1G", level: 0.001 },
                { label: "spotify", kind: "level", value: "0.1%  0.4G", level: 0.001 },
                { label: "Running", kind: "text", value: "214 processes, 1 482 threads" },
            ],
        },
        {
            title: "Power",
            summary: [
                { label: "Charge", kind: "level", value: Math.round(state.battery * 100) + "%", level: state.battery, alert: state.battery <= 0.2 && !state.charging },
                { label: "Draw", kind: "graph", value: state.charging ? "+38W" : "9.4W", samples: history(32, 6) },
                { label: "Left", kind: "text", value: state.charging ? "full in 50 min" : state.battery <= 0.2 ? "25 min" : "2 h 10 min", alert: state.battery <= 0.2 && !state.charging },
                { label: "Profile", kind: "text", value: "balanced" },
            ],
            rows: [
                { label: "Charge", kind: "level", value: Math.round(state.battery * 100) + "%", level: state.battery, alert: state.battery <= 0.2 && !state.charging },
                { label: "Draw", kind: "graph", value: state.charging ? "+38W" : "9.4W", samples: history(60, 6) },
                { label: "Time", kind: "text", value: state.charging ? "full in 50 min" : state.battery <= 0.2 ? "25 min left" : "2 h 10 min left" },
                { label: "Charger", kind: "text", value: state.charging ? "plugged in, 45 W" : "not plugged in" },
                { label: "Profile", kind: "text", value: "balanced" },
                { label: "Health", kind: "text", value: "91% of design capacity, 312 cycles" },
                { label: "Screen", kind: "level", value: "3.1W", level: 0.33 },
                { label: "Processor", kind: "level", value: "2.8W", level: 0.3 },
                { label: "Wi-Fi", kind: "level", value: "0.9W", level: 0.1 },
            ],
        },
        {
            title: "Services",
            alert: state.trouble,
            summary: [
                { label: "Failed", kind: "text", value: state.trouble ? "1 unit: cups" : "0 units", alert: state.trouble },
                { label: "Running", kind: "text", value: "61 system, 14 user" },
                { label: "Timers", kind: "text", value: "next in 12 min" },
                { label: "Journal", kind: "text", value: "2 warnings today" },
            ],
            rows: [
                { label: "Failed", kind: "text", value: state.trouble ? "1 unit" : "0 units", alert: state.trouble },
                { label: "cups", kind: "switch", value: state.trouble ? "failed, exit code 1" : "stopped", on: false, alert: state.trouble },
                { label: "System", kind: "text", value: "61 running" },
                { label: "User", kind: "text", value: "14 running" },
                { label: "tailscaled", kind: "switch", value: "running", on: true, note: "3d" },
                { label: "sshd", kind: "switch", value: "running", on: true, note: "3d" },
                { label: "pipewire", kind: "switch", value: "running", on: true, note: "5h" },
                { label: "bluetooth", kind: "switch", value: "stopped", on: false },
                { label: "nix-gc.timer", kind: "text", value: "runs in 12 min" },
                { label: "fstrim.timer", kind: "text", value: "runs in 4 d" },
                { label: "Journal", kind: "text", value: "2 warnings, 0 errors today" },
            ],
        },
        {
            title: "System",
            summary: [
                { label: "Host", kind: "text", value: "nixlaptop" },
                { label: "Up", kind: "text", value: "3 d 4 h" },
                { label: "NixOS", kind: "text", value: "26.11, gen 412" },
                { label: "Inputs", kind: "text", value: "nixpkgs 3 d old" },
            ],
            rows: [
                { label: "Host", kind: "text", value: "nixlaptop, ThinkPad T14" },
                { label: "Up", kind: "text", value: "3 d 4 h" },
                { label: "NixOS", kind: "text", value: "26.11 unstable" },
                { label: "Kernel", kind: "text", value: "Linux 7.3" },
                { label: "Generation", kind: "text", value: "412, booted and current" },
                { label: "nixpkgs", kind: "text", value: "locked 3 days ago" },
                { label: "home-manager", kind: "text", value: "locked 3 days ago" },
                { label: "quickshell", kind: "text", value: "locked 12 days ago" },
                { label: "Session", kind: "text", value: "niri on Wayland" },
                { label: "Shell", kind: "text", value: "this mockup" },
            ],
        },
    ];
}
