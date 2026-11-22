import QtQuick
import Quickshell
import Quickshell.Wayland

// Things that interrupt, shown as one page in the middle of the screen over
// the dimming: the password prompt when a program asks for administrator
// rights, and the warning that the screen is about to lock.
//
// shell.qml decides which is up and what it says (shell.dialogPage). The
// password prompt takes the keyboard: typing fills its field, enter
// answers, esc turns the request down. The lock warning takes nothing: any
// key or movement makes the system take it away.
PanelWindow {
    id: dialog

    // The shell root (shell.qml).
    required property var shell

    // The page that is drawn. It keeps the last one while the panel is
    // wiped away, so the panel does not empty before it has gone.
    property var drawnPage: null

    // 0 = nothing showing, 1 = the whole dialog.
    property real shown: shell.dialogPage !== null ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    Connections {
        target: dialog.shell

        function onDialogPageChanged(): void {
            if (dialog.shell.dialogPage !== null)
                dialog.drawnPage = dialog.shell.dialogPage;
        }
    }

    // Stay mapped until the dialog has been wiped away.
    visible: shell.dialogPage !== null || shown > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "shell"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shell.dialogTakesKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible)
            stage.forceActiveFocus();
    }

    Dim {
        level: dialog.shown
    }

    Item {
        id: stage

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const shell = dialog.shell;
            event.accepted = true;
            if (event.key === Qt.Key_Escape)
                shell.cancelDialog();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                shell.submitDialog();
            else if (event.key === Qt.Key_Backspace)
                shell.dialogTyped = shell.dialogTyped.slice(0, -1);
            else if (event.text.length === 1 && event.text >= " ")
                shell.dialogTyped += event.text;
        }

        Panel {
            x: Theme.snapX((parent.width - panelWidth) / 2)
            y: Theme.snapY((parent.height - panelHeight) / 2)
            page: dialog.drawnPage
            entries: dialog.drawnPage !== null ? dialog.drawnPage.rows : []
            // Nothing in a dialog is selected.
            selectedIndex: -1
            query: dialog.shell.dialogTyped
            cursor: dialog.shell.dialogTyped.length
            footer: dialog.drawnPage !== null ? dialog.drawnPage.footer : ""
            shown: dialog.shown
        }
    }
}
