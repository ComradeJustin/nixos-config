import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Wayland

// The login screen. Entry point.
//
// It is drawn like the desktop shell (configs/shell) and uses its pieces:
// Theme, Label, Box and the dither wipe are copied in beside this file
// when the system is built (modules/desktop/greeter.nix). It looks like the
// shell's lock screen: the time, the date, and a panel to type the password
// into.
//
// greetd, the login service, starts it in a niri of its own, which paints
// the same background from its first frame, and takes the password from it:
//   - it asks greetd to log the one user in, and greetd asks for a password
//   - enter hands over what was typed; a wrong one says so and asks again
//   - a right one wipes the panel away and starts the session
// F10 powers the machine off and F11 restarts it; each asks to be pressed
// twice.
//
// modules/desktop/greeter.nix sets, in the environment: GREETER_USER (who
// logs in), GREETER_HOST (the machine's name, for the title) and
// GREETER_SESSION (the command that starts the session).
ShellRoot {
    id: root

    // It runs from the Nix store, where nothing changes.
    settings.watchFiles: false

    readonly property string userName: Quickshell.env("GREETER_USER")
    readonly property string hostName: Quickshell.env("GREETER_HOST")
    readonly property string sessionCommand: Quickshell.env("GREETER_SESSION")

    // What has been typed. It is cleared as soon as it has been handed over.
    property string typed: ""
    // Whether greetd is waiting for the password, and whether one is being
    // checked.
    property bool passwordWanted: false
    property bool checking: false
    // The last password was wrong. Cleared by typing.
    property bool refused: false
    // Anything else greetd has to say, and whether it is an error.
    property string notice: ""
    property bool noticeIsError: false
    // "poweroff" or "reboot" after its key has been pressed once: a second
    // press does it, any other key calls it off.
    property string armed: ""
    // The password was right: the panel is wiped away, then the session starts.
    property bool leaving: false

    // 0 = nothing showing, 1 = everything. It wipes in when the greeter
    // starts and out when it leaves.
    property real shown: 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    onShownChanged: {
        if (shown === 0 && leaving)
            Greetd.launch([root.sessionCommand], [], true);
    }

    function askToLogIn(): void {
        root.passwordWanted = false;
        Greetd.createSession(root.userName);
    }

    Component.onCompleted: {
        root.shown = 1;
        root.askToLogIn();
    }

    // Enter: hand the password over, if greetd is waiting for one.
    function submit(): void {
        if (!root.passwordWanted || root.typed === "")
            return;
        root.passwordWanted = false;
        root.checking = true;
        Greetd.respond(root.typed);
        root.typed = "";
    }

    // F10 and F11: the first press arms, the second does it.
    function power(action: string): void {
        if (root.armed !== action) {
            root.armed = action;
            return;
        }
        root.armed = "";
        Quickshell.execDetached(["systemctl", action]);
    }

    Connections {
        target: Greetd

        // greetd asks for something or says something. A question waits
        // for the answer; anything else is only shown.
        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool): void {
            root.checking = false;
            if (responseRequired) {
                root.passwordWanted = true;
            } else {
                root.notice = message;
                root.noticeIsError = error;
            }
        }

        // A wrong password. greetd has dropped the attempt: start another.
        function onAuthFailure(message: string): void {
            root.checking = false;
            root.refused = true;
            retry.start();
        }

        function onReadyToLaunch(): void {
            root.checking = false;
            root.leaving = true;
            root.shown = 0;
        }

        function onError(error: string): void {
            root.checking = false;
            root.notice = error;
            root.noticeIsError = true;
            retry.start();
        }
    }

    // A moment after a failure, so that greetd has let go of the old attempt.
    Timer {
        id: retry

        interval: 300
        onTriggered: root.askToLogIn()
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // One layer over the whole screen, holding the keyboard.
    PanelWindow {
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.slab
        WlrLayershell.namespace: "greeter"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Item {
            id: stage

            anchors.fill: parent
            focus: true

            readonly property real centerX: Theme.snapX(width / 2)
            readonly property real centerY: Theme.snapY(height / 2)

            Keys.onPressed: event => {
                event.accepted = true;
                if (root.leaving)
                    return;
                if (event.key === Qt.Key_F10) {
                    root.power("poweroff");
                    return;
                }
                if (event.key === Qt.Key_F11) {
                    root.power("reboot");
                    return;
                }
                root.armed = "";
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.submit();
                } else if (event.key === Qt.Key_Escape) {
                    root.typed = "";
                    root.refused = false;
                } else if (event.key === Qt.Key_Backspace) {
                    root.typed = root.typed.slice(0, -1);
                } else if (event.text.length === 1 && event.text >= " ") {
                    root.typed += event.text;
                    root.refused = false;
                }
            }

            // The time at four times size and the date under it, wiped in
            // and out with the panel.
            Item {
                anchors.fill: parent
                visible: root.shown > 0
                layer.enabled: root.shown < 1
                layer.effect: DitherFade {
                    amount: root.shown
                    spread: Theme.wipeFront
                }

                Label {
                    x: stage.centerX - Theme.snapX(width / 2)
                    y: stage.centerY - 8 * Theme.cellHeight
                    text: Qt.formatDateTime(clock.date, "hh:mm")
                    scaleFactor: 4
                    color: Theme.ink
                }

                Label {
                    x: stage.centerX - Theme.snapX(width / 2)
                    y: stage.centerY - 4 * Theme.cellHeight
                    text: Qt.formatDateTime(clock.date, "dddd d MMMM")
                    color: Theme.inkDim
                    smallCaps: true
                }
            }

            Box {
                x: stage.centerX - Theme.snapX(panelWidth / 2)
                y: stage.centerY - Theme.cellHeight
                columns: 44
                rows: 3
                title: root.hostName
                titleColor: root.refused ? Theme.alert : Theme.ink
                footer: "↵ log in  f10 power off  f11 restart"
                shown: root.shown

                // Who is logging in.
                Row {
                    Label {
                        text: "user  "
                        color: Theme.inkDim
                    }

                    Label {
                        text: root.userName
                        color: Theme.ink
                    }
                }

                // The password field: a prompt, one dot per character, a
                // block cursor.
                Row {
                    y: Theme.cellHeight

                    Label {
                        text: "› "
                        color: Theme.accent
                    }

                    Label {
                        text: "•".repeat(root.typed.length)
                        color: Theme.ink
                    }

                    Label {
                        text: "█"
                        color: Theme.accent
                    }
                }

                // What is going on, most pressing first.
                Label {
                    readonly property bool wrong: root.armed !== "" || root.refused || root.noticeIsError || !Greetd.available

                    y: 2 * Theme.cellHeight
                    width: parent.width
                    elide: Text.ElideRight
                    text: {
                        if (root.armed === "poweroff")
                            return "press f10 again to power off";
                        if (root.armed === "reboot")
                            return "press f11 again to restart";
                        if (!Greetd.available)
                            return "the login service is not answering";
                        if (root.checking)
                            return "checking";
                        if (root.refused)
                            return "wrong password";
                        if (root.notice !== "")
                            return root.notice;
                        return "type your password";
                    }
                    color: wrong ? Theme.alert : Theme.inkDim
                }
            }
        }
    }
}
