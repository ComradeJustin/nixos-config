import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Design mockup for the shell redesign, round three. Entry point.
//
// The look borrows from departuremono.com: flat slabs, thin rules, small
// labels over larger values, and an inverted block for whatever is selected.
//   Bar            a ruled strip of cells along the top edge
//   Ring           the summoned layer: six stations on an orbit; the focused
//                  one opens into a table of its controls
//   VolumeReadout  a slab that drops out of the bar on a volume change
//   Toast          a slab that drops out of the bar for a notification
//
// The motion is real. The content is sample data; only the clock is live and
// nothing is wired to the system.
//
// One-time setup (the font is not installed system-wide yet):
//   nix build nixpkgs#recursive -o ~/nixos-config/configs/shell-mockups/recursive-font
// Start:  systemd-run --user --unit=shell-mockup --collect quickshell -p ~/nixos-config/configs/shell-mockups
// Stop:   systemctl --user stop shell-mockup
// Drive:  the control strip at the bottom of the screen, or
//   qs -p ~/nixos-config/configs/shell-mockups ipc call shell-mockup <ring|turn 1|open|back|volume|toast>
// In the ring: h l turn, enter opens a station, j k select, esc backs out.
// Files reload on save.
ShellRoot {
    id: root

    // --- State ---
    property bool ringOpen: false
    // How many steps the ring has been turned. Never wraps (see Ring.qml).
    property int turns: 0
    // Whether the focused station is opened into its controls.
    property bool dived: false
    // Which control is selected while dived.
    property int fanIndex: 0
    property int volume: 35
    property bool volumeShown: false
    property bool toastShown: false

    readonly property var now: clock.date

    // --- Sample content: the six stations and their controls ---
    // `level` is a meter reading from 0 to 1, or -1 for "no meter".
    readonly property var stations: [
        {
            name: "Launch",
            readout: "apps, files, commands",
            level: -1,
            controls: [
                {
                    label: "search",
                    value: "type to find anything",
                    level: -1
                },
                {
                    label: "recent",
                    value: "Firefox",
                    level: -1
                },
                {
                    label: "recent",
                    value: "Ghostty",
                    level: -1
                },
                {
                    label: "recent",
                    value: "Cursor",
                    level: -1
                },
                {
                    label: "recent",
                    value: "Nautilus",
                    level: -1
                }
            ]
        },
        {
            name: "System",
            readout: "volume " + root.volume + "  ·  brightness 60",
            level: root.volume / 100,
            controls: [
                {
                    label: "volume",
                    value: String(root.volume),
                    level: root.volume / 100
                },
                {
                    label: "brightness",
                    value: "60",
                    level: 0.6
                },
                {
                    label: "night light",
                    value: "On until 07:00",
                    level: -1
                },
                {
                    label: "quiet",
                    value: "Off",
                    level: -1
                },
                {
                    label: "keep awake",
                    value: "Off",
                    level: -1
                }
            ]
        },
        {
            name: "Network",
            readout: "Home-5G  ·  exit nixpc",
            level: 0.75,
            controls: [
                {
                    label: "wi-fi",
                    value: "Home-5G",
                    level: 0.75
                },
                {
                    label: "exit node",
                    value: "nixpc",
                    level: -1
                },
                {
                    label: "bluetooth",
                    value: "Off",
                    level: -1
                },
                {
                    label: "tailnet",
                    value: "4 devices online",
                    level: -1
                }
            ]
        },
        {
            name: "Media",
            readout: "Shelter — Porter Robinson",
            level: 0.4,
            controls: [
                {
                    label: "playing",
                    value: "Shelter",
                    level: 0.4
                },
                {
                    label: "artist",
                    value: "Porter Robinson & Madeon",
                    level: -1
                },
                {
                    label: "action",
                    value: "Pause",
                    level: -1
                },
                {
                    label: "action",
                    value: "Next track",
                    level: -1
                }
            ]
        },
        {
            name: "Inbox",
            readout: "2 unread",
            level: 0.4,
            controls: [
                {
                    label: "vesktop",
                    value: "Mara: are you still coming tonight?",
                    level: -1
                },
                {
                    label: "nh",
                    value: "Rebuild finished",
                    level: -1
                },
                {
                    label: "action",
                    value: "Dismiss all",
                    level: -1
                }
            ]
        },
        {
            name: "Session",
            readout: "up 21 h  ·  battery 28",
            level: 0.28,
            controls: [
                {
                    label: "action",
                    value: "Lock",
                    level: -1
                },
                {
                    label: "action",
                    value: "Suspend",
                    level: -1
                },
                {
                    label: "action",
                    value: "Log out",
                    level: -1
                },
                {
                    label: "action",
                    value: "Restart",
                    level: -1
                },
                {
                    label: "action",
                    value: "Power off",
                    level: -1
                }
            ]
        }
    ]

    // --- What the keys, the control strip and IPC all call ---
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

    Bar {
        shell: root
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

        function back(): void {
            root.back();
        }

        function volume(): void {
            root.bumpVolume();
        }

        function toast(): void {
            root.showToast();
        }
    }

    // Control strip for reviewing the mockup. Not part of the design.
    PanelWindow {
        anchors.bottom: true
        margins.bottom: 10
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: controls.implicitWidth + 12
        implicitHeight: 32
        color: "transparent"
        WlrLayershell.namespace: "shell-mockup"
        WlrLayershell.layer: WlrLayer.Top

        Rectangle {
            anchors.fill: parent
            color: Theme.slab
            border.width: 1
            border.color: Theme.rule

            Row {
                id: controls

                anchors.centerIn: parent
                spacing: 4

                Choice {
                    label: "Summon ring"
                    onChosen: root.toggleRing()
                }

                Choice {
                    label: "Volume key"
                    onChosen: root.bumpVolume()
                }

                Choice {
                    label: "Notification"
                    onChosen: root.showToast()
                }
            }
        }
    }

    // One clickable button in the control strip.
    component Choice: Rectangle {
        id: choice

        property string label
        signal chosen

        width: choiceLabel.implicitWidth + 20
        height: 22
        color: choiceArea.containsMouse ? Theme.accent : "transparent"

        Label {
            id: choiceLabel

            anchors.centerIn: parent
            text: choice.label
            caps: true
            color: choiceArea.containsMouse ? Theme.onAccent : Theme.inkDim
            font.pixelSize: 9
        }

        MouseArea {
            id: choiceArea

            anchors.fill: parent
            hoverEnabled: true
            onClicked: choice.chosen()
        }
    }
}
