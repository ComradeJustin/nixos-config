import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

// The ring's stations and every page that can open inside it, made from
// what the system reports. Panel.qml draws a page; shell.qml moves between
// pages and acts on rows.
//
// A page is { title, field, rows, empty, valueColumn }.
//   valueColumn  optional: the cell values start at, for a page whose
//           labels are longer than usual
//   field   optional line of text input at the top of the page:
//           { hint, filters, secret }. `filters` narrows the rows to those
//           that contain the typed text; `secret` shows dots instead of it.
//   empty   what to say when the page has no rows to show
//   rows    the lines of the page. Each is { label, kind, ... }:
//     kind "text"    label, then `value`
//     kind "line"    `label` across the whole width (no value)
//     kind "note"    the same, but only to be read: it cannot be selected
//     kind "level"   a bar (`level` 0 to 1), then `value` at the right edge
//     kind "switch"  on or off (`on`), then `value`
//     kind "signal"  signal bars (`level` 0 to 1), then `value`
//   Any row may also have:
//     note    dim text at the right edge
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
            mixer: 2,
            keys: 2,
            tray: 2,
            trayMenu: 2,
            wallpaper: 2,
            network: 3,
            wifi: 3,
            wifiPassword: 3,
            bluetooth: 3,
            media: 4,
            inbox: 5,
            notification: 5,
            session: 6,
            confirmLogOut: 6,
            confirmRestart: 6,
            confirmPowerOff: 6
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

    // --- Launch: open windows, then apps ---
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
        // Then everything in the shell's own pages: enter opens the page
        // at that row.
        for (const name of ["system", "network", "media", "session"]) {
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

    // --- System: controls ---
    readonly property var system: ({
            title: "System",
            rows: [
                {
                    label: "Volume",
                    kind: "level",
                    value: pages.shell.muted ? "mute" : String(pages.shell.volume),
                    level: pages.shell.muted ? 0 : pages.shell.volume / 100,
                    alert: pages.shell.muted,
                    adjust: step => pages.shell.changeVolume(step)
                },
                {
                    label: "Mute",
                    kind: "switch",
                    value: "sound",
                    on: pages.shell.muted,
                    toggle: () => pages.shell.toggleMute()
                },
                {
                    label: "Microphone",
                    kind: "switch",
                    value: pages.shell.microphoneMuted ? "muted" : "on",
                    on: !pages.shell.microphoneMuted,
                    toggle: () => pages.shell.toggleMicrophoneMute()
                },
                {
                    label: "Mixer",
                    kind: "text",
                    value: pages.playingStreams.length + " playing",
                    opens: "mixer"
                },
                {
                    label: "Brightness",
                    kind: "level",
                    value: String(pages.shell.brightness),
                    level: pages.shell.brightness / 100,
                    adjust: step => pages.shell.changeBrightness(step, false)
                },
                {
                    label: "Night light",
                    kind: "switch",
                    value: "warm from 19:00 to 07:00",
                    on: pages.shell.nightLight,
                    toggle: () => pages.shell.nightLight = !pages.shell.nightLight
                },
                {
                    label: "Keep awake",
                    kind: "switch",
                    value: pages.shell.keepAwake ? "no dimming, no idle lock" : "off",
                    on: pages.shell.keepAwake,
                    toggle: () => pages.shell.keepAwake = !pages.shell.keepAwake
                },
                {
                    label: "Do not disturb",
                    kind: "switch",
                    value: pages.shell.quiet ? "notifications are held" : "off",
                    on: pages.shell.quiet,
                    toggle: () => pages.shell.quiet = !pages.shell.quiet
                },
                {
                    label: "Japanese input",
                    kind: "switch",
                    value: pages.shell.inputAvailable ? "alt+space" : "fcitx5 is not running",
                    on: pages.shell.inputJapanese,
                    toggle: () => pages.shell.toggleInput()
                },
                {
                    label: "Background apps",
                    kind: "text",
                    value: SystemTray.items.values.length + " running",
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
                {
                    label: "Monitor",
                    kind: "text",
                    value: "processor, memory, disks and more",
                    act: () => pages.shell.toggleMonitor()
                }
            ]
        })

    // --- Mixer: the volume of each app that is playing sound ---
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

    readonly property var mixer: mixerPage()

    function mixerPage(): var {
        const rows = [];
        for (const stream of pages.playingStreams) {
            // A stream has no volume to read until it has been bound.
            if (stream.audio === null)
                continue;
            const appName = stream.properties["application.name"];
            rows.push({
                label: appName !== undefined ? appName : stream.name,
                kind: "level",
                value: String(Math.round(stream.audio.volume * 100)),
                level: stream.audio.volume,
                adjust: step => stream.audio.volume = Math.max(0, Math.min(1, stream.audio.volume + 0.05 * step))
            });
        }
        return {
            title: "Mixer",
            empty: "no app is playing sound",
            rows: rows
        };
    }

    // The app tray: apps that keep running without a window. Enter opens an
    // app's menu, or, for an app without one, does what a click on its tray
    // icon would.
    readonly property var tray: trayPage()

    function trayPage(): var {
        const rows = [];
        for (const item of SystemTray.items.values) {
            const row = {
                label: item.title !== "" ? item.title : item.id,
                kind: "text",
                value: item.tooltipTitle
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
            title: "Background apps",
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
            title: item.title !== "" ? item.title : item.id,
            rows: rows
        };
    }

    QsMenuOpener {
        id: trayMenuOpener

        menu: pages.trayTarget !== null ? pages.trayTarget.menu : null
    }

    // --- Key bindings: read out of niri's own list of them ---
    // Each is { keys, does }, read when the page opens.
    property var keyBindings: []
    readonly property var keys: keysPage()

    function keysPage(): var {
        const rows = [];
        for (const binding of pages.keyBindings) {
            rows.push({
                label: binding.keys,
                kind: "text",
                value: binding.does
            });
        }
        return {
            title: "Key bindings",
            field: {
                hint: "filter bindings",
                filters: true,
                secret: false
            },
            empty: "nothing matches",
            // Key names such as Mod+Shift+Ctrl+Right are long.
            valueColumn: 24,
            rows: rows
        };
    }

    // What a binding does, in words. niri's file gives an action such as
    // focus-column-left, or a command to run with each word in quotes.
    function bindingAction(action: string): string {
        if (!action.startsWith("spawn"))
            return action.replace(/-/g, " ");
        // The quoted words of the command.
        const words = [];
        for (const quoted of action.match(/"[^"]*"/g) || [])
            words.push(quoted.slice(1, -1));
        // A call to this shell: say only what it asks for.
        const shellCall = words.indexOf("shell");
        if (words.includes("ipc") && shellCall >= 0)
            return "shell: " + words.slice(shellCall + 1).join(" ");
        return "run " + words.join(" ");
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
                keys: parts[1],
                does: title !== null ? title[1] : pages.bindingAction(parts[3])
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

    readonly property var network: ({
            title: "Network",
            rows: [
                {
                    label: "Wi-Fi",
                    kind: "signal",
                    value: pages.shell.networkName,
                    level: pages.shell.networkSignal,
                    alert: !pages.shell.online,
                    opens: "wifi"
                },
                {
                    label: "Bluetooth",
                    kind: "text",
                    value: pages.bluetoothSummary(),
                    opens: "bluetooth"
                }
            ]
        })

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

    // The networks in range: the one in use first, then the saved ones,
    // then the rest, each group strongest first. Enter joins one: a network
    // that is saved or open straight away, any other after its password.
    readonly property var wifi: wifiPage()

    // Where a network goes in the list: lower comes first.
    function wifiRank(network: var): int {
        if (network.connected)
            return 0;
        return network.known ? 1 : 2;
    }

    function wifiPage(): var {
        const rows = [];
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
        return {
            title: "Wi-Fi",
            empty: "no networks in range",
            // Network names can be up to 32 characters long.
            valueColumn: 30,
            rows: rows
        };
    }

    // The Wi-Fi card looks for networks only while the Wi-Fi page is open.
    Binding {
        target: pages.wifiDevice
        property: "scannerEnabled"
        value: pages.shell.pageName === "wifi"
        when: pages.wifiDevice !== null
    }

    readonly property var wifiPassword: ({
            title: pages.wifiTarget !== null ? "Join " + pages.wifiTarget.name : "Join",
            field: {
                hint: "password",
                filters: false,
                secret: true
            },
            rows: [
                {
                    label: "Connect",
                    kind: "text",
                    value: "",
                    act: () => {
                        if (pages.wifiTarget !== null)
                            pages.wifiTarget.connectWithPsk(pages.shell.query);
                        pages.shell.back();
                    }
                },
                {
                    label: "Cancel",
                    kind: "text",
                    value: "",
                    act: () => pages.shell.back()
                }
            ]
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
                value: adapter.enabled ? "on" : "off",
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
            value: adapter.discovering ? "looking" : "off",
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
        rows.push({
            label: "Do not disturb",
            kind: "switch",
            value: pages.shell.quiet ? "notifications are held" : "off",
            on: pages.shell.quiet,
            toggle: () => pages.shell.quiet = !pages.shell.quiet
        });
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
                {
                    label: "Log out",
                    kind: "text",
                    value: "",
                    opens: "confirmLogOut"
                },
                {
                    label: "Restart",
                    kind: "text",
                    value: "",
                    opens: "confirmRestart"
                },
                {
                    label: "Power off",
                    kind: "text",
                    value: "",
                    opens: "confirmPowerOff"
                }
            ]
        })

    // Anything that ends the session asks first, with "Cancel" selected.
    function confirmPage(question: string, answer: string, command: var): var {
        return {
            title: question,
            rows: [
                {
                    label: "Cancel",
                    kind: "text",
                    value: "",
                    act: () => pages.shell.back()
                },
                {
                    label: answer,
                    kind: "text",
                    value: "open windows will close",
                    alert: true,
                    act: () => Quickshell.execDetached(command)
                }
            ]
        };
    }

    readonly property var confirmLogOut: confirmPage("Log out?", "Log out now", ["niri", "msg", "action", "quit", "--skip-confirmation"])
    readonly property var confirmRestart: confirmPage("Restart?", "Restart now", ["systemctl", "reboot"])
    readonly property var confirmPowerOff: confirmPage("Power off?", "Power off now", ["systemctl", "poweroff"])

    // Pages whose rows are read from a command are read when they open.
    Connections {
        target: pages.shell

        function onPageNameChanged(): void {
            if (pages.shell.pageName === "clipboard")
                clipboardList.running = true;
            else if (pages.shell.pageName === "wallpaper")
                wallpaperList.running = true;
            else if (pages.shell.pageName === "keys")
                keyBindingList.running = true;
        }
    }
}
