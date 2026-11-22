import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Design mockup for the shell redesign, round six. Entry point.
//
// The shell is drawn like a terminal UI, in the pixel font Departure Mono on
// a fixed grid of character cells: borders are box-drawing characters, bars
// are block characters, and whatever is focused or selected is in reverse
// video.
//   Bar            a status line along the top edge of every screen
//   Ring           the summoned layer: six station names on a dotted orbit
//                  around a clock; the focused one opens into a panel
//   VolumeReadout  a panel that drops out of the bar on a volume change
//   Toast          a panel that drops out of the bar for a notification
//   Box, Level     the panel frame and the bar they are all built from
//   Graph, Spinner a braille history graph and a busy mark, used in panels
//   DitherFade     the dithered wipe everything appears and disappears with
//
// The motion is real. The content is sample data; only the clock is live and
// nothing is wired to the system.
//
// One-time setup (the font is not installed system-wide yet):
//   nix build nixpkgs#nerd-fonts.departure-mono -o ~/nixos-config/configs/shell-mockups/departure-mono-font
// Start:  systemd-run --user --unit=shell-mockup --collect quickshell -p ~/nixos-config/configs/shell-mockups
// Stop:   systemctl --user stop shell-mockup
// Drive:  the four buttons at the bottom of the screen, or
//   qs -p ~/nixos-config/configs/shell-mockups ipc call shell-mockup <ring|turn 1|open|select 1|back|volume|toast|workspace>
// In the ring: h l turn, enter opens a station, j k select, esc backs out.
// Files reload on save.
ShellRoot {
    id: root

    // --- State ---
    property bool ringOpen: false
    // How many steps the ring has been turned. Never wraps (see Ring.qml).
    property int turns: 0
    // Whether the focused station is opened into its list.
    property bool dived: false
    // Which line is selected while a station is open.
    property int fanIndex: 0
    property int volume: 35
    property bool volumeShown: false
    property bool toastShown: false
    // Which workspace is focused, counting from 0.
    property int workspace: 1
    // Whether the focused window is fullscreen, from QuickShell's own window
    // list. It updates the moment the window changes; nothing polls. niri
    // covers the bar then, so the bar dithers away and drop-down panels
    // sit against the top of the screen.
    // While the ring has the keyboard no window counts as focused, so this
    // reads false; the bar is covered or dimmed then, so it does not show.
    readonly property bool fullscreen: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen : false

    readonly property var now: clock.date

    // --- Sample content: the six stations and the settings inside each ---
    // kind "level" has a bar (level 0 to 1) and a number; "graph" has a
    // history (samples 0 to 1) and a number; "switch" is on or off; "busy"
    // is something in progress; "text" is just a value.
    readonly property var stations: [
        {
            name: "Launch",
            controls: [
                {
                    label: "Firefox",
                    kind: "text",
                    value: "browser"
                },
                {
                    label: "Ghostty",
                    kind: "text",
                    value: "terminal"
                },
                {
                    label: "Cursor",
                    kind: "text",
                    value: "editor"
                },
                {
                    label: "Files",
                    kind: "text",
                    value: "file manager"
                },
                {
                    label: "Search",
                    kind: "text",
                    value: "type to find anything"
                }
            ]
        },
        {
            name: "System",
            controls: [
                {
                    label: "Volume",
                    kind: "level",
                    value: String(root.volume),
                    level: root.volume / 100
                },
                {
                    label: "Brightness",
                    kind: "level",
                    value: "60",
                    level: 0.6
                },
                {
                    label: "CPU",
                    kind: "graph",
                    value: "12%",
                    samples: root.sampleHistory(44, 3)
                },
                {
                    label: "Night light",
                    kind: "switch",
                    value: "until 07:00",
                    on: true
                },
                {
                    label: "Quiet",
                    kind: "switch",
                    value: "off",
                    on: false
                },
                {
                    label: "Keep awake",
                    kind: "switch",
                    value: "off",
                    on: false
                }
            ]
        },
        {
            name: "Network",
            controls: [
                {
                    label: "Wi-Fi",
                    kind: "level",
                    value: "Home-5G",
                    level: 0.75
                },
                {
                    label: "Traffic",
                    kind: "graph",
                    value: "1.2M/s",
                    samples: root.sampleHistory(44, 5)
                },
                {
                    label: "Exit node",
                    kind: "switch",
                    value: "nixpc",
                    on: true
                },
                {
                    label: "Tailnet",
                    kind: "text",
                    value: "4 devices online"
                },
                {
                    label: "Bluetooth",
                    kind: "switch",
                    value: "off",
                    on: false
                }
            ]
        },
        {
            name: "Media",
            controls: [
                {
                    label: "Shelter",
                    kind: "level",
                    value: "1:32",
                    level: 0.4
                },
                {
                    label: "Artist",
                    kind: "text",
                    value: "Porter Robinson & Madeon"
                },
                {
                    label: "Pause",
                    kind: "text",
                    value: ""
                },
                {
                    label: "Next track",
                    kind: "text",
                    value: ""
                }
            ]
        },
        {
            name: "Inbox",
            controls: [
                {
                    label: "Mara",
                    kind: "text",
                    value: "are you still coming tonight?"
                },
                {
                    label: "nh",
                    kind: "busy",
                    value: "Rebuilding nixlaptop"
                },
                {
                    label: "Dismiss all",
                    kind: "text",
                    value: ""
                }
            ]
        },
        {
            name: "Session",
            controls: [
                {
                    label: "Lock",
                    kind: "text",
                    value: ""
                },
                {
                    label: "Suspend",
                    kind: "text",
                    value: ""
                },
                {
                    label: "Log out",
                    kind: "text",
                    value: ""
                },
                {
                    label: "Restart",
                    kind: "text",
                    value: ""
                },
                {
                    label: "Power off",
                    kind: "text",
                    value: ""
                }
            ]
        }
    ]

    // A made-up history for a graph: `count` samples from 0 to 1 in a wave
    // that takes about `period` samples to rise and fall.
    function sampleHistory(count: int, period: real): var {
        const samples = [];
        for (let index = 0; index < count; index++)
            samples.push(0.5 + 0.5 * Math.sin(index / period) * Math.cos(index / (period * 2.7)));
        return samples;
    }

    // --- What the keys, the control words and IPC all call ---
    function toggleRing(): void {
        root.dived = false;
        root.ringOpen = !root.ringOpen;
    }

    function rotate(step: int): void {
        root.turns += step;
    }

    function diveIn(): void {
        root.fanIndex = 0;
        root.dived = true;
    }

    // Esc: leave the station first, then close the ring.
    function back(): void {
        if (root.dived)
            root.dived = false;
        else
            root.ringOpen = false;
    }

    function moveSelection(step: int): void {
        const index = ((root.turns % root.stations.length) + root.stations.length) % root.stations.length;
        const last = root.stations[index].controls.length - 1;
        root.fanIndex = Math.max(0, Math.min(last, root.fanIndex + step));
    }

    // Pretend a volume key was pressed: raise the volume and show the readout.
    function bumpVolume(): void {
        root.volume = root.volume >= 100 ? 10 : root.volume + 10;
        root.volumeShown = true;
        volumeHide.restart();
    }

    // Pretend a notification arrived.
    function showToast(): void {
        root.toastShown = true;
        toastHide.restart();
    }

    // Pretend the next workspace was switched to.
    function nextWorkspace(): void {
        root.workspace = (root.workspace + 1) % 5;
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Timer {
        id: volumeHide

        interval: 1600
        onTriggered: root.volumeShown = false
    }

    Timer {
        id: toastHide

        interval: 4500
        onTriggered: root.toastShown = false
    }

    // One bar on every screen. The ring and the drop-down panels are made
    // once and appear on one screen.
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            shell: root
            screen: modelData
        }
    }

    Ring {
        shell: root
    }

    VolumeReadout {
        shell: root
    }

    Toast {
        shell: root
    }

    IpcHandler {
        target: "shell-mockup"

        function ring(): void {
            root.toggleRing();
        }

        function turn(step: int): void {
            root.rotate(step);
        }

        function open(): void {
            root.diveIn();
        }

        function select(step: int): void {
            root.moveSelection(step);
        }

        function back(): void {
            root.back();
        }

        function volume(): void {
            root.bumpVolume();
        }

        function toast(): void {
            root.showToast();
        }

        function workspace(): void {
            root.nextWorkspace();
        }
    }

    // Four buttons for driving the mockup. Not part of the design.
    PanelWindow {
        anchors.bottom: true
        margins.bottom: 10
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: controls.width + 4 * Theme.cellWidth
        implicitHeight: Theme.barHeight
        color: Theme.slab
        WlrLayershell.namespace: "shell-mockup"
        WlrLayershell.layer: WlrLayer.Top

        Row {
            id: controls

            x: 2 * Theme.cellWidth
            y: Theme.barTextY
            spacing: 2 * Theme.cellWidth

            Repeater {
                model: [["summon ring", () => root.toggleRing()], ["volume key", () => root.bumpVolume()], ["notification", () => root.showToast()], ["next workspace", () => root.nextWorkspace()]]

                Label {
                    id: button

                    required property var modelData

                    text: "[ " + modelData[0] + " ]"
                    color: buttonArea.containsMouse ? Theme.accent : Theme.inkDim

                    MouseArea {
                        id: buttonArea

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: button.modelData[1]()
                    }
                }
            }
        }
    }
}
