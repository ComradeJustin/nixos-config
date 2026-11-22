import QtQuick
import Quickshell
import Quickshell.Wayland

// Things that interrupt: a password prompt when an app asks for
// administrator rights, a warning that the screen is about to lock, a
// warning that the battery is nearly empty. Each is one page
// (sample-data.js, dialogs) shown in the middle of the screen over the
// dimming, with the keyboard.
//
// With a password field: typing fills it, enter allows (or, with nothing
// typed, shows the wrong-password state), esc denies. Without one: any key
// dismisses it. It only counts the keys pressed and never keeps what was
// typed.
PanelWindow {
    id: dialog

    // The shell root (shell.qml). shell.dialogName names the dialog that is
    // up, or is "" for none.
    required property var shell

    // The dialog that is drawn. It keeps the last name while the panel is
    // wiped away, so the panel does not empty before it has gone.
    property string drawnName: ""
    readonly property var page: drawnName === "" ? null : shell.dialogs[drawnName]
    readonly property bool hasField: page !== null && page.field !== undefined
    readonly property bool inTrouble: page !== null && page.alert === true

    // 0 = nothing showing, 1 = the whole dialog.
    property real shown: shell.dialogName !== "" ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    Connections {
        target: dialog.shell

        function onDialogNameChanged(): void {
            if (dialog.shell.dialogName !== "")
                dialog.drawnName = dialog.shell.dialogName;
        }
    }

    // Stay mapped until the dialog has been wiped away.
    visible: shell.dialogName !== "" || shown > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shell.dialogName !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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

            // Without a password field, any key dismisses the dialog.
            if (!dialog.hasField || event.key === Qt.Key_Escape) {
                shell.closeDialog();
                return;
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (shell.dialogTyped === 0)
                    shell.dialogRefused = true;
                else
                    shell.closeDialog();
            } else if (event.key === Qt.Key_Backspace) {
                shell.dialogTyped = Math.max(0, shell.dialogTyped - 1);
            } else if (event.text.length === 1 && event.text >= " ") {
                shell.dialogTyped += 1;
                shell.dialogRefused = false;
            }
        }

        Panel {
            x: Theme.snapX((parent.width - panelWidth) / 2)
            y: Theme.snapY((parent.height - panelHeight) / 2)
            page: dialog.page
            entries: dialog.page ? dialog.page.rows : []
            // Nothing in a dialog is selected.
            selectedIndex: -1
            // The field shows one dot per key pressed; this stands in for
            // the text that was not kept.
            query: "•".repeat(dialog.shell.dialogTyped)
            cursor: dialog.shell.dialogTyped
            footer: dialog.hasField ? "↵ allow  esc deny" : "any key dismisses"
            titleColor: dialog.inTrouble ? Theme.alert : Theme.ink
            lineColor: dialog.inTrouble ? Theme.alert : Theme.line
            shown: dialog.shown
        }
    }
}
