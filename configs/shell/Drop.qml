import QtQuick
import Quickshell
import Quickshell.Wayland

// A panel that drops out of the bar, under the segment that was clicked:
// the inbox, the tray, the network, sound, power. It shows the shell's open
// page (PageView.qml) just as the ring does, and takes the keyboard while
// it is open, with the same keys. Esc backs out of a page that was opened
// from it, then closes it; a second click on the same segment closes it too.
//
// shell.dropOpen says that the open pages are drawn here and not in the
// ring. A change of page wipes the panel away and wipes the next one in.
PanelWindow {
    id: drop

    // The shell root (shell.qml), which holds the state.
    required property var shell

    // 0 = nothing showing, 1 = the whole panel. It drops to nothing while
    // a change of page waits.
    property real shown: shell.dropOpen && shell.dived && !shell.stackPending ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    // The page on screen has gone: let the waiting change of page happen.
    onShownChanged: {
        if (shown === 0 && shell.dropOpen && shell.stackPending)
            shell.commitStack();
    }

    Connections {
        target: drop.shell

        // Nothing is on screen yet, so there is nothing to wipe away first.
        function onStackPendingChanged(): void {
            if (drop.shell.stackPending && drop.shell.dropOpen && drop.shown === 0)
                drop.shell.commitStack();
        }
    }

    // On the screen whose bar was clicked. Opened by a key, it is left to
    // the compositor, which picks the screen in use.
    Binding {
        target: drop
        property: "screen"
        value: drop.shell.dropScreen
        when: drop.shell.dropScreen !== null
    }

    // Stay mapped until the panel has been wiped away.
    visible: shell.dropOpen || shown > 0
    anchors {
        top: true
        left: true
    }
    // Under the segment, moved left as far as it takes to stay on the screen.
    margins.left: screen !== null ? Math.max(0, Math.min(shell.dropX, screen.width - implicitWidth - Theme.cellWidth)) : shell.dropX
    // Directly under the bar, or against the top of the screen when a
    // fullscreen window has covered the bar.
    margins.top: shell.fullscreen ? 0 : Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: view.implicitWidth
    implicitHeight: view.implicitHeight
    color: "transparent"
    WlrLayershell.namespace: "shell"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shell.dropOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible)
            view.forceActiveFocus();
    }

    PageView {
        id: view

        shell: drop.shell
        shown: drop.shown
        // Esc on the page the panel opened with closes the panel.
        backWord: drop.shell.pageStack.length > 1 ? "back" : "close"
        focus: true

        Keys.onPressed: event => drop.shell.pressKey(event)
    }
}
