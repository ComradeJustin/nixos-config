import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.Polkit
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland

// The desktop shell. Entry point.
//
// It is drawn like a terminal UI, in the pixel font Departure Mono on a
// fixed grid of character cells. These are its parts:
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
//   PageView       the Panel that shows whichever page is open
//   Drop           a panel that drops out of the bar under what was clicked
//                  and shows a page there: inbox, tray, network, sound, power
//   Monitor        the other summoned layer: one dashboard of panels
//                  (processor, memory, network, disks, ...) with graphs
//   MonitorData    reads the system for it while it is open
//                  (system-readings.sh)
//   Calendar       a month that drops out of the bar's clock
//   Dialog         things that interrupt: the password prompt for
//                  administrator rights, the warning before the idle lock
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
//   network        NetworkManager, and BlueZ for airplane mode
//   tailscale      "tailscale status", asked at the start, when the
//                  Network page opens and after a change
//   camera         inotifywait on the camera's device files
//   displays       "niri msg outputs", asked when their pages open
//   idle and sleep swayidle, which the shell runs with the chosen times
//   rebuild        scripts/rebuild.sh, which tells the shell how it is going
//   weather        wttr.in, asked when something that shows it comes up
//   playing track  MPRIS
//   input method   fcitx5, through its tray item
//   notifications  what apps send, kept until dismissed
//   brightness     brightnessctl, asked only when a key changes it
//   night light    wlsunset, run while it is switched on
//   admin rights   polkit: the shell is the agent that asks for the password
// Night light, keep awake, do not disturb, the idle and sleep settings and
// which bar segments show are remembered across a restart, in a small file
// in the shell's state folder.
//
// Keys reach it through IPC, from niri's key bindings (configs/niri):
//   qs -p ~/nixos-config/configs/shell ipc call shell <name>
//   where <name> is one of: volumeUp, volumeDown, volumeMute,
//   microphoneMute, brightnessUp, brightnessDown, quiet, dismissAll,
//   lock, lockPractice (a lock that also lets go by itself after a minute),
//   lockWake (ask the fingerprint reader again, after a suspend),
//   ring (open or close the ring), page <name> (open the ring at a page:
//   launch, clipboard, system, network, media, inbox, session, ...),
//   monitor (open or close the monitor), calendar, tray (drop the tray
//   out of the bar), drop <name> (drop another page there: inbox, network,
//   sound, power), search,
//   idleWarning and idleResume (swayidle calls these before the idle lock),
//   build <phase> <made> <total> <names> (scripts/rebuild.sh reports a
//   rebuild's progress with this),
//   and, for driving the ring without the keyboard: turn <steps>, open,
//   select <steps>, adjust <step>, back, type <text>
// In the ring: h l turn, enter opens or acts, j k or the arrows select,
// left and right move a level, esc backs out. "/" searches the page:
// it brings up a field, and typing narrows the rows. In a page with a
// text field, letters type, up and down select, and left, right, home,
// end, backspace, delete and ctrl+u edit the text. The mouse works too.
// A panel dropped out of the bar takes the same keys (pressKey below).
// The lock is also reached through swayidle (see "Idle and sleep" below),
// which calls it when the session is asked to lock: after sitting idle,
// before a suspend, and by "loginctl lock-session".
//
// It runs as the user service "shell", and its font and the programs it
// calls are installed by the system (modules/desktop/shell.nix, fonts.nix).
// After changing a file:  systemctl --user restart shell
// It does not reload by itself, and the service brings it back if it ever
// crashes: the lock screen lives in here, and a locked session whose lock
// screen has gone shows nothing to unlock it with. (Lock.qml puts the lock
// screen back whenever the shell starts on a locked session.)
ShellRoot {
    id: root

    // Reloading while the session is locked destroys the lock screen in a
    // way the compositor refuses, which takes the whole shell down.
    settings.watchFiles: false

    // --- What is remembered ---
    // The switches that come back as they were left when the shell or the
    // machine restarts. They are kept in ~/.local/state/quickshell, in a
    // file that is written again whenever one of them changes.
    FileView {
        path: Quickshell.statePath("state.json")
        // Read before anything uses the values.
        blockLoading: true
        // There is no file the first time.
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: remembered

            property bool nightLight: false
            property bool keepAwake: false
            property bool quiet: false
            // Whether the machine goes to sleep by itself, and after how
            // long sitting idle it locks and sleeps.
            property bool sleepsItself: true
            property int lockMinutes: 3
            property int sleepMinutes: 30
            // The bar's segments that are switched off, by name.
            property var barHidden: []
        }
    }

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
    // Whether "/" has brought up a search field on a page without a text
    // field of its own.
    property bool searching: false
    // A change of page waits here while the page on screen is wiped away.
    // Ring.qml calls commitStack() once it has gone.
    property bool stackPending: false
    property var nextPageStack: []
    property var nextSelectionStack: []

    // Open pages are drawn in the ring, or in a panel that drops out of
    // the bar under the segment that was clicked (Drop.qml). `dropOpen`
    // says which, and `dropX` where the panel hangs, in pixels from the
    // left of the screen. Like the pages, they change only once the page
    // on screen has been wiped away, so a change waits in the two below.
    property bool dropOpen: false
    property real dropX: 0
    property bool nextDropOpen: false
    property real nextDropX: 0

    readonly property bool dived: pageStack.length > 0
    readonly property string pageName: dived ? pageStack[pageStack.length - 1] : ""
    readonly property var page: dived ? pageSource.named(pageName) : null
    readonly property int selectedIndex: dived && selectionStack.length > 0 ? selectionStack[selectionStack.length - 1] : 0
    // The innermost page's rows, narrowed by what has been typed.
    readonly property var pageRows: page ? matchingRows(page, query) : []
    // Whether there is a text field to type into right now.
    readonly property bool fieldOpen: page !== null && (page.field !== undefined || searching) && !stackPending

    // Only one of the ring and the monitor is open at a time.
    function toggleRing(): void {
        if (root.ringOpen) {
            root.closeRing();
        } else {
            root.closeMonitor();
            root.closePages();
            root.ringOpen = true;
        }
    }

    // Close whatever pages are open, in the ring or in a dropped panel.
    function closePages(): void {
        root.nextDropOpen = false;
        if (root.dived)
            root.changeStack([], []);
    }

    // Close the ring, and a dropped panel with it.
    function closeRing(): void {
        root.ringOpen = false;
        root.closePages();
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
        root.openPageAt(name, 0);
    }

    // Open the ring at one page with one of its rows selected.
    function openPageAt(name: string, row: int): void {
        root.closeMonitor();
        root.ringOpen = true;
        root.nextDropOpen = false;
        root.focusStation(pageSource.pageStation[name]);
        root.changeStack([name], [row]);
    }

    // Drop a page out of the bar, with the panel's left edge at `x`. Asking
    // for the one that is already there closes it, so one click or key
    // opens and closes it.
    function openDrop(name: string, x: real): void {
        if (pageSource.named(name) === null)
            return;
        if (root.dropOpen && root.pageStack[0] === name) {
            root.closePages();
            return;
        }
        root.closeMonitor();
        root.calendarShown = false;
        root.ringOpen = false;
        root.nextDropOpen = true;
        root.nextDropX = x;
        root.changeStack([name], [0]);
    }

    // The rows of a page that contain what has been typed. Typing narrows
    // a page whose own text field filters, and any page being searched.
    function matchingRows(page: var, typed: string): var {
        const filters = root.searching || (page.field !== undefined && page.field.filters);
        if (!filters || typed === "")
            return page.rows;
        const wanted = typed.toLowerCase();
        const matches = [];
        for (const row of page.rows) {
            const text = (row.label + " " + (row.value || "") + " " + (row.keywords || "")).toLowerCase();
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
        // With no page left open, a dropped panel is closed.
        root.dropOpen = root.nextDropOpen && root.nextPageStack.length > 0;
        root.nextDropOpen = root.dropOpen;
        root.dropX = root.nextDropX;
        root.pageStack = root.nextPageStack;
        root.selectionStack = root.nextSelectionStack;
        root.query = "";
        root.cursor = 0;
        root.searching = false;
        root.stackPending = false;
        root.selectReadable();
    }

    // Enter: open the focused station, or act on the selected row. A row
    // does its own thing first, then opens its page if it has one.
    function act(): void {
        if (root.stackPending)
            return;
        if (!root.dived) {
            if (root.ringOpen)
                root.changeStack([root.stations[root.focusedIndex].page], [0]);
            return;
        }
        if (root.pageRows.length === 0) {
            // A page that is only a text field: hand over what was typed.
            if (root.page !== null && root.page.field !== undefined && root.page.field.submit)
                root.page.field.submit(root.query);
            return;
        }
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

    // Esc: end a search, then leave the innermost page, then close the
    // ring. A dropped panel closes when its last page is left.
    function back(): void {
        if (root.stackPending)
            return;
        if (root.searching) {
            root.searching = false;
            root.query = "";
            root.cursor = 0;
            root.selectFirst();
            return;
        }
        if (root.dived)
            root.changeStack(root.pageStack.slice(0, -1), root.selectionStack.slice(0, -1));
        else
            root.ringOpen = false;
    }

    function select(index: int): void {
        root.selectionStack = root.selectionStack.slice(0, -1).concat([index]);
    }

    // Select the first row that can be selected.
    function selectFirst(): void {
        root.select(0);
        root.selectReadable();
    }

    // Rows can arrive after their page has opened, and can go while it is.
    onPageRowsChanged: root.selectReadable()

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

    // Keep the selection on a row that can be selected: back inside a list
    // that has grown shorter, and off a note onto the first row that is not.
    function selectReadable(): void {
        if (!root.dived || root.pageRows.length === 0)
            return;
        if (root.selectedIndex >= root.pageRows.length)
            root.select(root.pageRows.length - 1);
        if (root.pageRows[root.selectedIndex].kind !== "note")
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
        root.selectFirst();
    }

    // Backspace: take out the character before the cursor.
    function eraseText(): void {
        if (!root.fieldOpen || root.cursor === 0)
            return;
        root.query = root.query.slice(0, root.cursor - 1) + root.query.slice(root.cursor);
        root.cursor -= 1;
        root.selectFirst();
    }

    // Delete: take out the character under the cursor.
    function deleteText(): void {
        if (!root.fieldOpen || root.cursor >= root.query.length)
            return;
        root.query = root.query.slice(0, root.cursor) + root.query.slice(root.cursor + 1);
        root.selectFirst();
    }

    function clearText(): void {
        if (!root.fieldOpen)
            return;
        root.query = "";
        root.cursor = 0;
        root.selectFirst();
    }

    // Move the cursor to this position, kept inside the text.
    function placeCursor(position: int): void {
        if (!root.fieldOpen)
            return;
        root.cursor = Math.max(0, Math.min(root.query.length, position));
    }

    // A key pressed in the ring or in a dropped panel.
    function pressKey(event: var): void {
        const key = event.key;
        // Whether letters go into a text field: the page's own, or the
        // search field that "/" brings up on any other page.
        const hasField = root.page !== null && (root.page.field !== undefined || root.searching);
        event.accepted = true;

        if (key === Qt.Key_Escape) {
            root.back();
            return;
        }
        if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            root.act();
            return;
        }

        // The ring's names are showing: turn it, or open the focused one.
        if (!root.dived) {
            if (key === Qt.Key_L || key === Qt.Key_Right)
                root.rotate(1);
            else if (key === Qt.Key_H || key === Qt.Key_Left)
                root.rotate(-1);
            else if (key === Qt.Key_Space)
                root.act();
            return;
        }

        // A page is open. The arrows always move the selection.
        if (key === Qt.Key_Down) {
            root.moveSelection(1);
            return;
        }
        if (key === Qt.Key_Up) {
            root.moveSelection(-1);
            return;
        }

        // With a text field, the other keys edit its text.
        if (hasField) {
            const control = (event.modifiers & Qt.ControlModifier) !== 0;
            if (key === Qt.Key_Left)
                root.placeCursor(root.cursor - 1);
            else if (key === Qt.Key_Right)
                root.placeCursor(root.cursor + 1);
            else if (key === Qt.Key_Home || (control && key === Qt.Key_A))
                root.placeCursor(0);
            else if (key === Qt.Key_End || (control && key === Qt.Key_E))
                root.placeCursor(root.query.length);
            else if (control && key === Qt.Key_U)
                root.clearText();
            else if (key === Qt.Key_Backspace)
                root.eraseText();
            else if (key === Qt.Key_Delete)
                root.deleteText();
            else if (event.text.length === 1 && event.text >= " ")
                root.typeText(event.text);
            return;
        }

        // Without one, "/" brings up a search field.
        if (key === Qt.Key_Slash) {
            root.searching = true;
            return;
        }

        // And the letters move too. On a level, left and right move the
        // level; anywhere else they go back and act.
        const left = key === Qt.Key_H || key === Qt.Key_Left;
        const right = key === Qt.Key_L || key === Qt.Key_Right;
        const onLevel = root.pageRows.length > 0 && root.pageRows[root.selectedIndex].adjust !== undefined;
        if (key === Qt.Key_J)
            root.moveSelection(1);
        else if (key === Qt.Key_K)
            root.moveSelection(-1);
        else if (left && onLevel)
            root.adjust(-1);
        else if (right && onLevel)
            root.adjust(1);
        else if (left)
            root.back();
        else if (right)
            root.act();
    }

    function lock(): void {
        root.idleWarning = false;
        lockScreen.engage(false);
    }

    // --- Dialogs ---
    // The password prompt. The shell is the session's polkit agent: when a
    // program asks for administrator rights, polkit hands the request here
    // as a flow, which asks for what it needs a step at a time.
    PolkitAgent {
        id: polkitAgent
    }

    // The request being answered, or null.
    readonly property var authRequest: polkitAgent.isActive ? polkitAgent.flow : null
    // What has been typed into the dialog's field. It is cleared as soon as
    // it has been handed over.
    property string dialogTyped: ""

    onAuthRequestChanged: root.dialogTyped = ""

    // The warning before the idle lock: swayidle says when the machine has
    // sat idle and when it is touched again (see "Idle and sleep").
    property bool idleWarning: false
    readonly property int idleWarningSeconds: 30
    property int idleSecondsLeft: 0

    function warnIdle(): void {
        if (lockScreen.locked)
            return;
        root.idleSecondsLeft = root.idleWarningSeconds;
        root.idleWarning = true;
    }

    // Counts the warning down. Only runs while it is up.
    Timer {
        interval: 1000
        repeat: true
        running: root.idleWarning
        onTriggered: {
            root.idleSecondsLeft -= 1;
            if (root.idleSecondsLeft <= 0)
                root.idleWarning = false;
        }
    }

    // A sentence as lines no longer than `width` characters, broken at spaces.
    function wrappedLines(sentence: string, width: int): var {
        const lines = [];
        let line = "";
        for (const word of sentence.split(" ")) {
            if (line !== "" && line.length + 1 + word.length > width) {
                lines.push(line);
                line = word;
            } else {
                line = line === "" ? word : line + " " + word;
            }
        }
        if (line !== "")
            lines.push(line);
        return lines;
    }

    // The dialog that is up, as a page for Dialog.qml, or null for none.
    readonly property var dialogPage: {
        if (root.authRequest !== null)
            return root.passwordPage(root.authRequest);
        if (root.batteryCritical)
            return root.batteryPage();
        if (root.idleWarning)
            return root.idlePage();
        return null;
    }
    // The password prompt needs the keyboard, and the battery warning takes
    // any key as "keep going". The idle warning goes when swayidle sees the
    // machine touched.
    readonly property bool dialogTakesKeys: root.authRequest !== null || root.batteryCritical

    function passwordPage(request: var): var {
        // A line of the dialog holds 44 characters.
        const rows = [];
        for (const line of root.wrappedLines(request.message, 44))
            rows.push({
                label: line,
                kind: "note"
            });
        // What the request has said since: a wrong password, or the
        // fingerprint reader asking for a finger.
        for (const line of root.wrappedLines(request.supplementaryMessage, 44))
            rows.push({
                label: line,
                kind: "note",
                alert: request.supplementaryIsError
            });
        const page = {
            title: "Authenticate",
            footer: "↵ allow  esc deny",
            rows: rows
        };
        // The field is there once the request asks for something typed.
        if (request.isResponseRequired)
            page.field = {
                hint: request.inputPrompt.replace(":", "").trim().toLowerCase(),
                filters: false,
                secret: !request.responseVisible
            };
        return page;
    }

    function idlePage(): var {
        return {
            title: "Still there?",
            footer: "any key or movement stays",
            rows: [
                {
                    label: "Locking in",
                    kind: "level",
                    value: root.idleSecondsLeft + " s",
                    level: root.idleSecondsLeft / root.idleWarningSeconds
                }
            ]
        };
    }

    // Enter in the password prompt: hand over what was typed.
    function submitDialog(): void {
        if (root.authRequest === null || !root.authRequest.isResponseRequired)
            return;
        root.authRequest.submit(root.dialogTyped);
        root.dialogTyped = "";
    }

    // Esc in the password prompt: turn the request down. Any key in the
    // battery warning: call the sleep off.
    function cancelDialog(): void {
        if (root.authRequest !== null)
            root.authRequest.cancelAuthenticationRequest();
        else
            root.batteryCritical = false;
    }

    // --- The monitor ---
    property bool monitorOpen: false
    // Its panels, in bands from top to bottom (MonitorData.qml).
    readonly property var monitorBands: monitorData.bands

    function toggleMonitor(): void {
        if (root.monitorOpen) {
            root.closeMonitor();
            return;
        }
        root.closeRing();
        root.monitorOpen = true;
    }

    function closeMonitor(): void {
        root.monitorOpen = false;
    }

    // --- Rebuild ---
    // How a rebuild of the system is going. scripts/rebuild.sh reports
    // every change through "shell-call build ..." (reportBuild below); the
    // shell watches nothing itself.
    // What the rebuild is doing: "evaluating" (working out what to build),
    // "building", "finishing" (waiting for the answer, then switching) or
    // "copying" (to the cache). "" when none is running.
    property string buildPhase: ""
    // How many of the store paths it has to make exist so far.
    property int buildMade: 0
    property int buildTotal: 0
    // The names of what is being built right now, separated by commas,
    // and the last such names seen, for saying where a rebuild failed.
    property string buildNow: ""
    property string buildLastSeen: ""
    property var buildStarted: null
    // How the last rebuild ended, in words, and whether it failed. "" until
    // one has ended since the shell started.
    property string buildLast: ""
    property bool buildLastFailed: false
    readonly property bool building: buildPhase !== ""
    // Whole minutes since the rebuild started.
    readonly property int buildMinutes: building ? Math.max(0, Math.floor((now - buildStarted) / 60000)) : 0

    function reportBuild(phase: string, made: int, total: int, current: string): void {
        if (phase === "done" || phase === "failed") {
            root.finishBuild(phase === "failed");
            return;
        }
        if (!root.building) {
            root.buildStarted = new Date();
            root.buildLastSeen = "";
        }
        if (current !== "")
            root.buildLastSeen = current;
        root.buildPhase = phase;
        root.buildMade = made;
        root.buildTotal = total;
        root.buildNow = current;
    }

    // Note how the rebuild ended and say so in a notification.
    function finishBuild(failed: bool): void {
        // The end of a rebuild that this shell never saw start.
        if (!root.building)
            return;
        const ended = new Date();
        const seconds = Math.round((ended - root.buildStarted) / 1000);
        const took = seconds >= 60 ? Math.round(seconds / 60) + " min" : seconds + " s";
        root.buildLast = (failed ? "failed at " : "finished at ") + Qt.formatDateTime(ended, "hh:mm") + ", took " + took;
        if (failed && root.buildLastSeen !== "")
            root.buildLast += ", while building " + root.buildLastSeen;
        root.buildLastFailed = failed;
        root.buildPhase = "";
        root.buildNow = "";
        if (failed)
            Quickshell.execDetached(["notify-send", "--urgency=critical", "--app-name=Rebuild", "Rebuild failed", "after " + took + "; the terminal has the error"]);
        else
            Quickshell.execDetached(["notify-send", "--app-name=Rebuild", "Rebuild finished", "took " + took]);
    }

    // --- The tray ---
    // Where the bar's tray segment starts, in pixels from the left of the
    // screen. The bar keeps this up to date, so a key can drop the tray's
    // panel under it.
    property real trayTabX: 0
    // How many apps are running in the background.
    readonly property int trayCount: SystemTray.items.values.length

    // --- The calendar ---
    property bool calendarShown: false
    // Which month it shows, counted in months from this one.
    property int calendarOffset: 0

    function toggleCalendar(): void {
        if (root.dropOpen)
            root.closePages();
        root.calendarOffset = 0;
        root.calendarShown = !root.calendarShown;
        if (root.calendarShown)
            root.wantWeather();
    }

    // --- Weather ---
    // Today's weather where the machine is, from wttr.in, which places the
    // machine by its network address. It is asked for only when something
    // that shows it comes on screen (the desktop's Today tile, the
    // calendar) and the last answer is more than half an hour old.
    // { temperature, description, low, high, sunrise, sunset, place }, or
    // null until the first answer.
    property var weather: null
    // When it was last asked for, in milliseconds.
    property real weatherAsked: 0

    function wantWeather(): void {
        if (Date.now() - root.weatherAsked < 30 * 60 * 1000)
            return;
        root.weatherAsked = Date.now();
        weatherReader.running = true;
    }

    // A time as wttr.in writes it, "04:23 PM", on the 24-hour clock: "16:23".
    function clockTime(text: string): string {
        const parts = text.match(/^(\d+):(\d+) (AM|PM)$/);
        if (parts === null)
            return text;
        const hour = Number(parts[1]) % 12 + (parts[3] === "PM" ? 12 : 0);
        return (hour < 10 ? "0" : "") + hour + ":" + parts[2];
    }

    // The answer is JSON: the weather now, the place it is for, and each
    // day's range and sun times. Anything else, such as an error page, is
    // left alone.
    function readWeather(text: string): void {
        let answer;
        try {
            answer = JSON.parse(text);
        } catch (error) {
            return;
        }
        if (!answer.current_condition || !answer.weather || !answer.nearest_area)
            return;
        const now = answer.current_condition[0];
        const today = answer.weather[0];
        root.weather = {
            temperature: now.temp_C + "°",
            description: now.weatherDesc[0].value.trim().toLowerCase(),
            low: today.mintempC + "°",
            high: today.maxtempC + "°",
            sunrise: root.clockTime(today.astronomy[0].sunrise),
            sunset: root.clockTime(today.astronomy[0].sunset),
            place: answer.nearest_area[0].areaName[0].value
        };
    }

    Process {
        id: weatherReader

        command: ["curl", "--silent", "--max-time", "15", "https://wttr.in/?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: root.readWeather(text)
        }
    }

    // --- The desktop widgets ---
    // Whether the focused workspace has no windows, from niri.
    readonly property bool workspaceEmpty: niriState.focusedWorkspaceEmpty

    onWorkspaceEmptyChanged: {
        if (root.workspaceEmpty)
            root.wantWeather();
    }

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

    function changeMicrophoneVolume(step: int): void {
        if (root.microphoneReady)
            root.soundInput.audio.volume = Math.max(0, Math.min(1, root.soundInput.audio.volume + 0.05 * step));
    }

    // Whether any program is taking sound from the microphone: there is a
    // connection that starts at it.
    readonly property bool microphoneInUse: {
        for (const link of Pipewire.linkGroups.values) {
            if (link.source === root.soundInput)
                return true;
        }
        return false;
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

    // --- Night light and staying awake ---
    // Night light warms the screen's colours in the evening. It is
    // wlsunset, kept running while this is on, with fixed times.
    property alias nightLight: remembered.nightLight
    // Staying awake stops the screen dimming and the idle lock. The bar
    // holds the idle inhibitor (Bar.qml).
    property alias keepAwake: remembered.keepAwake

    Process {
        command: ["wlsunset", "-S", "07:00", "-s", "19:00", "-t", "4000", "-T", "6500"]
        running: root.nightLight
    }

    // --- Idle and sleep ---
    // After sitting idle the screen dims and a warning shows, then the
    // session locks, then the machine sleeps. swayidle does the waiting; the
    // shell runs it, so that the times can be changed here, and starts it
    // again whenever one changes.
    property alias lockMinutes: remembered.lockMinutes
    property alias sleepMinutes: remembered.sleepMinutes
    // Whether the machine goes to sleep by itself: after sitting idle, and
    // when the lid is shut. Switched off, it keeps running with the lid
    // shut; the screen still dims and locks.
    property alias sleepsItself: remembered.sleepsItself

    // swayidle's arguments: each "timeout" is seconds of idleness and what
    // to run then, with "resume" for when the machine is touched again.
    // Being asked to lock ("loginctl lock-session", from here or anywhere
    // else) runs the "lock" command, which is the lock screen. After a
    // sleep the lock asks the fingerprint reader again.
    readonly property var idleWatcherArguments: {
        const lockSeconds = root.lockMinutes * 60;
        let watcherArguments = ["timeout", String(lockSeconds - root.idleWarningSeconds), "brightnessctl -s set 10%; shell-call idleWarning", "resume", "brightnessctl -r; shell-call idleResume", "timeout", String(lockSeconds), "loginctl lock-session", "resume", "shell-call lockWake"];
        if (root.sleepsItself)
            watcherArguments = watcherArguments.concat(["timeout", String(root.sleepMinutes * 60), "systemctl suspend"]);
        return watcherArguments.concat(["before-sleep", "loginctl lock-session", "after-resume", "sleep 1; shell-call lockWake", "lock", "shell-call lock"]);
    }
    // New times: stop the watcher, and start it again a moment later with
    // them. The same timer starts it when the shell does.
    onIdleWatcherArgumentsChanged: {
        idleWatcher.running = false;
        idleWatcherStart.restart();
    }

    Timer {
        id: idleWatcherStart

        interval: 300
        running: true
        onTriggered: idleWatcher.running = true
    }

    Process {
        id: idleWatcher

        // Only one idle watcher may run, or the screen is dimmed twice and
        // stays dim: any other is stopped first.
        command: ["sh", "-c", "pkill -x swayidle; exec swayidle -w \"$@\"", "sh"].concat(root.idleWatcherArguments)
    }

    // While the machine is not to sleep by itself, shutting the lid must
    // not put it to sleep either: this holds the system's lid switch off.
    Process {
        command: ["systemd-inhibit", "--what=handle-lid-switch", "--who=Desktop shell", "--why=Sleep is switched off", "sleep", "infinity"]
        running: !root.sleepsItself
    }

    // --- The bar's segments ---
    // Any of them can be switched off (the Bar page, Pages.qml).
    property alias barHidden: remembered.barHidden

    function barShows(segment: string): bool {
        return !root.barHidden.includes(segment);
    }

    function toggleBarSegment(segment: string): void {
        const hidden = [];
        for (const name of root.barHidden) {
            if (name !== segment)
                hidden.push(name);
        }
        if (hidden.length === root.barHidden.length)
            hidden.push(segment);
        root.barHidden = hidden;
    }

    // --- Displays ---
    // What niri says about each screen, by its name such as "eDP-1": its
    // modes, the one in use, its scale and rotation. Read when the System
    // page or a display's page opens and after each change (Pages.qml).
    property var displays: ({})

    function readDisplays(): void {
        displayReader.running = true;
    }

    // Change a display with "niri msg output <name> ...", then read them
    // again. The change lasts until niri next loads its configuration.
    function changeDisplay(name: string, change: var): void {
        displayChange.command = ["niri", "msg", "output", name].concat(change);
        displayChange.running = true;
    }

    Process {
        id: displayReader

        command: ["niri", "msg", "--json", "outputs"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (text !== "")
                    root.displays = JSON.parse(text);
            }
        }
    }

    Process {
        id: displayChange

        onExited: root.readDisplays()
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
    property alias quiet: remembered.quiet
    // The notifications on screen now: for each its id, its place in the
    // stack, and its words as they were when it arrived.
    readonly property alias toastList: toastModel
    // How long a notification shows when it does not say, in milliseconds.
    readonly property int toastLifetime: 4500

    // When each notification arrived, by its id, in milliseconds.
    property var notificationArrivals: ({})

    // How long ago a notification arrived, in a few characters: "now",
    // "14m", "3h", "2d". The clock ticks once a minute, and so does this.
    function notificationAge(id: int): string {
        const arrived = root.notificationArrivals[id];
        if (arrived === undefined)
            return "";
        const minutes = Math.floor((root.now - arrived) / 60000);
        if (minutes < 1)
            return "now";
        if (minutes < 60)
            return minutes + "m";
        if (minutes < 1440)
            return Math.floor(minutes / 60) + "h";
        return Math.floor(minutes / 1440) + "d";
    }

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
        inlineReplySupported: true
        // Keep what is waiting when a file is saved and the shell reloads.
        keepOnReload: true

        onNotification: notification => {
            // Tracked means kept: it stays in the list until dismissed.
            notification.tracked = true;
            root.notificationArrivals[notification.id] = Date.now();
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

    // The battery in full, as rows: charge, rate, time left, health.
    readonly property var powerRows: monitorData.power.rows

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
            root.batteryCritical = false;
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
        // At the last level the machine is put to sleep, after a warning.
        if (passed === root.batteryWarnings[root.batteryWarnings.length - 1]) {
            root.warnBatteryCritical();
            return;
        }
        const minutes = Math.round(root.batteryDevice.timeToEmpty / 60);
        const timeLeft = minutes > 0 ? "about " + minutes + " minutes left, " : "";
        Quickshell.execDetached(["notify-send", "--urgency=critical", "--app-name=Battery", Math.round(root.battery * 100) + "% left", timeLeft + "plug in soon"]);
    }

    // The battery is nearly empty: a dialog counts down a minute, and then
    // the machine is put to sleep so that nothing is lost. Plugging in or
    // pressing a key calls it off.
    property bool batteryCritical: false
    readonly property int batteryCriticalSeconds: 60
    property int batterySecondsLeft: 0

    function warnBatteryCritical(): void {
        root.batterySecondsLeft = root.batteryCriticalSeconds;
        root.batteryCritical = true;
    }

    // Counts the warning down. Only runs while it is up.
    Timer {
        interval: 1000
        repeat: true
        running: root.batteryCritical
        onTriggered: {
            root.batterySecondsLeft -= 1;
            if (root.batterySecondsLeft > 0)
                return;
            root.batteryCritical = false;
            Quickshell.execDetached(["systemctl", "suspend"]);
        }
    }

    function batteryPage(): var {
        return {
            title: "Battery at " + Math.round(root.battery * 100) + "%",
            footer: "any key keeps going",
            rows: [
                {
                    label: "Sleeping in",
                    kind: "level",
                    value: root.batterySecondsLeft + " s",
                    level: root.batterySecondsLeft / root.batteryCriticalSeconds,
                    alert: true
                },
                {
                    label: "Plug in, or press any key to keep going",
                    kind: "note"
                }
            ]
        };
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
    // Airplane mode is every radio off: Wi-Fi and Bluetooth.
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool airplane: !Networking.wifiEnabled && (bluetoothAdapter === null || !bluetoothAdapter.enabled)
    // The network in use, or why there is none.
    readonly property string networkName: {
        if (wifiNetwork !== null)
            return wifiNetwork.name;
        if (wired)
            return "wired";
        if (airplane)
            return "airplane";
        return Networking.wifiEnabled ? "offline" : "wi-fi off";
    }

    // Turn every radio off, or back on.
    function toggleAirplane(): void {
        const radiosOn = root.airplane;
        Networking.wifiEnabled = radiosOn;
        if (root.bluetoothAdapter !== null)
            root.bluetoothAdapter.enabled = radiosOn;
    }
    // Wi-Fi signal strength from 0 to 1. A cable counts as full.
    readonly property real networkSignal: wifiNetwork !== null ? wifiNetwork.signalStrength : (wired ? 1 : 0)

    // --- Tailscale ---
    // Whether the tailnet is up, and the machines on it that offer to
    // carry this one's traffic: { name, inUse }. Nothing polls: the state
    // is read when the shell starts, when the Network page opens
    // (Pages.qml) and after each change made from here.
    property bool tailscaleRunning: false
    property var exitNodes: []
    readonly property bool exitNodeInUse: {
        for (const node of exitNodes) {
            if (node.inUse)
                return true;
        }
        return false;
    }

    function checkTailscale(): void {
        tailscaleStatus.running = true;
    }

    // "tailscale status --json" gives BackendState, and Peer: one entry
    // for each other machine, with HostName, ExitNodeOption (it offers to
    // be an exit node) and ExitNode (it is the one in use).
    function readTailscale(text: string): void {
        if (text === "")
            return;
        const status = JSON.parse(text);
        root.tailscaleRunning = status.BackendState === "Running";
        const peers = status.Peer || {};
        const nodes = [];
        for (const key in peers) {
            const peer = peers[key];
            if (peer.ExitNodeOption)
                nodes.push({
                    name: peer.HostName,
                    inUse: peer.ExitNode === true
                });
        }
        root.exitNodes = nodes;
    }

    // Run tailscale with these arguments, then read its state again. If
    // it refuses, say why in a notification.
    function tailscale(arguments: var): void {
        tailscaleCommand.command = ["tailscale"].concat(arguments);
        tailscaleCommand.running = true;
    }

    Process {
        id: tailscaleStatus

        command: ["tailscale", "status", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.readTailscale(text)
        }
    }

    Process {
        id: tailscaleCommand

        stderr: StdioCollector {
            id: tailscaleRefusal
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                Quickshell.execDetached(["notify-send", "--app-name=Tailscale", "Tailscale refused", tailscaleRefusal.text.trim()]);
            root.checkTailscale();
        }
    }

    // --- Camera ---
    // Whether something has the camera open. inotifywait reports each open
    // and close of the camera's device files as it happens, and the camera
    // is in use while more have been opened than closed. A camera that was
    // already open when the shell started is not counted.
    property int cameraOpens: 0
    readonly property bool cameraInUse: cameraOpens > 0

    Process {
        // Through sh for the "*": one device file for each of the camera's streams.
        command: ["sh", "-c", "exec inotifywait --monitor --quiet --event open --event close --format %e /dev/video*"]
        running: true
        stdout: SplitParser {
            // A line is OPEN, or the kind of close.
            onRead: line => {
                if (line.startsWith("OPEN"))
                    root.cameraOpens += 1;
                else
                    root.cameraOpens = Math.max(0, root.cameraOpens - 1);
            }
        }
    }

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
    // "Keyboard - English (US)" for plain typing, and names Mozc when the
    // Japanese input method is on. It reads other things at other times,
    // for instance while the ring has the keyboard, so only Mozc counts.
    readonly property var inputTrayItem: {
        for (const item of SystemTray.items.values) {
            if (item.id === "Fcitx")
                return item;
        }
        return null;
    }
    // False when fcitx5 is not running: there is nothing to show then.
    readonly property bool inputAvailable: inputTrayItem !== null
    readonly property bool inputJapanese: inputAvailable && inputTrayItem.tooltipTitle.toLowerCase().includes("mozc")

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

    Drop {
        shell: root
    }

    Dialog {
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

        function tray(): void {
            root.openDrop("tray", root.trayTabX);
        }

        function drop(name: string): void {
            root.openDrop(name, root.trayTabX);
        }

        function search(): void {
            root.searching = true;
        }

        function build(phase: string, made: int, total: int, current: string): void {
            root.reportBuild(phase, made, total, current);
        }

        function idleWarning(): void {
            root.warnIdle();
        }

        function idleResume(): void {
            root.idleWarning = false;
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
