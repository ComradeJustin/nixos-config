import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

// The ring's stations and every page that can open, in the ring or in a
// panel dropped out of the bar, made from what the system reports.
// Panel.qml draws a page; shell.qml moves between pages and acts on rows.
//
// A page exists only where there is a list worth opening. Anything smaller
// happens on the row it belongs to: the apps playing sound sit under the
// volume, and ending the session is confirmed on its own row.
//
// A page is { title, field, rows, empty, valueColumn, columns }.
//   valueColumn  optional: the cell values start at, for a page whose
//           labels are longer than usual
//   columns optional: how wide the panel is, for a page with long lines
//   field   optional line of text input at the top of the page:
//           { hint, filters, secret }. `filters` narrows the rows to those
//           that contain the typed text; `secret` shows dots instead of it.
//           A page that is only a text field gives it `submit`, a function
//           that enter hands the text to, and `submitHint`, the word for
//           that in the footer.
//   empty   what to say when the page has no rows to show
//   rows    the lines of the page. Each is { label, kind, ... }:
//     kind "text"    label, then `value`
//     kind "line"    `label` across the whole width (no value)
//     kind "note"    the same, but only to be read: it cannot be selected
//     kind "level"   a bar (`level` 0 to 1), then `value` at the right edge
//     kind "switch"  on or off (`on`); `note` says what it does
//     kind "signal"  signal bars (`level` 0 to 1), then `value`
//   Any row may also have:
//     note    dim text at the right edge
//     keywords  more words that a search for this row should match
//     alert   true when something is wrong; the value is in the alert colour
//     image   a picture to preview beside the page while the row is selected
//     opens   the name of the page that enter opens (shown as "›")
//     act     what enter does: a function
//     toggle  for a switch: what enter does
//     adjust  for a level: what left and right do, given -1 or 1
//     closes  true when the ring should close after enter
Scope {
    id: pages

    // The shell root (shell.qml).
    required property var shell

    // The names on the ring, clockwise, and the page each one opens.
    readonly property var stations: [
        {
            name: "Launch",
            page: "launch"
        },
        {
            name: "Clipboard",
            page: "clipboard"
        },
        {
            name: "System",
            page: "system"
        },
        {
            name: "Network",
            page: "network"
        },
        {
            name: "Media",
            page: "media"
        },
        {
            name: "Inbox",
            page: "inbox"
        },
        {
            name: "Session",
            page: "session"
        }
    ]

    // Which station each page belongs to, counted from 0 in the order
    // above. Opening a page directly, as a key binding does, turns the
    // ring there. Every page has an entry here.
    readonly property var pageStation: ({
            launch: 0,
            clipboard: 1,
            system: 2,
            sound: 2,
            power: 2,
            keys: 2,
            tray: 2,
            trayMenu: 2,
            wallpaper: 2,
            network: 3,
            wifiPassword: 3,
            bluetooth: 3,
            media: 4,
            inbox: 5,
            notification: 5,
            session: 6
        })

    // The page with this name, or null when there is none.
    function named(name: string): var {
        if (pages.pageStation[name] === undefined)
            return null;
        return pages[name];
    }

    // What was last picked on the way into a page that is about one thing.
    property int openNotificationId: 0
    property var wifiTarget: null
    property var trayTarget: null

    // --- Launch: open windows, then apps, then the shell's own settings ---
    readonly property var launch: launchPage()

    function launchPage(): var {
        const rows = [];
        // Open windows come first: enter switches to one.
        for (const window of pages.shell.niri.windows) {
            rows.push({
                label: window.app,
                kind: "text",
                value: window.title,
                note: "window",
                act: () => pages.shell.niri.focusWindow(window.id),
                closes: true
            });
        }
        // Then apps, by name: enter starts one.
        const apps = [];
        for (const entry of DesktopEntries.applications.values) {
            if (!entry.noDisplay)
                apps.push(entry);
        }
        apps.sort((first, second) => first.name.localeCompare(second.name));
        for (const entry of apps) {
            rows.push({
                label: entry.name,
                kind: "text",
                value: entry.genericName !== "" ? entry.genericName : entry.comment,
                act: () => entry.execute(),
                closes: true
            });
        }
        // Last, the shell itself, to be found by typing: each station, and
        // every row of the pages that hold settings. Enter opens the page
        // at that row.
        for (const station of pages.stations) {
            if (station.page === "launch")
                continue;
            rows.push({
                label: station.name,
                kind: "text",
                value: "open",
                note: "shell",
                act: () => pages.shell.openPage(station.page)
            });
        }
        for (const name of ["system", "media", "session"]) {
            const page = pages[name];
            for (let index = 0; index < page.rows.length; index++) {
                const row = page.rows[index];
                if (row.kind === "note")
                    continue;
                rows.push({
                    label: row.label,
                    kind: "text",
                    value: page.title,
                    note: "shell",
                    act: () => pages.shell.openPageAt(name, index)
                });
            }
        }
        return {
            title: "Launch",
            field: {
                hint: "search windows, settings and apps",
                filters: true,
                secret: false
            },
            empty: "nothing matches",
            rows: rows
        };
    }

    // --- Clipboard: what cliphist has kept, newest first ---
    // Read when the page opens. Each entry is { id, preview }.
    property var clipboardEntries: []
    readonly property var clipboard: clipboardPage()

    function clipboardPage(): var {
        const rows = [];
        for (const entry of pages.clipboardEntries) {
            rows.push({
                label: entry.preview,
                kind: "line",
                // Put it back on the clipboard.
                act: () => Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", entry.id]),
                closes: true
            });
        }
        return {
            title: "Clipboard",
            field: {
                hint: "filter clipboard",
                filters: true,
                secret: false
            },
            empty: "nothing matches",
            rows: rows
        };
    }

    // cliphist prints one entry per line: its id, a tab, a preview.
    Process {
        id: clipboardList

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const entries = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab > 0)
                        entries.push({
                            id: line.slice(0, tab),
                            preview: line.slice(tab + 1)
                        });
                }
                pages.clipboardEntries = entries;
            }
        }
    }

    // --- Sound: the volume, each app that is playing, mute, the microphone ---
    // The apps playing are whatever is connected to the speakers: each
    // connection's source is one app's stream.
    PwNodeLinkTracker {
        id: speakerLinks

        node: pages.shell.soundOutput
    }

    readonly property var playingStreams: {
        const streams = [];
        for (const link of speakerLinks.linkGroups)
            streams.push(link.source);
        return streams;
    }

    // Keeps those streams bound, so their volume can be read and set.
    PwObjectTracker {
        objects: pages.playingStreams
    }

    // These rows are the top of the System page, and all of the panel that
    // drops out of the bar's volume.
    function soundRows(): var {
        const rows = [
            {
                label: "Volume",
                kind: "level",
                value: pages.shell.muted ? "mute" : String(pages.shell.volume),
                level: pages.shell.muted ? 0 : pages.shell.volume / 100,
                alert: pages.shell.muted,
                adjust: step => pages.shell.changeVolume(step)
            }
        ];
        // Each app that is playing, hung under the volume it is a part of.
        // A stream has no volume to read until it has been bound.
        const streams = [];
        for (const stream of pages.playingStreams) {
            if (stream.audio !== null)
                streams.push(stream);
        }
        for (let index = 0; index < streams.length; index++) {
            const stream = streams[index];
            const appName = stream.properties["application.name"];
            const branch = index === streams.length - 1 ? "└ " : "├ ";
            rows.push({
                label: branch + (appName !== undefined ? appName : stream.name),
                kind: "level",
                value: String(Math.round(stream.audio.volume * 100)),
                level: stream.audio.volume,
                adjust: step => stream.audio.volume = Math.max(0, Math.min(1, stream.audio.volume + 0.05 * step))
            });
        }
        rows.push({
            label: "Mute",
            kind: "switch",
            on: pages.shell.muted,
            toggle: () => pages.shell.toggleMute()
        });
        rows.push({
            label: "Microphone",
            kind: "switch",
            on: !pages.shell.microphoneMuted,
            toggle: () => pages.shell.toggleMicrophoneMute()
        });
        return rows;
    }

    readonly property var sound: ({
            title: "Sound",
            rows: pages.soundRows()
        })

    // --- Rows that sit on more than one page ---
    function brightnessRow(): var {
        return {
            label: "Brightness",
            kind: "level",
            value: String(pages.shell.brightness),
            level: pages.shell.brightness / 100,
            adjust: step => pages.shell.changeBrightness(step, false)
        };
    }

    function keepAwakeRow(): var {
        return {
            label: "Keep awake",
            kind: "switch",
            note: "no dimming or idle lock",
            on: pages.shell.keepAwake,
            toggle: () => pages.shell.keepAwake = !pages.shell.keepAwake
        };
    }

    function quietRow(): var {
        return {
            label: "Do not disturb",
            kind: "switch",
            note: "holds notifications",
            on: pages.shell.quiet,
            toggle: () => pages.shell.quiet = !pages.shell.quiet
        };
    }

    function monitorRow(): var {
        return {
            label: "Monitor",
            kind: "text",
            value: "processor, memory, disks and more",
            act: () => pages.shell.toggleMonitor()
        };
    }

    // --- System: controls ---
    readonly property var system: ({
            title: "System",
            rows: pages.soundRows().concat([pages.brightnessRow(),
                {
                    label: "Night light",
                    kind: "switch",
                    note: "warm from 19:00 to 07:00",
                    on: pages.shell.nightLight,
                    toggle: () => pages.shell.nightLight = !pages.shell.nightLight
                },
                pages.keepAwakeRow(), pages.quietRow(),
                {
                    label: "Japanese input",
                    kind: "switch",
                    note: pages.shell.inputAvailable ? "alt+space" : "fcitx5 is not running",
                    on: pages.shell.inputJapanese,
                    toggle: () => pages.shell.toggleInput()
                },
                {
                    label: "Tray",
                    kind: "text",
                    value: pages.shell.trayCount + " running",
                    opens: "tray"
                },
                {
                    label: "Wallpaper",
                    kind: "text",
                    value: "",
                    opens: "wallpaper"
                },
                {
                    label: "Key bindings",
                    kind: "text",
                    value: "",
                    opens: "keys"
                },
                pages.monitorRow()])
        })

    // --- Power: the battery in full, and what bears on it ---
    // The panel that drops out of the bar's battery.
    readonly property var power: ({
            title: "Power",
            rows: pages.shell.powerRows.concat([pages.brightnessRow(), pages.keepAwakeRow(), pages.monitorRow()])
        })

    // --- Tray ---
    // What a tray app is called. One that gives no title is known by its
    // id, which often ends in "_status_icon_1".
    function trayName(item: var): string {
        let name = item.title !== "" ? item.title : item.id.replace(/_status_icon.*$/, "");
        name = name.replace(/[_-]/g, " ");
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    // The app tray: apps that keep running without a window. Enter opens an
    // app's menu, or, for an app without one, does what a click on its tray
    // icon would.
    readonly property var tray: trayPage()

    function trayPage(): var {
        const rows = [];
        for (const item of SystemTray.items.values) {
            const name = pages.trayName(item);
            const row = {
                label: name,
                kind: "text",
                // What the app says about itself, unless that is its name.
                value: item.tooltipTitle !== name ? item.tooltipTitle : ""
            };
            if (item.hasMenu) {
                row.act = () => pages.trayTarget = item;
                row.opens = "trayMenu";
            } else {
                row.act = () => item.activate();
                row.closes = true;
            }
            rows.push(row);
        }
        return {
            title: "Tray",
            empty: "nothing is running in the background",
            rows: rows
        };
    }

    // One app's tray menu, as the app gives it. Lines that divide the menu
    // are left out, and so are entries that would open a further menu.
    readonly property var trayMenu: trayMenuPage()

    function trayMenuPage(): var {
        const item = pages.trayTarget;
        if (item === null) {
            return {
                title: "Menu",
                empty: "the app has gone",
                rows: []
            };
        }
        const rows = [
            {
                label: "Open",
                kind: "text",
                value: "",
                act: () => item.activate(),
                closes: true
            }
        ];
        for (const entry of trayMenuOpener.children.values) {
            if (entry.isSeparator || entry.hasChildren || entry.text === "")
                continue;
            if (!entry.enabled) {
                rows.push({
                    label: entry.text,
                    kind: "note"
                });
                continue;
            }
            rows.push({
                label: entry.text,
                kind: "line",
                act: () => entry.triggered(),
                closes: true
            });
        }
        return {
            title: pages.trayName(item),
            rows: rows
        };
    }

    QsMenuOpener {
        id: trayMenuOpener

        menu: pages.trayTarget !== null ? pages.trayTarget.menu : null
    }

    // --- Key bindings: read out of niri's own list of them ---
    // Each is { keys, does, group }, read when the page opens.
    property var keyBindings: []
    // The groups, in the order the page lists them.
    readonly property var bindingGroups: ["Shell", "Apps", "Windows", "Workspaces", "Screens", "Screenshots", "Other"]
    readonly property var keys: keysPage()

    function keysPage(): var {
        const rows = [];
        for (const group of pages.bindingGroups) {
            const inGroup = [];
            for (const binding of pages.keyBindings) {
                if (binding.group === group)
                    inGroup.push(binding);
            }
            if (inGroup.length === 0)
                continue;
            rows.push({
                label: "── " + group + " ──",
                kind: "note"
            });
            for (const binding of inGroup) {
                rows.push({
                    label: binding.keys,
                    kind: "text",
                    value: binding.does,
                    keywords: group
                });
            }
        }
        return {
            title: "Key bindings",
            field: {
                hint: "filter bindings",
                filters: true,
                secret: false
            },
            empty: "nothing matches",
            // Both the keys and what they do are long.
            columns: 72,
            valueColumn: 26,
            rows: rows
        };
    }

    // How niri spells a key, and how it is shown. "Mod" is the Super key.
    readonly property var keyNames: ({
            Mod: "Super",
            Return: "Enter",
            Slash: "/",
            Comma: ",",
            Period: ".",
            Minus: "-",
            Equal: "=",
            BracketLeft: "[",
            BracketRight: "]",
            Left: "←",
            Right: "→",
            Up: "↑",
            Down: "↓",
            Page_Up: "PgUp",
            Page_Down: "PgDn",
            Print: "PrtSc",
            WheelScrollUp: "Wheel↑",
            WheelScrollDown: "Wheel↓",
            WheelScrollLeft: "Wheel←",
            WheelScrollRight: "Wheel→",
            XF86AudioRaiseVolume: "Volume up key",
            XF86AudioLowerVolume: "Volume down key",
            XF86AudioMute: "Mute key",
            XF86AudioMicMute: "Microphone mute key",
            XF86MonBrightnessUp: "Brightness up key",
            XF86MonBrightnessDown: "Brightness down key",
            XF86Display: "Display key"
        })

    // What this shell is asked for by a binding, in words.
    readonly property var shellCallNames: ({
            "ring": "Open the ring",
            "monitor": "System monitor",
            "tray": "Tray",
            "lock": "Lock the screen",
            "page clipboard": "Clipboard history",
            "page system": "System settings",
            "page wallpaper": "Wallpaper",
            "page session": "Session",
            "volumeUp": "Volume up",
            "volumeDown": "Volume down",
            "volumeMute": "Mute",
            "microphoneMute": "Mute the microphone",
            "brightnessUp": "Brightness up",
            "brightnessDown": "Brightness down"
        })

    // Keys as niri writes them, such as Mod+Shift+Slash, as they are shown.
    function bindingKeys(keys: string): string {
        const shown = [];
        for (const key of keys.split("+"))
            shown.push(pages.keyNames[key] !== undefined ? pages.keyNames[key] : key);
        return shown.join("+");
    }

    // What a command asks this shell for, such as "page clipboard". "" when
    // the binding is not a call to this shell. niri's file gives a command
    // with each word in quotes.
    function shellCall(action: string): string {
        const words = pages.commandWords(action);
        const target = words.indexOf("shell");
        if (!words.includes("ipc") || target < 0)
            return "";
        return words.slice(target + 1).join(" ");
    }

    function commandWords(action: string): var {
        const words = [];
        for (const quoted of action.match(/"[^"]*"/g) || [])
            words.push(quoted.slice(1, -1));
        return words;
    }

    // What a binding does, in words.
    function bindingAction(action: string): string {
        if (!action.startsWith("spawn")) {
            // One of niri's own actions, such as focus-column-left or
            // set-column-width "-10%". The hyphens between words become
            // spaces; the one in front of a number stays.
            const words = action.replace(/-(?=[a-z])/g, " ").replace(/"/g, "");
            return words.charAt(0).toUpperCase() + words.slice(1);
        }
        const call = pages.shellCall(action);
        if (call !== "")
            return pages.shellCallNames[call] !== undefined ? pages.shellCallNames[call] : call;
        return "Run " + pages.commandWords(action).join(" ");
    }

    // Which group a binding is listed under.
    function bindingGroup(action: string): string {
        if (action.startsWith("spawn"))
            return pages.shellCall(action) !== "" ? "Shell" : "Apps";
        if (action.includes("screenshot"))
            return "Screenshots";
        if (action.includes("monitor"))
            return "Screens";
        if (action.includes("workspace"))
            return "Workspaces";
        if (action.includes("window") || action.includes("column"))
            return "Windows";
        return "Other";
    }

    // A binding is one line: the keys, then options, then the action in
    // braces. A line may carry its own description as
    // hotkey-overlay-title="...". Comment lines start with "//".
    function readBindings(text: string): void {
        const bindings = [];
        for (const rawLine of text.split("\n")) {
            const line = rawLine.trim();
            if (line.startsWith("//"))
                continue;
            // Keys, anything, then { action }.
            const parts = line.match(/^([A-Za-z0-9_+]+)\s+(.*?)\{\s*(.*?)\s*;?\s*\}$/);
            if (parts === null)
                continue;
            const title = parts[2].match(/hotkey-overlay-title="([^"]*)"/);
            bindings.push({
                keys: pages.bindingKeys(parts[1]),
                does: title !== null ? title[1] : pages.bindingAction(parts[3]),
                group: pages.bindingGroup(parts[3])
            });
        }
        pages.keyBindings = bindings;
    }

    Process {
        id: keyBindingList

        command: ["cat", Quickshell.env("HOME") + "/.config/niri/keybind.kdl"]
        stdout: StdioCollector {
            onStreamFinished: pages.readBindings(text)
        }
    }

    // --- Wallpaper: the pictures in the repository's wallpaper folder ---
    readonly property string wallpaperFolder: Quickshell.shellDir + "/../../assets/wallpapers"
    // The file names, read when the page opens.
    property var wallpaperFiles: []
    readonly property var wallpaper: wallpaperPage()

    function wallpaperPage(): var {
        const rows = [];
        for (const file of pages.wallpaperFiles) {
            const path = pages.wallpaperFolder + "/" + file;
            rows.push({
                label: file,
                kind: "line",
                image: path,
                act: () => Quickshell.execDetached(["awww", "img", path])
            });
        }
        return {
            title: "Wallpaper",
            field: {
                hint: "filter wallpapers",
                filters: true,
                secret: false
            },
            empty: "nothing matches",
            rows: rows
        };
    }

    Process {
        id: wallpaperList

        command: ["ls", pages.wallpaperFolder]
        stdout: StdioCollector {
            onStreamFinished: {
                const files = [];
                for (const line of text.split("\n")) {
                    if (line !== "")
                        files.push(line);
                }
                pages.wallpaperFiles = files;
            }
        }
    }

    // --- Network ---
    readonly property var wifiDevice: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wifi)
                return device;
        }
        return null;
    }
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter

    function bluetoothSummary(): string {
        if (pages.bluetoothAdapter === null)
            return "no adapter";
        if (!pages.bluetoothAdapter.enabled)
            return "off";
        let connected = 0;
        for (const device of pages.bluetoothAdapter.devices.values) {
            if (device.connected)
                connected += 1;
        }
        return connected + " connected";
    }

    // Bluetooth, then the Wi-Fi networks in range: the one in use first,
    // then the saved ones, then the rest, each group strongest first. Enter
    // joins one: a network that is saved or open straight away, any other
    // after its password.
    readonly property var network: networkPage()

    // Where a network goes in the list: lower comes first.
    function wifiRank(network: var): int {
        if (network.connected)
            return 0;
        return network.known ? 1 : 2;
    }

    function networkPage(): var {
        const rows = [
            {
                label: "Bluetooth",
                kind: "text",
                value: pages.bluetoothSummary(),
                opens: "bluetooth"
            }
        ];
        if (pages.wifiDevice !== null) {
            const networks = pages.wifiDevice.networks.values.slice();
            networks.sort((first, second) => {
                const rankDifference = pages.wifiRank(first) - pages.wifiRank(second);
                if (rankDifference !== 0)
                    return rankDifference;
                return second.signalStrength - first.signalStrength;
            });
            for (const network of networks) {
                const open = network.security === WifiSecurityType.Open;
                let state = open ? "open" : "secured";
                if (network.connected)
                    state = "connected";
                else if (network.known)
                    state = "saved";
                const row = {
                    label: network.name,
                    kind: "signal",
                    value: state,
                    level: network.signalStrength
                };
                if (network.connected) {
                    row.act = () => network.disconnect();
                } else if (network.known || open) {
                    row.act = () => network.connect();
                } else {
                    row.act = () => pages.wifiTarget = network;
                    row.opens = "wifiPassword";
                }
                rows.push(row);
            }
        }
        if (rows.length === 1) {
            rows.push({
                label: "no Wi-Fi networks in range",
                kind: "note"
            });
        }
        return {
            title: "Network",
            // Network names can be up to 32 characters long.
            valueColumn: 30,
            rows: rows
        };
    }

    // The Wi-Fi card looks for networks only while the Network page is open.
    Binding {
        target: pages.wifiDevice
        property: "scannerEnabled"
        value: pages.shell.pageName === "network"
        when: pages.wifiDevice !== null
    }

    // The password of a network that has not been joined before. The page
    // is only its text field: enter joins, esc goes back.
    readonly property var wifiPassword: ({
            title: pages.wifiTarget !== null ? "Join " + pages.wifiTarget.name : "Join",
            field: {
                hint: "password",
                filters: false,
                secret: true,
                submitHint: "join",
                submit: text => {
                    if (pages.wifiTarget !== null)
                        pages.wifiTarget.connectWithPsk(text);
                    pages.shell.back();
                }
            },
            rows: []
        })

    // Bluetooth: the adapter, then its devices. Enter connects a paired
    // device, disconnects a connected one, and pairs a new one.
    readonly property var bluetooth: bluetoothPage()

    function bluetoothPage(): var {
        const adapter = pages.bluetoothAdapter;
        if (adapter === null) {
            return {
                title: "Bluetooth",
                empty: "this machine has no Bluetooth adapter",
                rows: []
            };
        }
        const rows = [
            {
                label: "Bluetooth",
                kind: "switch",
                on: adapter.enabled,
                toggle: () => adapter.enabled = !adapter.enabled
            }
        ];
        if (!adapter.enabled) {
            rows.push({
                label: "Turn Bluetooth on to see devices",
                kind: "note"
            });
            return {
                title: "Bluetooth",
                rows: rows
            };
        }
        for (const device of adapter.devices.values) {
            let state = "found, not paired";
            if (device.connected)
                state = "connected";
            else if (device.paired)
                state = "paired";
            const row = {
                label: device.name,
                kind: "text",
                value: state,
                note: device.batteryAvailable ? Math.round(device.battery * 100) + "%" : ""
            };
            if (device.connected)
                row.act = () => device.disconnect();
            else if (device.paired)
                row.act = () => device.connect();
            else
                row.act = () => device.pair();
            rows.push(row);
        }
        rows.push({
            label: "Find devices",
            kind: "switch",
            note: adapter.discovering ? "looking" : "",
            on: adapter.discovering,
            toggle: () => adapter.discovering = !adapter.discovering
        });
        return {
            title: "Bluetooth",
            rows: rows
        };
    }

    // --- Media: the player that is playing, or else the first one ---
    readonly property var mediaPlayer: pages.shell.mediaPlayer
    readonly property var media: mediaPage()

    function mediaPage(): var {
        const player = pages.mediaPlayer;
        if (player === null) {
            return {
                title: "Media",
                empty: "nothing is playing",
                rows: []
            };
        }
        return {
            title: "Media",
            rows: [
                {
                    label: "Track",
                    kind: "text",
                    value: player.trackTitle
                },
                {
                    label: "Artist",
                    kind: "text",
                    value: player.trackArtist
                },
                {
                    label: "Player",
                    kind: "text",
                    value: player.identity
                },
                {
                    label: player.isPlaying ? "Pause" : "Play",
                    kind: "text",
                    value: "",
                    act: () => player.togglePlaying()
                },
                {
                    label: "Next track",
                    kind: "text",
                    value: "",
                    act: () => player.next()
                },
                {
                    label: "Previous track",
                    kind: "text",
                    value: "",
                    act: () => player.previous()
                }
            ]
        };
    }

    // --- Inbox: the notifications that have not been dismissed ---
    readonly property var inbox: inboxPage()

    function inboxPage(): var {
        const rows = [];
        for (const notification of pages.shell.waitingNotifications) {
            rows.push({
                label: notification.appName,
                kind: "text",
                value: pages.shell.plainText(notification.summary),
                act: () => pages.openNotificationId = notification.id,
                opens: "notification"
            });
        }
        if (rows.length === 0) {
            return {
                title: "Inbox",
                empty: "no notifications",
                rows: rows
            };
        }
        rows.push(pages.quietRow());
        rows.push({
            label: "Dismiss all",
            kind: "text",
            value: "",
            act: () => pages.shell.dismissAll()
        });
        return {
            title: "Inbox",
            rows: rows
        };
    }

    // One notification, opened from the inbox: all of it, then what can be
    // done with it.
    readonly property var notification: notificationPage()

    function notificationPage(): var {
        const notification = pages.shell.notificationWithId(pages.openNotificationId);
        if (notification === null) {
            return {
                title: "Notification",
                empty: "it has gone",
                rows: []
            };
        }
        const rows = [
            {
                label: pages.shell.plainText(notification.summary),
                kind: "note"
            },
            {
                label: pages.shell.plainText(notification.body),
                kind: "note"
            }
        ];
        for (const action of notification.actions) {
            rows.push({
                label: action.text,
                kind: "text",
                value: "",
                // Doing an action also closes the notification, unless
                // its app asked for it to stay.
                act: () => {
                    action.invoke();
                    pages.shell.back();
                }
            });
        }
        rows.push({
            label: "Dismiss",
            kind: "text",
            value: "",
            act: () => {
                notification.dismiss();
                pages.shell.back();
            }
        });
        return {
            title: notification.appName,
            rows: rows
        };
    }

    // --- Session ---
    // Anything that ends the session asks first, on its own row: the first
    // enter arms the row, a second one does it, and moving away from the
    // row disarms it. This is the label of the armed row, or "".
    property string armedRow: ""

    function endingRow(label: string, command: var): var {
        const armed = pages.armedRow === label;
        return {
            label: label,
            kind: "text",
            value: armed ? "enter again to confirm" : "",
            alert: armed,
            act: () => {
                if (armed) {
                    pages.armedRow = "";
                    Quickshell.execDetached(command);
                } else {
                    pages.armedRow = label;
                }
            }
        };
    }

    readonly property var session: ({
            title: "Session",
            rows: [
                {
                    label: "Lock",
                    kind: "text",
                    value: "",
                    act: () => pages.shell.lock(),
                    closes: true
                },
                {
                    label: "Suspend",
                    kind: "text",
                    value: "",
                    act: () => Quickshell.execDetached(["systemctl", "suspend"]),
                    closes: true
                },
                pages.endingRow("Log out", ["niri", "msg", "action", "quit", "--skip-confirmation"]), pages.endingRow("Restart", ["systemctl", "reboot"]), pages.endingRow("Power off", ["systemctl", "poweroff"])]
        })

    // Pages whose rows are read from a command are read when they open.
    Connections {
        target: pages.shell

        function onSelectedIndexChanged(): void {
            pages.armedRow = "";
        }

        function onPageNameChanged(): void {
            pages.armedRow = "";
            if (pages.shell.pageName === "clipboard")
                clipboardList.running = true;
            else if (pages.shell.pageName === "wallpaper")
                wallpaperList.running = true;
            else if (pages.shell.pageName === "keys")
                keyBindingList.running = true;
        }
    }
}
