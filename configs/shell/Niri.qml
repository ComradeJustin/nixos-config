import QtQuick
import Quickshell
import Quickshell.Io

// What niri knows that the shell shows: the workspaces, the open windows,
// and the window that has the keyboard. It reads niri's event stream, which
// niri sends as things happen, so nothing polls. It can also ask niri to
// switch workspace or window.
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
    // Every open window: { id, app, title }.
    property var windows: []
    // Whether the workspace with the keyboard has no windows. False until
    // niri has reported, so nothing that waits for an empty desktop shows
    // by mistake.
    property bool focusedWorkspaceEmpty: false

    // Whether a program is recording or sharing the screen.
    property bool screenShared: false
    // niri's record of each recording or share, by its stream id.
    property var castByStream: ({})

    // niri's own records, by id. Plain bookkeeping: after every event the
    // four properties above are worked out again from these.
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
                niri.markFocused(window.id);
            niri.windowById[window.id] = window;
        } else if (event.WindowClosed) {
            delete niri.windowById[event.WindowClosed.id];
        } else if (event.WindowFocusChanged) {
            // The id is null when no window has the keyboard.
            niri.markFocused(event.WindowFocusChanged.id);
        } else if (event.CastsChanged) {
            const casts = {};
            for (const cast of event.CastsChanged.casts)
                casts[cast.stream_id] = cast;
            niri.castByStream = casts;
        } else if (event.CastStartedOrChanged) {
            const cast = event.CastStartedOrChanged.cast;
            niri.castByStream[cast.stream_id] = cast;
        } else if (event.CastStopped) {
            delete niri.castByStream[event.CastStopped.stream_id];
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

    // Record which window has the keyboard; null for none.
    function markFocused(id: var): void {
        for (const otherId in niri.windowById)
            niri.windowById[otherId].is_focused = false;
        if (id !== null && niri.windowById[id] !== undefined)
            niri.windowById[id].is_focused = true;
    }

    // Work out what the shell shows from niri's records.
    function summarise(): void {
        const occupied = {};
        const windows = [];
        let title = "";
        for (const windowId in niri.windowById) {
            const window = niri.windowById[windowId];
            occupied[window.workspace_id] = true;
            if (window.is_focused)
                title = window.title || "";
            windows.push({
                id: window.id,
                app: window.app_id || "",
                title: window.title || ""
            });
        }

        const summary = [];
        let focusedEmpty = false;
        for (const workspaceId in niri.workspaceById) {
            const workspace = niri.workspaceById[workspaceId];
            if (workspace.is_focused)
                focusedEmpty = occupied[workspace.id] !== true;
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
        niri.windows = windows;
        niri.focusedWorkspaceEmpty = focusedEmpty;

        let shared = false;
        for (const streamId in niri.castByStream) {
            if (niri.castByStream[streamId].is_active)
                shared = true;
        }
        niri.screenShared = shared;
    }

    // Switch to a workspace by its number.
    function focusWorkspace(index: int): void {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(index)]);
    }

    // Switch to a window by niri's id for it.
    function focusWindow(id: int): void {
        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(id)]);
    }

    Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: line => niri.handleEvent(line)
        }
    }
}
