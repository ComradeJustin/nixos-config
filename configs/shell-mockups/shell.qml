import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Design mockup for the shell redesign, round four. Entry point.
//
// The design is type only: no boxes, rules, icons, meters or small headers.
// Weight, size and colour carry the hierarchy; one accent marks what is
// focused or selected.
//   Bar            one line of type along the top edge
//   Ring           the summoned layer: six words on an orbit around the
//                  time; the focused word opens into a list of its settings
//   VolumeReadout  a word and a number that drop out of the bar on a volume change
//   Toast          two lines that drop out of the bar for a notification
//
// The motion is real. The content is sample data; only the clock is live and
// nothing is wired to the system.
//
// One-time setup (the font is not installed system-wide yet):
//   nix build nixpkgs#recursive -o ~/nixos-config/configs/shell-mockups/recursive-font
// Start:  systemd-run --user --unit=shell-mockup --collect quickshell -p ~/nixos-config/configs/shell-mockups
// Stop:   systemctl --user stop shell-mockup
// Drive:  the three words at the bottom of the screen, or
//   qs -p ~/nixos-config/configs/shell-mockups ipc call shell-mockup <ring|turn 1|open|back|volume|toast>
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

    readonly property var now: clock.date

    // --- Sample content: the six stations and the lines inside each ---
    readonly property var stations: [
        {
            name: "Launch",
            controls: [
                {
                    label: "Firefox",
                    value: "browser"
                },
                {
                    label: "Ghostty",
                    value: "terminal"
                },
                {
                    label: "Cursor",
                    value: "editor"
                },
                {
                    label: "Files",
                    value: "file manager"
                },
                {
                    label: "Search",
                    value: "type to find anything"
                }
            ]
        },
        {
            name: "System",
            controls: [
                {
                    label: "Volume",
                    value: String(root.volume)
                },
                {
                    label: "Brightness",
                    value: "60"
                },
                {
                    label: "Night light",
                    value: "Until 07:00"
                },
                {
                    label: "Quiet",
                    value: "Off"
                },
                {
                    label: "Keep awake",
                    value: "Off"
                }
            ]
        },
        {
            name: "Network",
            controls: [
                {
                    label: "Wi-Fi",
                    value: "Home-5G"
                },
                {
                    label: "Exit node",
                    value: "nixpc"
                },
                {
                    label: "Tailnet",
                    value: "4 devices"
                },
                {
                    label: "Bluetooth",
                    value: "Off"
                }
            ]
        },
        {
            name: "Media",
            controls: [
                {
                    label: "Shelter",
                    value: "Porter Robinson & Madeon"
                },
                {
                    label: "Pause",
                    value: ""
                },
                {
                    label: "Next track",
                    value: ""
                }
            ]
        },
        {
            name: "Inbox",
            controls: [
                {
                    label: "Mara",
                    value: "are you still coming tonight?"
                },
                {
                    label: "nh",
                    value: "Rebuild finished"
                },
                {
                    label: "Dismiss all",
                    value: ""
                }
            ]
        },
        {
            name: "Session",
            controls: [
                {
                    label: "Lock",
                    value: ""
                },
                {
                    label: "Suspend",
                    value: ""
                },
                {
                    label: "Log out",
                    value: ""
                },
                {
                    label: "Restart",
                    value: ""
                },
                {
                    label: "Power off",
                    value: ""
                }
            ]
        }
    ]

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

    // Three words for driving the mockup. Not part of the design.
    PanelWindow {
        anchors.bottom: true
        margins.bottom: 10
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: controls.implicitWidth + 36
        implicitHeight: 30
        color: Theme.slab
        WlrLayershell.namespace: "shell-mockup"
        WlrLayershell.layer: WlrLayer.Top

        Row {
            id: controls

            anchors.centerIn: parent
            spacing: 26

            Repeater {
                model: [["Summon ring", () => root.toggleRing()], ["Volume key", () => root.bumpVolume()], ["Notification", () => root.showToast()]]

                Label {
                    id: word

                    required property var modelData

                    text: modelData[0]
                    weight: wordArea.containsMouse ? 800 : 420
                    color: wordArea.containsMouse ? Theme.accent : Theme.inkDim
                    font.pixelSize: 12

                    MouseArea {
                        id: wordArea

                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        onClicked: word.modelData[1]()
                    }
                }
            }
        }
    }
}
