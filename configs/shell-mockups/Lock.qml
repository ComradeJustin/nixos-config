import QtQuick
import Quickshell
import Quickshell.Wayland

// What the lock screen looks like: the whole screen in the background
// colour, the clock, how many notifications are waiting (not what they
// say) and what is playing, and a panel with a password field. A low
// battery is called out at the foot of the screen.
//
// This is a picture of a lock screen, not a lock: it does not use the
// session-lock protocol and it checks nothing. Enter with something typed
// closes it; enter with nothing typed shows the "wrong password" state.
// Tab steps the fingerprint reader through waiting, reading and not
// recognised. It only counts the keys pressed and never keeps what was typed.
PanelWindow {
    id: lock

    // The shell root (shell.qml).
    required property var shell

    // How many characters have been typed.
    property int typedCount: 0
    // Whether the last attempt was turned down.
    property bool refused: false

    // 0 = nothing showing, 1 = the whole screen covered.
    property real shown: shell.lockShown ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    // Stay mapped until the screen has dithered back.
    visible: shell.lockShown || shown > 0
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
    WlrLayershell.keyboardFocus: shell.lockShown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible) {
            lock.typedCount = 0;
            lock.refused = false;
            lock.shell.fingerprintStep = 0;
            stage.forceActiveFocus();
        }
    }

    Item {
        id: stage

        readonly property real centerX: Theme.snapX(width / 2)
        readonly property real centerY: Theme.snapY(height / 2)
        readonly property string timeText: Qt.formatDateTime(lock.shell.now, "hh:mm")
        readonly property string dateText: Qt.formatDateTime(lock.shell.now, "dddd d MMMM")

        anchors.fill: parent
        focus: true
        // The whole screen dithers in and out, in coarse dots like the
        // dimming behind the ring.
        layer.enabled: lock.shown < 1
        layer.effect: DitherFade {
            amount: lock.shown
            dotSize: 2 * Theme.dotSize
        }

        Keys.onPressed: event => {
            event.accepted = true;
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (lock.typedCount === 0)
                    lock.refused = true;
                else
                    lock.shell.lockShown = false;
            } else if (event.key === Qt.Key_Escape) {
                lock.typedCount = 0;
                lock.refused = false;
            } else if (event.key === Qt.Key_Tab) {
                lock.shell.fingerprintStep = (lock.shell.fingerprintStep + 1) % 3;
            } else if (event.key === Qt.Key_Backspace) {
                lock.typedCount = Math.max(0, lock.typedCount - 1);
            } else if (event.text.length === 1 && event.text >= " ") {
                lock.typedCount += 1;
                lock.refused = false;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.slab
        }

        // The time at four times size, the date under it.
        Label {
            x: stage.centerX - Theme.snapX(width / 2)
            y: stage.centerY - 8 * Theme.cellHeight
            text: stage.timeText
            scaleFactor: 4
            color: Theme.ink
        }

        Label {
            x: stage.centerX - Theme.snapX(width / 2)
            y: stage.centerY - 4 * Theme.cellHeight
            text: stage.dateText
            color: Theme.inkDim
            smallCaps: true
        }

        // How many notifications are waiting, and the playing track.
        Label {
            x: stage.centerX - Theme.snapX(width / 2)
            y: stage.centerY - 3 * Theme.cellHeight
            text: (lock.shell.unreadCount > 0 ? "\uf0f3 " + lock.shell.unreadCount + " waiting   " : "") + "♪ Shelter"
            color: Theme.inkDim
        }

        Box {
            id: panel

            x: stage.centerX - Theme.snapX(panelWidth / 2)
            y: stage.centerY - Theme.cellHeight
            columns: 40
            rows: 3
            title: "locked"
            titleColor: lock.refused ? Theme.alert : Theme.ink
            footer: "↵ unlock  esc clear  tab finger"

            // The password field: a prompt, one dot per character, a block cursor.
            Row {
                Label {
                    text: "› "
                    color: Theme.accent
                }

                Label {
                    text: "•".repeat(lock.typedCount)
                    color: Theme.ink
                }

                Label {
                    text: "█"
                    color: Theme.accent
                }
            }

            Label {
                y: Theme.cellHeight
                text: {
                    if (lock.refused)
                        return "wrong password";
                    if (lock.shell.capsLock)
                        return "caps lock is on";
                    return "mockup: type anything, then enter";
                }
                color: lock.refused || lock.shell.capsLock ? Theme.alert : Theme.inkDim
            }

            // The fingerprint reader: waiting, reading, or not recognised.
            Row {
                y: 2 * Theme.cellHeight

                Spinner {
                    visible: lock.shell.fingerprintStep === 1
                }

                Label {
                    text: {
                        if (lock.shell.fingerprintStep === 1)
                            return " reading fingerprint";
                        if (lock.shell.fingerprintStep === 2)
                            return "fingerprint not recognised, try again";
                        return "or touch the fingerprint reader";
                    }
                    color: lock.shell.fingerprintStep === 2 ? Theme.alert : Theme.inkDim
                }
            }
        }

        // Who and what is locked, and the battery, at the foot of the screen.
        Label {
            x: stage.centerX - Theme.snapX(width / 2)
            y: Theme.snapY(parent.height - 3 * Theme.cellHeight)
            readonly property bool batteryLow: lock.shell.battery <= 0.2 && !lock.shell.charging

            text: "nixlaptop  ·  battery " + Math.round(lock.shell.battery * 100) + "%" + (batteryLow ? " !  plug in soon" : "")
            color: batteryLow ? Theme.alert : Theme.inkDim
        }
    }
}
