import QtQuick
import Quickshell
import Quickshell.Io

// What niri knows that the shell shows: the workspaces, and the window that
// has the keyboard. It reads niri's event stream, which niri sends as
// things happen, so nothing polls. It can also ask niri to switch
// workspace.
//
// Each line of the stream is one JSON object with a single key naming the
// event. On connecting niri sends the whole state (WorkspacesChanged,
// WindowsChanged) and after that only what changes.
Scope {
    id: niri

    // Every workspace, in the order niri numbers them on each screen. Each
    // is { index, output, focused, active, occupied }: its number on its
    // screen, the screen's name, whether it has the keyboard, whether it
    // is the one showing on its screen, and whether it has any windows.
    property var workspaces: []
    // The title of the window that has the keyboard, or "" for none.
    property string focusedTitle: ""

    // niri's own records, by id. Plain bookkeeping: after every event the
    // two properties above are worked out again from these.
    property var workspaceById: ({})
    property var windowById: ({})

    function handleEvent(line: string): void {
        const event = JSON.parse(line);
        if (event.WorkspacesChanged) {
            const workspaces = {};
            for (const workspace of event.WorkspacesChanged.workspaces)
                workspaces[workspace.id] = workspace;
            niri.workspaceById = workspaces;
        } else if (event.WorkspaceActivated) {
            niri.activateWorkspace(event.WorkspaceActivated.id, event.WorkspaceActivated.focused);
        } else if (event.WindowsChanged) {
            const windows = {};
            for (const window of event.WindowsChanged.windows)
                windows[window.id] = window;
            niri.windowById = windows;
        } else if (event.WindowOpenedOrChanged) {
            const window = event.WindowOpenedOrChanged.window;
            // A window that arrives with the keyboard takes it from the rest.
            if (window.is_focused)
                niri.focusWindow(window.id);
            niri.windowById[window.id] = window;
        } else if (event.WindowClosed) {
            delete niri.windowById[event.WindowClosed.id];
        } else if (event.WindowFocusChanged) {
            // The id is null when no window has the keyboard.
            niri.focusWindow(event.WindowFocusChanged.id);
        } else {
            // Some other event: nothing here depends on it.
            return;
        }
        niri.summarise();
    }

    // A workspace became the one showing on its screen, and perhaps the
    // one with the keyboard.
    function activateWorkspace(id: int, focused: bool): void {
        const activated = niri.workspaceById[id];
        if (activated === undefined)
            return;
        for (const otherId in niri.workspaceById) {
            const other = niri.workspaceById[otherId];
            if (other.output === activated.output)
                other.is_active = false;
            if (focused)
                other.is_focused = false;
        }
        activated.is_active = true;
        if (focused)
            activated.is_focused = true;
    }

    function focusWindow(id: var): void {
        for (const otherId in niri.windowById)
            niri.windowById[otherId].is_focused = false;
        if (id !== null && niri.windowById[id] !== undefined)
            niri.windowById[id].is_focused = true;
    }

    // Work out what the shell shows from niri's records.
    function summarise(): void {
        const occupied = {};
        let title = "";
        for (const windowId in niri.windowById) {
            const window = niri.windowById[windowId];
            occupied[window.workspace_id] = true;
            if (window.is_focused)
                title = window.title || "";
        }

        const summary = [];
        for (const workspaceId in niri.workspaceById) {
            const workspace = niri.workspaceById[workspaceId];
            summary.push({
                index: workspace.idx,
                output: workspace.output,
                focused: workspace.is_focused,
                active: workspace.is_active,
                occupied: occupied[workspace.id] === true
            });
        }
        summary.sort((first, second) => first.index - second.index);

        niri.workspaces = summary;
        niri.focusedTitle = title;
    }

    // Switch to a workspace by its number.
    function focusWorkspace(index: int): void {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(index)]);
    }

    Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: line => niri.handleEvent(line)
        }
    }
}
