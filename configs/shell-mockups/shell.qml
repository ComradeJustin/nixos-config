import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "sample-data.js" as SampleData

// Design mockup for the shell redesign, round seven. Entry point.
//
// The shell is drawn like a terminal UI, in the pixel font Departure Mono on
// a fixed grid of character cells: borders are box-drawing characters, bars
// are the font's progress-bar pieces, and whatever is focused or selected
// is in reverse video.
//   Bar            a status line along the top edge of every screen
//   Ring           the summoned layer: station names on a braille orbit
//                  around a clock; the focused one opens into pages
//   Panel          one page inside the ring: a line of text input and a
//                  scrolling list of rows that can open further pages
//   Monitor        the other summoned layer: a grid of applets (rebuild,
//                  processor, memory, ...) that each expand to a full view
//   Readout        a panel that drops out of the bar when the volume or
//                  brightness changes
//   Toasts         notifications, stacked under the bar's left end
//   Calendar       a month that drops out of the bar's clock
//   Lock           the lock screen
//   Box, Level     the panel frame and the bar they are all built from
//   Graph, Spinner a braille history graph and a busy mark, used in pages
//   SignalBars     Wi-Fi strength as four rising bars
//   DitherFade     the dithered wipe everything appears and disappears with
//
// The motion is real. The content is sample data (sample-data.js); only the
// clock and the calendar are live and nothing is wired to the system.
//
// One-time setup (the font is not installed system-wide yet):
//   nix build nixpkgs#nerd-fonts.departure-mono -o ~/nixos-config/configs/shell-mockups/departure-mono-font
// Start:  systemd-run --user --unit=shell-mockup --collect quickshell -p ~/nixos-config/configs/shell-mockups
// Stop:   systemctl --user stop shell-mockup
// Drive:  the buttons at the bottom of the screen, or
//   qs -p ~/nixos-config/configs/shell-mockups ipc call shell-mockup <name>
//   where <name> is one of: ring, turn 1, open, select 1, back, type abc,
//   page clipboard, monitor, applet 2, expand, scroll 1, volume, mute,
//   brightness, toast, workspace, states, rebuild, calendar, lock
// In the ring: h l turn, enter opens, j k or the arrows select, esc backs
// out. In a page with a text field, letters type and the arrows select.
// In the monitor: h j k l move between applets, enter expands, esc backs out.
// Files reload on save.
ShellRoot {
    id: root

    // --- The ring ---
    property bool ringOpen: false
    // How many steps the ring has been turned. Never wraps (see Ring.qml).
    property int turns: 0
    readonly property var stations: SampleData.stations
    readonly property int focusedIndex: ((turns % stations.length) + stations.length) % stations.length

    // The pages open inside the focused station, innermost last. Empty
    // while the ring shows its names.
    property var pageStack: []
    // The selected row of each of those pages.
    property var selectionStack: []
    // What has been typed into the innermost page's text field.
    property string query: ""
    // A change of page waits here while the page on screen is wiped away.
    // Ring.qml calls commitStack() once it has gone.
    property bool stackPending: false
    property var nextPageStack: []
    property var nextSelectionStack: []

    readonly property bool dived: pageStack.length > 0
    readonly property var page: dived ? pages[pageStack[pageStack.length - 1]] : null
    readonly property int selectedIndex: dived && selectionStack.length > 0 ? selectionStack[selectionStack.length - 1] : 0
    // The innermost page's rows, narrowed by what has been typed.
    readonly property var pageRows: page ? matchingRows(page, query) : []

    // --- The monitor ---
    property bool monitorOpen: false
    // Which applet is focused, and whether it is expanded.
    property int monitorIndex: 0
    property bool monitorExpanded: false
    // The selected row of the expanded applet.
    property int monitorSelected: 0
    // How many applets sit side by side in the grid.
    readonly property int monitorColumns: 3

    // --- Sample state that the buttons change ---
    property int volume: 35
    property bool muted: false
    property int brightness: 60
    // Which of the two the drop-down readout is showing: "volume" or "brightness".
    property string readoutKind: "volume"
    property bool readoutShown: false
    property real battery: 0.28
    property bool charging: false
    property bool online: true
    // Which set of states is showing: 0 all well, 1 trouble, 2 charging.
    property int statePreset: 0
    // Which workspace is focused, counting from 0.
    property int workspace: 1
    // Notifications not yet looked at.
    property int unreadCount: 2
    // Which sample notification the next press of "notify" shows.
    property int nextToast: 0
    // Counts notifications, so each one on screen has its own number.
    property int toastSerial: 0
    readonly property alias toastList: toastModel
    // A system rebuild in progress, from 0 to 1.
    property bool rebuilding: false
    property real rebuildProgress: 0
    property bool calendarShown: false
    property bool lockShown: false

    // Whether the focused window is fullscreen, from QuickShell's own window
    // list. It updates the moment the window changes; nothing polls. niri
    // covers the bar then, so the bar dithers away and drop-down panels
    // sit against the top of the screen.
    // While the ring has the keyboard no window counts as focused, so this
    // reads false; the bar is covered or dimmed then, so it does not show.
    readonly property bool fullscreen: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen : false

    readonly property var now: clock.date

    // Every page that can open in the ring, by name.
    readonly property var pages: SampleData.pages({
        volume: root.volume,
        muted: root.muted,
        brightness: root.brightness,
        battery: root.battery,
        charging: root.charging,
        online: root.online
    })

    // The monitor's applets, in grid order.
    readonly property var applets: SampleData.applets({
        rebuilding: root.rebuilding,
        rebuildProgress: root.rebuildProgress,
        battery: root.battery,
        charging: root.charging,
        online: root.online
    })

    // --- The ring: what the keys, the buttons and IPC all call ---
    // Only one of the ring and the monitor is open at a time.
    function toggleRing(): void {
        if (root.ringOpen) {
            root.ringOpen = false;
            if (root.dived)
                root.changeStack([], []);
        } else {
            root.closeMonitor();
            root.ringOpen = true;
        }
    }

    function rotate(step: int): void {
        if (!root.dived)
            root.turns += step;
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
        root.stackPending = false;
    }

    // Enter: open the focused station, or act on the selected row.
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
        if (row.opens) {
            root.changeStack(root.pageStack.concat([row.opens]), root.selectionStack.concat([0]));
        } else if (row.does === "back") {
            root.back();
        } else if (row.does === "lock") {
            root.toggleRing();
            root.lockShown = true;
        }
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

    function moveSelection(step: int): void {
        if (!root.dived || root.stackPending || root.pageRows.length === 0)
            return;
        const last = root.pageRows.length - 1;
        root.select(Math.max(0, Math.min(last, root.selectedIndex + step)));
    }

    // Typing into the innermost page's text field. The first match is selected.
    function typeText(text: string): void {
        if (!root.page || !root.page.field || root.stackPending)
            return;
        root.query += text;
        root.select(0);
    }

    function eraseText(): void {
        if (!root.page || !root.page.field || root.stackPending)
            return;
        root.query = root.query.slice(0, -1);
        root.select(0);
    }

    // Open the ring straight at one page, as a key binding would.
    function openPage(pageName: string): void {
        if (root.pages[pageName] === undefined)
            return;
        root.ringOpen = true;
        root.changeStack([pageName], [0]);
    }

    // --- The monitor ---
    function toggleMonitor(): void {
        if (root.monitorOpen) {
            root.closeMonitor();
            return;
        }
        if (root.ringOpen)
            root.toggleRing();
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

    // --- Pretend keys and events ---
    function bumpVolume(): void {
        root.muted = false;
        root.volume = root.volume >= 100 ? 10 : root.volume + 5;
        root.showReadout("volume");
    }

    function toggleMute(): void {
        root.muted = !root.muted;
        root.showReadout("volume");
    }

    function bumpBrightness(): void {
        root.brightness = root.brightness >= 100 ? 10 : root.brightness + 10;
        root.showReadout("brightness");
    }

    function showReadout(kind: string): void {
        root.readoutKind = kind;
        root.readoutShown = true;
        readoutHide.restart();
    }

    // Pretend a notification arrived.
    function showToast(): void {
        root.toastSerial += 1;
        toastModel.append({
            sample: root.nextToast,
            serial: root.toastSerial
        });
        root.nextToast = (root.nextToast + 1) % SampleData.toasts.length;
        root.unreadCount += 1;
    }

    // Take a notification off the screen, by its serial number.
    function removeToast(serial: int): void {
        for (let index = 0; index < toastModel.count; index++) {
            if (toastModel.get(index).serial === serial) {
                toastModel.remove(index);
                return;
            }
        }
    }

    // Pretend the next workspace was switched to.
    function nextWorkspace(): void {
        root.workspace = (root.workspace + 1) % 5;
    }

    // Step through the sample states: all well, trouble, charging.
    function cycleStates(): void {
        root.statePreset = (root.statePreset + 1) % 3;
        const trouble = root.statePreset === 1;
        root.battery = root.statePreset === 0 ? 0.28 : 0.12;
        root.charging = root.statePreset === 2;
        root.online = !trouble;
        root.muted = trouble;
    }

    // Pretend a system rebuild started.
    function startRebuild(): void {
        root.rebuildProgress = 0;
        root.rebuilding = true;
    }

    ListModel {
        id: toastModel
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Timer {
        id: readoutHide

        interval: 1600
        onTriggered: root.readoutShown = false
    }

    // Moves the pretend rebuild along. Only runs during one.
    Timer {
        interval: 250
        repeat: true
        running: root.rebuilding
        onTriggered: {
            root.rebuildProgress = Math.min(1, root.rebuildProgress + 0.04);
            if (root.rebuildProgress >= 1)
                root.rebuilding = false;
        }
    }

    // One bar on every screen. Everything else is made once and appears on
    // one screen.
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

    Monitor {
        shell: root
    }

    Readout {
        shell: root
    }

    Toasts {
        shell: root
    }

    Calendar {
        shell: root
    }

    Lock {
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
            root.act();
        }

        function select(step: int): void {
            root.moveSelection(step);
        }

        function back(): void {
            root.back();
        }

        function type(text: string): void {
            root.typeText(text);
        }

        function page(pageName: string): void {
            root.openPage(pageName);
        }

        function monitor(): void {
            root.toggleMonitor();
        }

        function applet(index: int): void {
            root.moveApplet(index - root.monitorIndex);
        }

        function expand(): void {
            if (root.monitorExpanded)
                root.monitorBack();
            else
                root.expandApplet();
        }

        function scroll(step: int): void {
            root.monitorScroll(step);
        }

        function volume(): void {
            root.bumpVolume();
        }

        function mute(): void {
            root.toggleMute();
        }

        function brightness(): void {
            root.bumpBrightness();
        }

        function toast(): void {
            root.showToast();
        }

        function workspace(): void {
            root.nextWorkspace();
        }

        function states(): void {
            root.cycleStates();
        }

        function rebuild(): void {
            root.startRebuild();
        }

        function calendar(): void {
            root.calendarShown = !root.calendarShown;
        }

        function lock(): void {
            root.lockShown = !root.lockShown;
        }
    }

    // Buttons for driving the mockup. Not part of the design.
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
                model: [["ring", () => root.toggleRing()], ["monitor", () => root.toggleMonitor()], ["vol", () => root.bumpVolume()], ["mute", () => root.toggleMute()], ["bright", () => root.bumpBrightness()], ["notify", () => root.showToast()], ["workspace", () => root.nextWorkspace()], ["states", () => root.cycleStates()], ["rebuild", () => root.startRebuild()], ["calendar", () => root.calendarShown = !root.calendarShown], ["lock", () => root.lockShown = true]]

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
