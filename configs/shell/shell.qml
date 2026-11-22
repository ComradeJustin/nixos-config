import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland

// The desktop shell. Entry point.
//
// It is drawn like a terminal UI, in the pixel font Departure Mono on a
// fixed grid of character cells. The design was worked out in
// configs/shell-mockups, which shows every screen with sample data; this
// is the real one, built a piece at a time. So far it is the bar.
//   Bar            a status line along the top edge of every screen
//   Niri           workspaces and the focused window, from niri
//   Theme          colours, the character grid, motion
//   Label, Level, SignalBars, Value, Passing, Segment, DitherFade
//                  what the bar is built from
//
// This file gathers what the bar shows from the system and holds the few
// things it can do. Everything arrives as it changes; nothing polls.
//   time           QuickShell's clock
//   windows        niri's event stream (Niri.qml) and the window list
//   sound          PipeWire
//   battery        UPower
//   network        NetworkManager
//   playing track  MPRIS
//   input method   fcitx5, through its tray item
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

    // Keeps the sound output bound, so its volume can be read and set.
    PwObjectTracker {
        objects: [root.soundOutput]
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
}
