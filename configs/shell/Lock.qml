import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

// The lock screen. It uses the compositor's session-lock protocol, so
// while it is locked nothing else is drawn and no other window gets the
// keyboard. Each screen shows the background colour, the clock, how many
// notifications are waiting (not what they say) and what is playing, and a
// panel with a password field.
//
// Two things can unlock it, and both are asked at once:
//   the password    typed into the field and checked on enter, with the
//                   shell's own rule file (pam/password)
//   a fingerprint   checked by the system's rule set for the old shell's
//                   lock, which waits at the reader until a finger matches
// Every login rule set on this system asks the reader first and waits for
// it, which is why the password has a rule file of its own.
//
// Locking is immediate: the compositor cuts to the lock, and the clock and
// panel are wiped in on top of it. Unlocking draws a curtain in the same
// colour over the desktop at the moment the lock lets go, and dithers the
// curtain away.
//
// A practice lock is an ordinary lock that also lets go by itself after a
// minute. It is for trying this out without any risk of being locked out.
//
// The lock screen belongs to the shell, so if the shell restarts, or
// reloads because one of its files was saved, while the session is locked,
// the session stays locked but there is nothing on screen to unlock it
// with. So whenever the shell starts it asks the system whether the session
// is locked, and if it is, puts the lock screen back.
Scope {
    id: lock

    // The shell root (shell.qml).
    required property var shell

    // What has been typed into the password field. It is cleared as soon
    // as it has been checked.
    property string typed: ""
    // Whether the last password was turned down.
    property bool refused: false
    // Whether the last finger was not recognised.
    property bool fingerRefused: false
    // Whether this lock lets go by itself.
    property bool practice: false
    readonly property bool locked: sessionLock.locked
    // The reader is waiting for a finger.
    readonly property bool fingerWanted: fingerprintCheck.active

    function engage(practice: bool): void {
        if (sessionLock.locked)
            return;
        lock.typed = "";
        lock.refused = false;
        lock.fingerRefused = false;
        lock.practice = practice;
        lock.shell.checkCapsLock();
        sessionLock.locked = true;
        fingerprintCheck.start();
    }

    // The machine woke up, or was touched after sitting idle. The reader's
    // check does not survive a suspend, so it is started again.
    function wake(): void {
        if (!sessionLock.locked || fingerprintCheck.active)
            return;
        lock.fingerRefused = false;
        fingerprintCheck.start();
    }

    // Enter: check what has been typed.
    function submit(): void {
        if (lock.typed === "" || passwordCheck.active)
            return;
        lock.refused = false;
        passwordCheck.start();
    }

    // Let go: draw the curtain and unlock under it, then stop both checks.
    // Unlocking comes first, so that nothing after it can leave the screen
    // locked.
    function release(): void {
        lock.curtain = 1;
        sessionLock.locked = false;
        curtainFade.restart();
        lock.typed = "";
        if (passwordCheck.active)
            passwordCheck.abort();
        if (fingerprintCheck.active)
            fingerprintCheck.abort();
    }

    // Ask the system whether this user's session is locked already. It
    // prints "yes" or "no".
    Process {
        command: ["sh", "-c", "loginctl show-session \"$(loginctl show-user \"$USER\" --property=Display --value)\" --property=LockedHint --value"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "yes")
                    lock.engage(false);
            }
        }
    }

    // --- The password ---
    PamContext {
        id: passwordCheck

        configDirectory: Quickshell.shellDir + "/pam"
        config: "password"

        // The rule file asks one thing: the password.
        onPamMessage: {
            if (passwordCheck.responseRequired)
                passwordCheck.respond(lock.typed);
        }

        onCompleted: result => {
            lock.typed = "";
            if (result === PamResult.Success)
                lock.release();
            else
                lock.refused = true;
        }

        onError: {
            lock.typed = "";
            lock.refused = true;
        }
    }

    // --- The fingerprint reader ---
    PamContext {
        id: fingerprintCheck

        // The system's rule set that asks the reader and keeps asking.
        config: "shell-lock"

        onPamMessage: {
            // After the reader that rule set asks for a password. If it
            // gets that far the reader could not be used (no finger
            // enrolled, or it is busy), so its part is over. Stopping is
            // put off until this handler has returned.
            if (fingerprintCheck.responseRequired) {
                Qt.callLater(() => fingerprintCheck.abort());
                return;
            }
            // Otherwise the reader is talking: an error means a finger
            // that was not recognised.
            lock.fingerRefused = fingerprintCheck.messageIsError;
        }

        onCompleted: result => {
            if (result === PamResult.Success)
                lock.release();
        }
    }

    // A practice lock lets go by itself.
    Timer {
        interval: 60000
        running: sessionLock.locked && lock.practice
        onTriggered: lock.release()
    }

    WlSessionLock {
        id: sessionLock

        // One of these is made for each screen.
        WlSessionLockSurface {
            id: surface

            color: Theme.slab

            Item {
                id: stage

                readonly property real centerX: Theme.snapX(width / 2)
                readonly property real centerY: Theme.snapY(height / 2)
                readonly property bool batteryLow: lock.shell.battery <= 0.2 && !lock.shell.charging
                // 0 = nothing showing, 1 = the clock and panel are showing.
                property real shown: 0

                Behavior on shown {
                    NumberAnimation {
                        duration: Theme.wipeMs
                    }
                }

                anchors.fill: parent
                focus: true
                // Drawn through the dither only while it is changing.
                layer.enabled: shown < 1
                layer.effect: DitherFade {
                    amount: stage.shown
                    spread: Theme.wipeFront
                }

                Component.onCompleted: {
                    shown = 1;
                    forceActiveFocus();
                }

                Keys.onPressed: event => {
                    event.accepted = true;
                    if (event.key === Qt.Key_CapsLock) {
                        lock.shell.capsLockPressed();
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        lock.submit();
                    } else if (event.key === Qt.Key_Escape) {
                        lock.typed = "";
                        lock.refused = false;
                    } else if (event.key === Qt.Key_Backspace) {
                        lock.typed = lock.typed.slice(0, -1);
                    } else if (event.text.length === 1 && event.text >= " ") {
                        lock.typed += event.text;
                        lock.refused = false;
                    }
                }

                // The time at four times size, the date under it.
                Label {
                    x: stage.centerX - Theme.snapX(width / 2)
                    y: stage.centerY - 8 * Theme.cellHeight
                    text: Qt.formatDateTime(lock.shell.now, "hh:mm")
                    scaleFactor: 4
                    color: Theme.ink
                }

                Label {
                    x: stage.centerX - Theme.snapX(width / 2)
                    y: stage.centerY - 4 * Theme.cellHeight
                    text: Qt.formatDateTime(lock.shell.now, "dddd d MMMM")
                    color: Theme.inkDim
                    smallCaps: true
                }

                // How many notifications are waiting, and the playing track.
                Label {
                    readonly property string waiting: lock.shell.unreadCount > 0 ? " " + lock.shell.unreadCount + " waiting" : ""
                    readonly property string playing: lock.shell.trackTitle !== "" ? "♪ " + lock.shell.trackTitle : ""

                    x: stage.centerX - Theme.snapX(width / 2)
                    y: stage.centerY - 3 * Theme.cellHeight
                    text: waiting + (waiting !== "" && playing !== "" ? "   " : "") + playing
                    color: Theme.inkDim
                }

                Box {
                    x: stage.centerX - Theme.snapX(panelWidth / 2)
                    y: stage.centerY - Theme.cellHeight
                    columns: 44
                    rows: 3
                    title: "locked"
                    titleColor: lock.refused ? Theme.alert : Theme.ink
                    footer: "↵ unlock  esc clear"

                    // The password field: a prompt, one dot per character,
                    // a block cursor.
                    Row {
                        Label {
                            text: "› "
                            color: Theme.accent
                        }

                        Label {
                            text: "•".repeat(lock.typed.length)
                            color: Theme.ink
                        }

                        Label {
                            text: "█"
                            color: Theme.accent
                        }
                    }

                    // What the password check has to say.
                    Label {
                        y: Theme.cellHeight
                        text: {
                            if (passwordCheck.active)
                                return "checking";
                            if (lock.refused)
                                return "wrong password";
                            if (lock.shell.capsLock)
                                return "caps lock is on";
                            if (lock.practice)
                                return "practice: unlocks by itself in a minute";
                            return "type your password";
                        }
                        color: lock.refused || lock.shell.capsLock ? Theme.alert : Theme.inkDim
                    }

                    // The fingerprint reader, while it is waiting.
                    Label {
                        y: 2 * Theme.cellHeight
                        visible: lock.fingerWanted
                        text: lock.fingerRefused ? "fingerprint not recognised, try again" : "or touch the fingerprint reader"
                        color: lock.fingerRefused ? Theme.alert : Theme.inkDim
                    }
                }

                // The battery, at the foot of the screen.
                Label {
                    x: stage.centerX - Theme.snapX(width / 2)
                    y: Theme.snapY(parent.height - 3 * Theme.cellHeight)
                    visible: lock.shell.batteryPresent
                    text: "battery " + Math.round(lock.shell.battery * 100) + "%" + (stage.batteryLow ? " !  plug in soon" : "")
                    color: stage.batteryLow ? Theme.alert : Theme.inkDim
                }
            }
        }
    }

    // --- The curtain ---
    // A sheet in the lock's colour over every screen. It is drawn solid at
    // the moment the lock lets go, and dithers away to show the desktop.
    property real curtain: 0

    NumberAnimation {
        id: curtainFade

        target: lock
        property: "curtain"
        from: 1
        to: 0
        duration: 2 * Theme.wipeMs
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            visible: lock.curtain > 0
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

            Rectangle {
                anchors.fill: parent
                color: Theme.slab
                layer.enabled: lock.curtain < 1
                layer.effect: DitherFade {
                    amount: lock.curtain
                    dotSize: 2 * Theme.dotSize
                }
            }
        }
    }
}
