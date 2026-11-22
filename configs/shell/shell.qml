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
// notifications, and the volume, brightness and microphone keys.
//   Bar            a status line along the top edge of every screen
//   Toasts         notifications, stacked under the bar's left end
//   Readout        a panel that drops out of the bar when the volume,
//                  brightness or microphone mute changes
//   Niri           workspaces and the focused window, from niri
//   Theme          colours, the character grid, motion
//   Box, Label, Level, SignalBars, Value, Passing, Flag, Segment,
//   DitherFade     what those are built from
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
//   microphoneMute, brightnessUp, brightnessDown, quiet, dismissAll
//
// One-time setup (the font is not installed system-wide yet):
//   nix build nixpkgs#nerd-fonts.departure-mono -o ~/nixos-config/configs/shell/departure-mono-font
// Start:  systemd-run --user --unit=shell --collect quickshell -p ~/nixos-config/configs/shell
// Stop:   systemctl --user stop shell
// Files reload on save.
ShellRoot {
    id: root

    // --- Time ---
    readonly property var now: clock.date

    // --- Windows ---
    readonly property alias niri: niriState
    // Whether the focused window is fullscreen. niri covers the bar then,
    // so the bar dithers away.
    readonly property bool fullscreen: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen : false

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
    // From 0 to 100, as it was after the last change made from here. It is
    // only shown in the readout, right after such a change.
    property int brightness: 0

    // One step up or down. brightnessctl prints the new state as one line
    // of comma-separated fields; the fourth is the percentage.
    function changeBrightness(step: int): void {
        if (brightnessChange.running)
            return;
        brightnessChange.command = ["brightnessctl", "--machine-readable", "set", step > 0 ? "5%+" : "5%-"];
        brightnessChange.running = true;
    }

    Process {
        id: brightnessChange

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(",");
                if (fields.length < 4)
                    return;
                root.brightness = parseInt(fields[3]);
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
    // by default, and dismiss it.
    function actOnNotification(id: int): void {
        const notification = root.notificationWithId(id);
        if (notification === null)
            return;
        if (notification.actions.length > 0)
            notification.actions[0].invoke();
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
            root.changeBrightness(1);
        }

        function brightnessDown(): void {
            root.changeBrightness(-1);
        }

        function quiet(): void {
            root.quiet = !root.quiet;
        }

        function dismissAll(): void {
            root.dismissAll();
        }
    }
}
