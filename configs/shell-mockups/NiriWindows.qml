import QtQuick
import Quickshell
import Quickshell.Io

// Watches niri for one thing: whether the focused workspace has any
// windows on it. It reads niri's event stream, which niri sends as things
// happen, so nothing polls.
//
// Each line of the stream is one JSON object with a single key naming the
// event. The ones that matter here say which workspace is focused and
// which workspace each window is on.
Scope {
    id: watcher

    // False until niri has said otherwise, so nothing that depends on an
    // empty workspace shows by mistake.
    property bool focusedWorkspaceEmpty: false

    // The focused workspace's id, and each open window's workspace id by
    // window id. Plain bookkeeping; only focusedWorkspaceEmpty is watched.
    property int focusedWorkspace: -1
    property var workspaceOfWindow: ({})

    function handleEvent(line: string): void {
        const event = JSON.parse(line);
        if (event.WorkspacesChanged) {
            for (const workspace of event.WorkspacesChanged.workspaces) {
                if (workspace.is_focused)
                    watcher.focusedWorkspace = workspace.id;
            }
        } else if (event.WorkspaceActivated) {
            if (event.WorkspaceActivated.focused)
                watcher.focusedWorkspace = event.WorkspaceActivated.id;
        } else if (event.WindowsChanged) {
            const workspaces = {};
            for (const window of event.WindowsChanged.windows)
                workspaces[window.id] = window.workspace_id;
            watcher.workspaceOfWindow = workspaces;
        } else if (event.WindowOpenedOrChanged) {
            const window = event.WindowOpenedOrChanged.window;
            watcher.workspaceOfWindow[window.id] = window.workspace_id;
        } else if (event.WindowClosed) {
            delete watcher.workspaceOfWindow[event.WindowClosed.id];
        } else {
            // Some other event: nothing here depends on it.
            return;
        }

        let windowsOnFocused = 0;
        for (const windowId in watcher.workspaceOfWindow) {
            if (watcher.workspaceOfWindow[windowId] === watcher.focusedWorkspace)
                windowsOnFocused += 1;
        }
        watcher.focusedWorkspaceEmpty = windowsOnFocused === 0;
    }

    Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: line => watcher.handleEvent(line)
        }
    }
}
