import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".." as Root

Item {
    id: lock
    anchors.fill: parent

    Root.Theme { id: theme }

    signal unlocked()

    property string statusText: "Authenticating..."
    property bool showError: false
    property bool showPassword: false

    // ── PAM handles everything: fprintd first, then password fallback ──
    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            var msg = "" + (pam.message || "");
            var needsResponse = pam.responseRequired;
            var isErr = pam.messageIsError;

            console.log("PAM: msg='" + msg + "' responseRequired=" + needsResponse + " isError=" + isErr + " active=" + pam.active);

            if (needsResponse) {
                lock.showPassword = true;
                lock.showError = false;
                lock.statusText = "Enter password";
                passInput.text = "";
                focusTimer.start();
            } else {
                if (msg.length > 0) {
                    if (msg.indexOf("finger") !== -1 || msg.indexOf("Finger") !== -1 || msg.indexOf("swipe") !== -1 || msg.indexOf("Place") !== -1) {
                        lock.statusText = "Swipe fingerprint to unlock";
                        lock.showPassword = false;
                    } else if (isErr) {
                        lock.statusText = msg;
                        lock.showError = true;
                        errorResetTimer.start();
                    } else {
                        lock.statusText = msg;
                    }
                }
            }
        }

        // PamResult may not have .success — dump everything to find the right property
        onCompleted: function(result) {
            console.log("PAM completed: result=" + result + " type=" + typeof result);
            try { console.log("PAM result keys: " + JSON.stringify(result)); } catch(e) {}
            try { console.log("PAM result.success=" + result.success); } catch(e) {}
            try { console.log("PAM result.type=" + result.type); } catch(e) {}

            // Try multiple ways to detect success
            var ok = false;
            if (result === true) ok = true;
            else if (result && result.success === true) ok = true;
            else if (result && result.type === 0) ok = true;  // PamResult enum?
            else if (result && ("" + result).indexOf("success") !== -1) ok = true;

            console.log("PAM auth ok=" + ok);

            if (ok) {
                lock.statusText = "Welcome back";
                lock.showError = false;
                lock.showPassword = false;
                unlockTimer.start();
            } else {
                lock.statusText = "Authentication failed";
                lock.showError = true;
                lock.showPassword = false;
                passInput.text = "";
                restartTimer.start();
            }
        }

        onError: function(err) {
            console.log("PAM error: " + err + " type=" + typeof err);
            try { console.log("PAM error detail: " + JSON.stringify(err)); } catch(e) {}
            lock.statusText = "Authentication error";
            lock.showError = true;
            lock.showPassword = false;
            restartTimer.start();
        }
    }

    // Delay focus to ensure TextInput is visible first
    Timer {
        id: focusTimer
        interval: 50
        onTriggered: passInput.forceActiveFocus()
    }

    function startAuth() {
        lock.showError = false;
        lock.showPassword = false;
        lock.statusText = "Swipe fingerprint to unlock";
        if (pam.active) pam.abort();
        pam.start();
    }

    function submitPassword() {
        var pw = passInput.text;
        passInput.text = "";
        if (pw.length === 0) return;

        console.log("submitPassword: active=" + pam.active + " responseRequired=" + pam.responseRequired + " pwLen=" + pw.length);

        if (pam.active && pam.responseRequired) {
            lock.statusText = "Authenticating...";
            lock.showError = false;
            pam.respond(pw);
        } else {
            console.log("submitPassword: PAM not ready! active=" + pam.active + " responseRequired=" + pam.responseRequired);
            lock.statusText = "Not ready — try again";
            lock.showError = true;
            errorResetTimer.start();
        }
    }

    Component.onCompleted: startAuth()

    Timer {
        id: unlockTimer
        interval: 200
        onTriggered: lock.unlocked()
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: lock.startAuth()
    }

    Timer {
        id: errorResetTimer
        interval: 1500
        onTriggered: {
            lock.showError = false;
        }
    }

    // ══════════════════════════════════
    // ── Visual layout ──
    // ══════════════════════════════════
    Rectangle {
        anchors.fill: parent
        color: theme.base00

        // Clock
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.2
            spacing: 4

            Text {
                id: clockText
                anchors.horizontalCenter: parent.horizontalCenter
                color: theme.textPrimary
                font { family: theme.fontFamily; pixelSize: 72; bold: true }
                property int tick: 0
                text: {
                    void(tick);
                    var d = new Date();
                    var h = d.getHours();
                    var m = d.getMinutes();
                    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
                }
            }

            Text {
                id: dateText
                anchors.horizontalCenter: parent.horizontalCenter
                color: theme.textDimmed
                font { family: theme.fontFamily; pixelSize: 18 }
                property int tick: 0
                text: {
                    void(tick);
                    var d = new Date();
                    var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
                    var months = ["January", "February", "March", "April", "May", "June",
                                  "July", "August", "September", "October", "November", "December"];
                    return days[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate();
                }
            }
        }

        Timer {
            interval: 1000; repeat: true; running: true
            onTriggered: { clockText.tick++; dateText.tick++ }
        }

        // Center content
        Column {
            anchors.centerIn: parent
            spacing: 16
            width: 320

            // Fingerprint icon (visible when waiting for finger)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰈷"
                color: lock.showError ? theme.textCritical : theme.textAccent
                font { family: theme.fontFamily; pixelSize: 64 }
                visible: !lock.showPassword

                SequentialAnimation on opacity {
                    running: !lock.showPassword && !lock.showError
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            // Lock icon (visible in password mode)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰌾"
                color: lock.showError ? theme.textCritical : theme.textDimmed
                font { family: theme.fontFamily; pixelSize: 36 }
                visible: lock.showPassword
            }

            // Status text
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: lock.statusText
                color: lock.showError ? theme.textCritical : theme.textDimmed
                font { family: theme.fontFamily; pixelSize: 14 }
            }

            // Password input (only visible when PAM asks for it)
            Rectangle {
                width: parent.width
                height: 44
                radius: 22
                visible: lock.showPassword
                color: Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.08)
                border.color: passInput.activeFocus
                    ? theme.textAccent
                    : lock.showError
                      ? theme.textCritical
                      : Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.15)
                border.width: 2

                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 8

                    TextInput {
                        id: passInput
                        Layout.fillWidth: true
                        color: theme.textPrimary
                        font { family: theme.fontFamily; pixelSize: 14 }
                        echoMode: TextInput.Password
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter

                        Text {
                            anchors.fill: parent
                            text: "Password"
                            color: theme.textDimmed
                            font: parent.font
                            visible: parent.text.length === 0
                            verticalAlignment: Text.AlignVCenter
                        }

                        Keys.onReturnPressed: lock.submitPassword()
                        Keys.onEnterPressed: lock.submitPassword()
                    }

                    Text {
                        text: "→"
                        color: passInput.text.length > 0 ? theme.textAccent : theme.textDimmed
                        font { family: theme.fontFamily; pixelSize: 18; bold: true }
                        visible: passInput.text.length > 0

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: lock.submitPassword()
                        }
                    }
                }
            }
        }
    }
}
