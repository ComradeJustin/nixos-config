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
//   Dialog         things that interrupt: a password prompt, a warning
//                  that the screen is about to lock, a nearly empty battery
//   Desktop        tiles that sit on the desktop under the windows
//   Tile           one applet's summary, used by the monitor and the desktop
//   NiriWindows    tells the desktop widgets when the workspace is empty
//   Box, Level     the panel frame and the bar they are all built from
//   Graph, Spinner a braille history graph and a busy mark, used in pages
//   SignalBars     Wi-Fi strength as four rising bars
//   DitherFade     the dithered wipe everything appears and disappears with
//
// The motion is real. The content is sample data (sample-data.js). The
// only live things are the clock, the calendar, and whether the focused
// workspace has windows; nothing else is wired to the system.
//
// One-time setup (the font is not installed system-wide yet):
//   nix build nixpkgs#nerd-fonts.departure-mono -o ~/nixos-config/configs/shell-mockups/departure-mono-font
// Start:  systemd-run --user --unit=shell-mockup --collect quickshell -p ~/nixos-config/configs/shell-mockups
// Stop:   systemctl --user stop shell-mockup
// Drive:  the buttons at the bottom of the screen, or
//   qs -p ~/nixos-config/configs/shell-mockups ipc call shell-mockup <name>
//   where <name> is one of: ring, turn 1, open, select 1, back, type abc,
//   cursor -1, page clipboard, monitor, applet 2, expand, scroll 1,
//   volume, mute, microphone, brightness, toast, dismiss, quiet,
//   workspace, states, rebuild, calendar, month 1, lock, finger,
//   dialog authenticate, privacy, caps, desktop
// In the ring: h l turn, enter opens, j k or the arrows select, esc backs
// out. In a page with a text field, letters type, up and down select, and
// left, right, home, end, backspace, delete and ctrl+u edit the text.
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
    property int microphoneLevel: 60
    property bool microphoneMuted: false
    // Which of the three the drop-down readout is showing: "volume",
    // "brightness" or "microphone".
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
    // Whether something is using the microphone, the camera or the screen.
    property bool microphoneInUse: false
    property bool cameraInUse: false
    property bool screenShared: false
    property bool capsLock: false
    // Which of the privacy samples is showing: 0 nothing, 1 the microphone,
    // 2 the microphone, camera and screen.
    property int privacyStep: 0
    // Which month the calendar shows, counted in months from this one.
    property int calendarOffset: 0
    // Whether "Dismiss all" has emptied the inbox.
    property bool inboxEmpty: false
    // Do not disturb: notifications are counted but not shown.
    property bool quiet: false
    // The serial number of the notification that was last dismissed by hand.
    property int dismissedSerial: 0
    // Which fingerprint sample the lock screen shows: 0 waiting, 1 reading,
    // 2 not recognised.
    property int fingerprintStep: 0
    property bool desktopShown: true
    // Whether the focused workspace has no windows, from niri.
    readonly property bool workspaceEmpty: niriWindows.focusedWorkspaceEmpty

    // --- Dialogs ---
    // The name of the dialog that is up, or "" for none.
    property string dialogName: ""
    // How many characters have been typed into its password field. Only
    // the count is kept, never the characters.
    property int dialogTyped: 0
    property bool dialogRefused: false
    // The time left before a dialog acts by itself, from 1 to 0.
    property real dialogCountdown: 1
    readonly property var dialogs: SampleData.dialogs({
        countdown: root.dialogCountdown,
        refused: root.dialogRefused
    })

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
        online: root.online,
        trouble: root.statePreset === 1,
        inboxEmpty: root.inboxEmpty,
        quiet: root.quiet
    })

    // The monitor's applets, in grid order.
    readonly property var applets: SampleData.applets({
        rebuilding: root.rebuilding,
        rebuildProgress: root.rebuildProgress,
        battery: root.battery,
        charging: root.charging,
        online: root.online,
        trouble: root.statePreset === 1
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
        root.cursor = 0;
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
        } else if (row.does === "monitor") {
            root.toggleMonitor();
        } else if (row.does === "dismissAll") {
            root.inboxEmpty = true;
            root.unreadCount = 0;
        } else if (row.does === "toggleQuiet") {
            root.quiet = !root.quiet;
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

    // --- The text field of the innermost page ---
    // Whether there is one to type into right now.
    readonly property bool fieldOpen: page !== null && page.field !== undefined && !stackPending

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

    function toggleMicrophoneMute(): void {
        root.microphoneMuted = !root.microphoneMuted;
        root.showReadout("microphone");
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

    // Whether a notification on screen is in this place of the stack.
    function toastPlaceTaken(place: int): bool {
        for (let index = 0; index < toastModel.count; index++) {
            if (toastModel.get(index).place === place)
                return true;
        }
        return false;
    }

    // Pretend a notification arrived. It takes the highest free place in
    // the stack and keeps it until it leaves, so nothing ever moves. With
    // do not disturb on it is only counted.
    function showToast(): void {
        root.unreadCount += 1;
        root.inboxEmpty = false;
        if (root.quiet)
            return;
        let place = 0;
        while (root.toastPlaceTaken(place))
            place += 1;
        root.toastSerial += 1;
        toastModel.append({
            sample: root.nextToast,
            serial: root.toastSerial,
            place: place
        });
        root.nextToast = (root.nextToast + 1) % SampleData.toasts.length;
    }

    // Dismiss the newest notification on screen by hand. It is wiped away
    // and no longer counts as waiting.
    function dismissToast(): void {
        let newest = 0;
        for (let index = 0; index < toastModel.count; index++)
            newest = Math.max(newest, toastModel.get(index).serial);
        if (newest === 0 || newest === root.dismissedSerial)
            return;
        root.dismissedSerial = newest;
        root.unreadCount = Math.max(0, root.unreadCount - 1);
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

    // Step through the privacy samples: nothing, the microphone, everything.
    function cyclePrivacy(): void {
        root.privacyStep = (root.privacyStep + 1) % 3;
        root.microphoneInUse = root.privacyStep >= 1;
        root.cameraInUse = root.privacyStep === 2;
        root.screenShared = root.privacyStep === 2;
    }

    function toggleCalendar(): void {
        root.calendarOffset = 0;
        root.calendarShown = !root.calendarShown;
    }

    // Put a dialog up, by its name in sample-data.js.
    function showDialog(name: string): void {
        if (root.dialogs[name] === undefined)
            return;
        root.dialogTyped = 0;
        root.dialogRefused = false;
        root.dialogCountdown = 1;
        root.dialogName = name;
    }

    function closeDialog(): void {
        root.dialogName = "";
    }

    // Pretend a system rebuild started.
    function startRebuild(): void {
        root.rebuildProgress = 0;
        root.rebuilding = true;
    }

    ListModel {
        id: toastModel
    }

    NiriWindows {
        id: niriWindows
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

    // Runs a dialog's time down, while one that counts down is up. When
    // the time is out the dialog goes, and "about to lock" locks.
    Timer {
        interval: 200
        repeat: true
        running: root.dialogName !== "" && root.dialogs[root.dialogName].countsDown
        onTriggered: {
            root.dialogCountdown = Math.max(0, root.dialogCountdown - 0.03);
            if (root.dialogCountdown > 0)
                return;
            if (root.dialogName === "lockSoon")
                root.lockShown = true;
            root.closeDialog();
        }
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

    Dialog {
        shell: root
    }

    Desktop {
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

        function cursor(step: int): void {
            root.placeCursor(root.cursor + step);
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

        function microphone(): void {
            root.toggleMicrophoneMute();
        }

        function brightness(): void {
            root.bumpBrightness();
        }

        function dismiss(): void {
            root.dismissToast();
        }

        function quiet(): void {
            root.quiet = !root.quiet;
        }

        function finger(): void {
            root.fingerprintStep = (root.fingerprintStep + 1) % 3;
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
            root.toggleCalendar();
        }

        function month(step: int): void {
            root.calendarOffset += step;
        }

        function dialog(name: string): void {
            if (root.dialogName === name)
                root.closeDialog();
            else
                root.showDialog(name);
        }

        function privacy(): void {
            root.cyclePrivacy();
        }

        function caps(): void {
            root.capsLock = !root.capsLock;
        }

        function desktop(): void {
            root.desktopShown = !root.desktopShown;
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
        implicitHeight: controls.height + 2 * Theme.barTextY
        color: Theme.slab
        WlrLayershell.namespace: "shell-mockup"
        WlrLayershell.layer: WlrLayer.Top

        Flow {
            id: controls

            x: 2 * Theme.cellWidth
            y: Theme.barTextY
            // Wide enough for two rows of buttons.
            width: 120 * Theme.cellWidth
            spacing: 2 * Theme.cellWidth

            Repeater {
                model: [["ring", () => root.toggleRing()], ["monitor", () => root.toggleMonitor()], ["vol", () => root.bumpVolume()], ["mute", () => root.toggleMute()], ["mic", () => root.toggleMicrophoneMute()], ["bright", () => root.bumpBrightness()], ["notify", () => root.showToast()], ["dismiss", () => root.dismissToast()], ["quiet", () => root.quiet = !root.quiet], ["workspace", () => root.nextWorkspace()], ["states", () => root.cycleStates()], ["rebuild", () => root.startRebuild()], ["calendar", () => root.toggleCalendar()], ["lock", () => root.lockShown = true], ["password", () => root.showDialog("authenticate")], ["idle", () => root.showDialog("lockSoon")], ["battery", () => root.showDialog("batteryCritical")], ["privacy", () => root.cyclePrivacy()], ["caps", () => root.capsLock = !root.capsLock], ["desktop", () => root.desktopShown = !root.desktopShown]]

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
