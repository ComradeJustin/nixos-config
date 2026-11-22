import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland

// The desktop shell. Entry point.
//
// It is drawn like a terminal UI, in the pixel font Departure Mono on a
// fixed grid of character cells. The design was worked out in
// configs/shell-mockups, which shows every screen with sample data; this
// is the real one, built a piece at a time. So far it is the bar,
// notifications, the volume, brightness and microphone keys, the lock
// screen, and the ring with its pages.
//   Bar            a status line along the top edge of every screen
//   Toasts         notifications, stacked under the bar's left end
//   Readout        a panel that drops out of the bar when the volume,
//                  brightness or microphone mute changes
//   Lock           the lock screen (pam/password is its password rule)
//   Ring           the summoned layer: station names on a braille orbit
//                  around a clock; the focused one opens into pages
//   Pages          the stations and what every page holds, from the system
//   Panel          draws one page: a line of text input and a scrolling
//                  list of rows
//   Monitor        the other summoned layer: a grid of applets (processor,
//                  memory, disks, ...) that each expand to a full view
//   MonitorData    reads the system for it while it is open
//                  (system-readings.sh)
//   Calendar       a month that drops out of the bar's clock
//   Desktop        a clock and the playing track on an empty desktop
//   Niri           workspaces and the focused window, from niri
//   Theme          colours, the character grid, motion
//   Box, Label, Level, SignalBars, Value, Passing, Flag, Segment, Dim,
//   Graph, Spinner, Tile, DitherFade, DitherImage
//                  what those are built from
//
// This file gathers what they show from the system and holds what they
// can do. Everything arrives as it changes; nothing polls. The shell is
// also the desktop's notification service: apps send theirs here.
//   time           QuickShell's clock
//   windows        niri's event stream (Niri.qml) and the window list
//   sound          PipeWire
//   battery        UPower
//   network        NetworkManager
//   playing track  MPRIS
//   input method   fcitx5, through its tray item
//   notifications  what apps send, kept until dismissed
//   brightness     brightnessctl, asked only when a key changes it
//
// Keys reach it through IPC, from niri's key bindings (configs/niri):
//   qs -p ~/nixos-config/configs/shell ipc call shell <name>
//   where <name> is one of: volumeUp, volumeDown, volumeMute,
//   microphoneMute, brightnessUp, brightnessDown, quiet, dismissAll,
//   lock, lockPractice (a lock that also lets go by itself after a minute),
//   lockWake (ask the fingerprint reader again, after a suspend),
//   ring (open or close the ring), page <name> (open the ring at a page:
//   launch, clipboard, system, network, media, inbox, session, ...),
//   monitor (open or close the monitor), calendar,
//   and, for driving the ring without the keyboard: turn <steps>, open,
//   select <steps>, adjust <step>, back, type <text>
// In the ring: h l turn, enter opens or acts, j k or the arrows select,
// left and right move a level, esc backs out. In a page with a text
// field, letters type, up and down select, and left, right, home, end,
// backspace, delete and ctrl+u edit the text. The mouse works too.
// The lock is also reached through swayidle (configs/niri/startup.kdl),
// which calls it when the session is asked to lock: after sitting idle,
// before a suspend, and by "loginctl lock-session".
//
// One-time setup (the font is not installed system-wide yet):
//   nix build nixpkgs#nerd-fonts.departure-mono -o ~/nixos-config/configs/shell/departure-mono-font
// Start:  systemd-run --user --unit=shell --collect -p Restart=on-failure quickshell -p ~/nixos-config/configs/shell
// Stop:   systemctl --user stop shell
// After changing a file, stop and start it again. It does not reload by
// itself, and it is started so that it comes back if it ever crashes:
// the lock screen lives in here, and a locked session whose lock screen
// has gone shows nothing to unlock it with. (Lock.qml puts the lock
// screen back whenever the shell starts on a locked session.)
ShellRoot {
    id: root

    // Reloading while the session is locked destroys the lock screen in a
    // way the compositor refuses, which takes the whole shell down.
    settings.watchFiles: false

    // --- Time ---
    readonly property var now: clock.date

    // --- Windows ---
    readonly property alias niri: niriState
    // Whether the focused window is fullscreen. niri covers the bar then,
    // so the bar dithers away.
    readonly property bool fullscreen: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen : false

    // --- The ring ---
    property bool ringOpen: false
    // How many steps the ring has been turned. Never wraps (see Ring.qml).
    property int turns: 0
    readonly property var stations: pageSource.stations
    readonly property int focusedIndex: ((turns % stations.length) + stations.length) % stations.length

    // The pages open inside the focused station, innermost last. Empty
    // while the ring shows its names.
    property var pageStack: []
    // The selected row of each of those pages.
    property var selectionStack: []
    // What has been typed into the innermost page's text field, and where
    // the text cursor is in it, counted in characters from the start.
    property string query: ""
    property int cursor: 0
    // A change of page waits here while the page on screen is wiped away.
    // Ring.qml calls commitStack() once it has gone.
    property bool stackPending: false
    property var nextPageStack: []
    property var nextSelectionStack: []

    readonly property bool dived: pageStack.length > 0
    readonly property string pageName: dived ? pageStack[pageStack.length - 1] : ""
    readonly property var page: dived ? pageSource.named(pageName) : null
    readonly property int selectedIndex: dived && selectionStack.length > 0 ? selectionStack[selectionStack.length - 1] : 0
    // The innermost page's rows, narrowed by what has been typed.
    readonly property var pageRows: page ? matchingRows(page, query) : []
    // Whether there is a text field to type into right now.
    readonly property bool fieldOpen: page !== null && page.field !== undefined && !stackPending

    // Only one of the ring and the monitor is open at a time.
    function toggleRing(): void {
        if (root.ringOpen) {
            root.closeRing();
        } else {
            root.closeMonitor();
            root.ringOpen = true;
        }
    }

    function closeRing(): void {
        root.ringOpen = false;
        if (root.dived)
            root.changeStack([], []);
    }

    function rotate(step: int): void {
        if (!root.dived)
            root.turns += step;
    }

    // Turn the ring the short way round until this station is focused.
    function focusStation(station: int): void {
        const count = root.stations.length;
        // The difference from the focused one, from -count/2 to count/2.
        const ahead = ((station - root.focusedIndex) % count + count) % count;
        root.turns += ahead > count / 2 ? ahead - count : ahead;
    }

    // Open the ring straight at one page, as a key binding does. The ring
    // turns to the station the page belongs to. Asking for the page that
    // is already open closes the ring, so one key opens and closes it.
    function openPage(name: string): void {
        if (pageSource.named(name) === null)
            return;
        if (root.ringOpen && root.pageName === name) {
            root.closeRing();
            return;
        }
        root.closeMonitor();
        root.ringOpen = true;
        root.focusStation(pageSource.pageStation[name]);
        root.changeStack([name], [0]);
    }

    // The rows of a page that contain what has been typed. A page without a
    // filtering text field always shows all of its rows.
    function matchingRows(page: var, typed: string): var {
        if (!page.field || !page.field.filters || typed === "")
            return page.rows;
        const wanted = typed.toLowerCase();
        const matches = [];
        for (const row of page.rows) {
            const text = (row.label + " " + (row.value || "")).toLowerCase();
            if (text.includes(wanted))
                matches.push(row);
        }
        return matches;
    }

    // Ask for a different set of open pages. It takes effect once the page
    // on screen has been wiped away.
    function changeStack(pageNames: var, selections: var): void {
        root.nextPageStack = pageNames;
        root.nextSelectionStack = selections;
        root.stackPending = true;
    }

    function commitStack(): void {
        root.pageStack = root.nextPageStack;
        root.selectionStack = root.nextSelectionStack;
        root.query = "";
        root.cursor = 0;
        root.stackPending = false;
        root.selectReadable();
    }

    // Enter: open the focused station, or act on the selected row. A row
    // does its own thing first, then opens its page if it has one.
    function act(): void {
        if (root.stackPending)
            return;
        if (!root.dived) {
            root.changeStack([root.stations[root.focusedIndex].page], [0]);
            return;
        }
        if (root.pageRows.length === 0)
            return;
        const row = root.pageRows[root.selectedIndex];
        if (row.act)
            row.act();
        if (row.toggle)
            row.toggle();
        if (row.opens)
            root.changeStack(root.pageStack.concat([row.opens]), root.selectionStack.concat([0]));
        if (row.closes)
            root.closeRing();
    }

    // Left and right on a level move it one step.
    function adjust(step: int): void {
        if (!root.dived || root.stackPending || root.pageRows.length === 0)
            return;
        const row = root.pageRows[root.selectedIndex];
        if (row.adjust)
            row.adjust(step);
    }

    // Esc: leave the innermost page, then close the ring.
    function back(): void {
        if (root.stackPending)
            return;
        if (root.dived)
            root.changeStack(root.pageStack.slice(0, -1), root.selectionStack.slice(0, -1));
        else
            root.ringOpen = false;
    }

    function select(index: int): void {
        root.selectionStack = root.selectionStack.slice(0, -1).concat([index]);
    }

    // Move the selection one row up or down, passing over notes, which are
    // only there to be read. It stays put when there is no row that way.
    function moveSelection(step: int): void {
        if (!root.dived || root.stackPending)
            return;
        let index = root.selectedIndex + step;
        while (index >= 0 && index < root.pageRows.length) {
            if (root.pageRows[index].kind !== "note") {
                root.select(index);
                return;
            }
            index += step;
        }
    }

    // If the selection is on a note, move it to the first row that is not.
    function selectReadable(): void {
        if (!root.dived || root.pageRows.length === 0 || root.pageRows[root.selectedIndex].kind !== "note")
            return;
        for (let index = 0; index < root.pageRows.length; index++) {
            if (root.pageRows[index].kind !== "note") {
                root.select(index);
                return;
            }
        }
    }

    // Typing puts the text in at the cursor. The first match is selected.
    function typeText(text: string): void {
        if (!root.fieldOpen)
            return;
        root.query = root.query.slice(0, root.cursor) + text + root.query.slice(root.cursor);
        root.cursor += text.length;
        root.select(0);
    }

    // Backspace: take out the character before the cursor.
    function eraseText(): void {
        if (!root.fieldOpen || root.cursor === 0)
            return;
        root.query = root.query.slice(0, root.cursor - 1) + root.query.slice(root.cursor);
        root.cursor -= 1;
        root.select(0);
    }

    // Delete: take out the character under the cursor.
    function deleteText(): void {
        if (!root.fieldOpen || root.cursor >= root.query.length)
            return;
        root.query = root.query.slice(0, root.cursor) + root.query.slice(root.cursor + 1);
        root.select(0);
    }

    function clearText(): void {
        if (!root.fieldOpen)
            return;
        root.query = "";
        root.cursor = 0;
        root.select(0);
    }

    // Move the cursor to this position, kept inside the text.
    function placeCursor(position: int): void {
        if (!root.fieldOpen)
            return;
        root.cursor = Math.max(0, Math.min(root.query.length, position));
    }

    function lock(): void {
        lockScreen.engage(false);
    }

    // --- The monitor ---
    property bool monitorOpen: false
    // Which applet is focused, and whether it is expanded.
    property int monitorIndex: 0
    property bool monitorExpanded: false
    // The selected row of the expanded applet.
    property int monitorSelected: 0
    // How many applets sit side by side in the grid.
    readonly property int monitorColumns: 3
    readonly property var applets: monitorData.applets

    function toggleMonitor(): void {
        if (root.monitorOpen) {
            root.closeMonitor();
            return;
        }
        if (root.ringOpen)
            root.closeRing();
        root.monitorOpen = true;
    }

    function closeMonitor(): void {
        root.monitorOpen = false;
        root.monitorExpanded = false;
    }

    // Move the focus by this many applets, if there is one there.
    function moveApplet(step: int): void {
        const target = root.monitorIndex + step;
        if (root.monitorExpanded || target < 0 || target >= root.applets.length)
            return;
        root.monitorIndex = target;
    }

    function expandApplet(): void {
        root.monitorSelected = 0;
        root.monitorExpanded = true;
    }

    // Esc: collapse the expanded applet, then close the monitor.
    function monitorBack(): void {
        if (root.monitorExpanded)
            root.monitorExpanded = false;
        else
            root.monitorOpen = false;
    }

    function monitorScroll(step: int): void {
        if (!root.monitorExpanded)
            return;
        const last = root.applets[root.monitorIndex].rows.length - 1;
        root.monitorSelected = Math.max(0, Math.min(last, root.monitorSelected + step));
    }

    // --- The calendar ---
    property bool calendarShown: false
    // Which month it shows, counted in months from this one.
    property int calendarOffset: 0

    function toggleCalendar(): void {
        root.calendarOffset = 0;
        root.calendarShown = !root.calendarShown;
    }

    // --- The desktop widgets ---
    // Whether the focused workspace has no windows, from niri.
    readonly property bool workspaceEmpty: niriState.focusedWorkspaceEmpty

    // --- Sound ---
    // The speakers or headphones sound goes to. It has no volume to read
    // until PipeWire has bound it, which the tracker below asks for.
    readonly property var soundOutput: Pipewire.defaultAudioSink
    readonly property bool soundReady: soundOutput !== null && soundOutput.audio !== null
    // From 0 to 100.
    readonly property int volume: soundReady ? Math.round(soundOutput.audio.volume * 100) : 0
    readonly property bool muted: soundReady && soundOutput.audio.muted

    // One step up or down. Turning the volume also takes mute off.
    function changeVolume(step: int): void {
        if (!root.soundReady)
            return;
        root.soundOutput.audio.muted = false;
        root.soundOutput.audio.volume = Math.max(0, Math.min(1, root.soundOutput.audio.volume + 0.05 * step));
    }

    function toggleMute(): void {
        if (root.soundReady)
            root.soundOutput.audio.muted = !root.soundOutput.audio.muted;
    }

    // The microphone sound comes from.
    readonly property var soundInput: Pipewire.defaultAudioSource
    readonly property bool microphoneReady: soundInput !== null && soundInput.audio !== null
    readonly property int microphoneVolume: microphoneReady ? Math.round(soundInput.audio.volume * 100) : 0
    readonly property bool microphoneMuted: microphoneReady && soundInput.audio.muted

    function toggleMicrophoneMute(): void {
        if (root.microphoneReady)
            root.soundInput.audio.muted = !root.soundInput.audio.muted;
    }

    // --- Screen brightness ---
    // From 0 to 100, as it was when the shell started or after the last
    // change made from here. A change made some other way is not seen.
    property int brightness: 0
    // Whether the change being made should show the readout: a key does,
    // the level in the System page does not.
    property bool brightnessReadout: false

    // One step up or down. brightnessctl prints the state as one line of
    // comma-separated fields; the fourth is the percentage.
    function changeBrightness(step: int, showReadout: bool): void {
        if (brightnessCommand.running)
            return;
        root.brightnessReadout = showReadout;
        brightnessCommand.command = ["brightnessctl", "--machine-readable", "set", step > 0 ? "5%+" : "5%-"];
        brightnessCommand.running = true;
    }

    Process {
        id: brightnessCommand

        // The first run only reads the brightness.
        command: ["brightnessctl", "--machine-readable"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(",");
                if (fields.length < 4)
                    return;
                root.brightness = parseInt(fields[3]);
                if (root.brightnessReadout)
                    root.showReadout("brightness");
            }
        }
    }

    // --- The readout ---
    // Which of the three it is showing: "volume", "brightness" or
    // "microphone", and whether it is up.
    property string readoutKind: "volume"
    property bool readoutShown: false

    function showReadout(kind: string): void {
        root.readoutKind = kind;
        root.readoutShown = true;
        readoutHide.restart();
    }

    Timer {
        id: readoutHide

        interval: 1600
        onTriggered: root.readoutShown = false
    }

    // --- Notifications ---
    // Every notification that has not been dismissed. The bell counts these.
    readonly property var waitingNotifications: notificationServer.trackedNotifications.values
    readonly property int unreadCount: waitingNotifications.length
    // Do not disturb: notifications are kept and counted but not shown,
    // except urgent ones.
    property bool quiet: false
    // The notifications on screen now: for each its id, its place in the
    // stack, and its words as they were when it arrived.
    readonly property alias toastList: toastModel
    // How long a notification shows when it does not say, in milliseconds.
    readonly property int toastLifetime: 4500

    // The waiting notification with this id, or null.
    function notificationWithId(id: int): var {
        for (const notification of root.waitingNotifications) {
            if (notification.id === id)
                return notification;
        }
        return null;
    }

    // A notification's text as one line of plain text: apps may send
    // several lines and simple markup such as <b>.
    function plainText(text: string): string {
        // Take out anything between angle brackets.
        let plain = text.replace(/<[^>]*>/g, "");
        // Put back the three characters markup has to write differently.
        plain = plain.replace(/&lt;/g, "<");
        plain = plain.replace(/&gt;/g, ">");
        plain = plain.replace(/&amp;/g, "&");
        // Line breaks and runs of spaces become one space.
        plain = plain.replace(/\s+/g, " ");
        return plain.trim();
    }

    function toastIndex(id: int): int {
        for (let index = 0; index < toastModel.count; index++) {
            if (toastModel.get(index).notificationId === id)
                return index;
        }
        return -1;
    }

    // Whether a notification on screen is in this place of the stack.
    function toastPlaceTaken(place: int): bool {
        for (let index = 0; index < toastModel.count; index++) {
            if (toastModel.get(index).place === place)
                return true;
        }
        return false;
    }

    // The highest free place above this one in the stack, or -1.
    function freePlaceAbove(place: int): int {
        for (let candidate = 0; candidate < place; candidate++) {
            if (!root.toastPlaceTaken(candidate))
                return candidate;
        }
        return -1;
    }

    // Put a notification on screen. It takes the highest free place in
    // the stack and keeps it until it leaves.
    function showToast(notification: var): void {
        if (root.toastIndex(notification.id) >= 0)
            return;
        let place = 0;
        while (root.toastPlaceTaken(place))
            place += 1;
        const actionNames = [];
        for (const action of notification.actions)
            actionNames.push(action.text);
        toastModel.append({
            notificationId: notification.id,
            place: place,
            app: notification.appName,
            summary: root.plainText(notification.summary),
            body: root.plainText(notification.body),
            actions: actionNames.join(" · "),
            urgent: notification.urgency === NotificationUrgency.Critical,
            // The notification's own time, in milliseconds; none given is 0 or less.
            lifetime: notification.expireTimeout > 0 ? notification.expireTimeout : root.toastLifetime
        });
    }

    // Take a notification off the screen. One that ran out of time stays
    // waiting, unless its app marked it as not worth keeping.
    function removeToast(id: int, ranOutOfTime: bool): void {
        const index = root.toastIndex(id);
        if (index >= 0)
            toastModel.remove(index);
        const notification = root.notificationWithId(id);
        if (ranOutOfTime && notification !== null && notification.transient)
            notification.expire();
    }

    // Give a notification on screen a different place in the stack.
    function moveToast(id: int, place: int): void {
        const index = root.toastIndex(id);
        if (index >= 0)
            toastModel.setProperty(index, "place", place);
    }

    function dismissNotification(id: int): void {
        const notification = root.notificationWithId(id);
        if (notification !== null)
            notification.dismiss();
    }

    // A click on a notification: do its first action, the one an app means
    // by default, which also closes it. One with no action is dismissed.
    function actOnNotification(id: int): void {
        const notification = root.notificationWithId(id);
        if (notification === null)
            return;
        if (notification.actions.length > 0)
            notification.actions[0].invoke();
        else
            notification.dismiss();
    }

    // Show every waiting notification again.
    function showWaiting(): void {
        for (const notification of root.waitingNotifications)
            root.showToast(notification);
    }

    function dismissAll(): void {
        // A copy of the list, because dismissing takes them out of it.
        for (const notification of root.waitingNotifications.slice())
            notification.dismiss();
    }

    ListModel {
        id: toastModel
    }

    NotificationServer {
        id: notificationServer

        bodySupported: true
        actionsSupported: true
        // Keep what is waiting when a file is saved and the shell reloads.
        keepOnReload: true

        onNotification: notification => {
            // Tracked means kept: it stays in the list until dismissed.
            notification.tracked = true;
            if (!root.quiet || notification.urgency === NotificationUrgency.Critical)
                root.showToast(notification);
        }
    }

    // --- Battery ---
    // UPower's summary of all batteries. A machine without one has none present.
    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool batteryPresent: batteryDevice.ready && batteryDevice.isPresent
    // From 0 to 1.
    readonly property real battery: batteryDevice.percentage
    readonly property bool charging: batteryDevice.state === UPowerDeviceState.Charging

    // The battery is warned about as it runs down past each of these
    // levels, lowest last, with an urgent notification that stays until it
    // is dismissed.
    readonly property var batteryWarnings: [0.2, 0.1, 0.05]
    // The lowest of those already warned about since the charger was last
    // plugged in; 1 when none has been.
    property real batteryWarnedAt: 1

    function checkBattery(): void {
        if (!root.batteryPresent)
            return;
        // On the charger again: start over.
        if (root.charging || root.batteryDevice.state === UPowerDeviceState.FullyCharged) {
            root.batteryWarnedAt = 1;
            return;
        }
        // The lowest level the battery has run down past and not been warned about.
        let passed = 1;
        for (const level of root.batteryWarnings) {
            if (root.battery <= level && level < root.batteryWarnedAt)
                passed = level;
        }
        if (passed === 1)
            return;
        root.batteryWarnedAt = passed;
        const minutes = Math.round(root.batteryDevice.timeToEmpty / 60);
        const timeLeft = minutes > 0 ? "about " + minutes + " minutes left, " : "";
        Quickshell.execDetached(["notify-send", "--urgency=critical", "--app-name=Battery", Math.round(root.battery * 100) + "% left", timeLeft + "plug in soon"]);
    }

    onBatteryChanged: root.checkBattery()
    onChargingChanged: root.checkBattery()
    onBatteryPresentChanged: root.checkBattery()

    // --- Network ---
    // The Wi-Fi network in use, or null.
    readonly property var wifiNetwork: {
        for (const device of Networking.devices.values) {
            if (device.type !== DeviceType.Wifi)
                continue;
            for (const network of device.networks.values) {
                if (network.connected)
                    return network;
            }
        }
        return null;
    }
    readonly property bool wired: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wired && device.connected)
                return true;
        }
        return false;
    }
    readonly property bool online: wifiNetwork !== null || wired
    readonly property string networkName: wifiNetwork !== null ? wifiNetwork.name : (wired ? "wired" : "offline")
    // Wi-Fi signal strength from 0 to 1. A cable counts as full.
    readonly property real networkSignal: wifiNetwork !== null ? wifiNetwork.signalStrength : (wired ? 1 : 0)

    // --- Playing track ---
    // The first media player that is playing, or null.
    readonly property var playingPlayer: {
        for (const player of Mpris.players.values) {
            if (player.isPlaying)
                return player;
        }
        return null;
    }
    readonly property string trackTitle: playingPlayer !== null ? playingPlayer.trackTitle : ""
    // The player to show and control: the one playing, or else the first one.
    readonly property var mediaPlayer: {
        if (root.playingPlayer !== null)
            return root.playingPlayer;
        const players = Mpris.players.values;
        return players.length > 0 ? players[0] : null;
    }

    function pausePlaying(): void {
        if (root.playingPlayer !== null && root.playingPlayer.canPause)
            root.playingPlayer.pause();
    }

    // --- Input method ---
    // fcitx5 has no way to tell a program when the input method changes,
    // but it keeps a tray item whose tooltip names the one in use, and a
    // tray item's changes do arrive as they happen. The tooltip reads
    // "Keyboard - English (US)" for plain typing and names the input
    // method, such as Mozc for Japanese, otherwise.
    readonly property var inputTrayItem: {
        for (const item of SystemTray.items.values) {
            if (item.id === "Fcitx")
                return item;
        }
        return null;
    }
    // False when fcitx5 is not running: there is nothing to show then.
    readonly property bool inputAvailable: inputTrayItem !== null
    readonly property bool inputJapanese: inputAvailable && !inputTrayItem.tooltipTitle.startsWith("Keyboard")

    function toggleInput(): void {
        Quickshell.execDetached(["fcitx5-remote", "-t"]);
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Niri {
        id: niriState
    }

    // Keeps the sound output and the microphone bound, so their volume
    // and mute can be read and set.
    PwObjectTracker {
        objects: [root.soundOutput, root.soundInput]
    }

    // One bar on every screen.
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            shell: root
            screen: modelData
        }
    }

    Toasts {
        shell: root
    }

    Readout {
        shell: root
    }

    Lock {
        id: lockScreen

        shell: root
    }

    Pages {
        id: pageSource

        shell: root
    }

    Ring {
        shell: root
    }

    MonitorData {
        id: monitorData

        shell: root
    }

    Monitor {
        shell: root
    }

    Calendar {
        shell: root
    }

    Desktop {
        shell: root
    }

    // What niri's key bindings call.
    IpcHandler {
        target: "shell"

        function volumeUp(): void {
            root.changeVolume(1);
            root.showReadout("volume");
        }

        function volumeDown(): void {
            root.changeVolume(-1);
            root.showReadout("volume");
        }

        function volumeMute(): void {
            root.toggleMute();
            root.showReadout("volume");
        }

        function microphoneMute(): void {
            root.toggleMicrophoneMute();
            root.showReadout("microphone");
        }

        function brightnessUp(): void {
            root.changeBrightness(1, true);
        }

        function brightnessDown(): void {
            root.changeBrightness(-1, true);
        }

        function quiet(): void {
            root.quiet = !root.quiet;
        }

        function dismissAll(): void {
            root.dismissAll();
        }

        function lock(): void {
            root.lock();
        }

        function lockPractice(): void {
            lockScreen.engage(true);
        }

        function lockWake(): void {
            lockScreen.wake();
        }

        function ring(): void {
            root.toggleRing();
        }

        function monitor(): void {
            root.toggleMonitor();
        }

        function calendar(): void {
            root.toggleCalendar();
        }

        function page(name: string): void {
            root.openPage(name);
        }

        function turn(steps: int): void {
            root.rotate(steps);
        }

        function open(): void {
            root.act();
        }

        function select(steps: int): void {
            root.moveSelection(steps);
        }

        function adjust(step: int): void {
            root.adjust(step);
        }

        function back(): void {
            root.back();
        }

        function type(text: string): void {
            root.typeText(text);
        }
    }
}
