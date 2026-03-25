import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".." as Root

Item {
    id: lock
    anchors.fill: parent

    // Theme is now a singleton - access via Root.Theme.propertyName

    signal unlocked()

    property string statusText: ""
    property bool showError: false
    property bool authDone: false
    property bool isAuthenticating: false
    property bool passwordMode: false
    property var playerService: null
    property string pendingPassword: ""
    property int wakeSignal: 0
    onWakeSignalChanged: if (wakeSignal > 0) resetToFingerprint()

    PamContext {
        id: pam
        config: "quickshell-bar"

        onPamMessage: {
            var msg = "" + (pam.message || "");
            var needsResponse = pam.responseRequired;

            console.log("PAM msg='" + msg + "' needsResp=" + needsResponse);

            if (needsResponse) {
                lock.showError = false;

                if (lock.pendingPassword.length > 0) {
                    var pw = lock.pendingPassword;
                    lock.pendingPassword = "";
                    lock.statusText = "Authenticating...";
                    lock.isAuthenticating = true;
                    lock.passwordMode = true;
                    pam.respond(pw);
                } else {
                    // PAM moved past fingerprint to password phase
                    lock.passwordMode = true;
                    lock.isAuthenticating = false;
                    lock.statusText = "Enter password";
                    focusTimer.start();
                }
            } else if (!lock.passwordMode && msg.length > 0) {
                var lower = msg.toLowerCase();
                if (lower.indexOf("no-match") !== -1 || lower.indexOf("no match") !== -1
                    || lower.indexOf("not match") !== -1 || lower.indexOf("verify-no-match") !== -1
                    || lower.indexOf("failed") !== -1 || lower.indexOf("mismatch") !== -1) {
                    lock.statusText = "Fingerprint not recognized";
                    lock.showError = true;
                    fingerShake.start();
                    fingerErrorReset.start();
                } else if (lower.indexOf("finger") !== -1 || lower.indexOf("swipe") !== -1
                           || lower.indexOf("place") !== -1 || lower.indexOf("scan") !== -1) {
                    lock.statusText = "Swipe fingerprint to unlock";
                    lock.showError = false;
                }
            }
        }

        onCompleted: function(result) {
            console.log("PAM completed: result=" + result);
            lock.isAuthenticating = false;
            if (lock.authDone) return;

            if (result === 0) {
                lock.authDone = true;
                lock.statusText = "Welcome back";
                lock.showError = false;
                unlockAnim.start();
            } else {
                if (lock.pendingPassword.length > 0) {
                    // Queued password — restart PAM to reach password prompt
                    lock.statusText = "Authenticating...";
                    lock.showError = false;
                    lock.isAuthenticating = true;
                    pamRestartDelay.start();
                } else if (lock.passwordMode) {
                    lock.statusText = "Wrong password — try again";
                    lock.showError = true;
                    pwRestart.start();
                } else {
                    lock.statusText = "Fingerprint not recognized";
                    lock.showError = true;
                    fingerShake.start();
                    fingerRestart.start();
                }
            }
        }

        onError: function(err) {
            console.log("PAM system error: " + err);
            lock.isAuthenticating = false;
            if (lock.authDone) return;
            lock.statusText = "Auth error — retrying";
            lock.showError = true;
            fingerRestart.start();
        }
    }

    function startAuth() {
        lock.showError = false;
        lock.authDone = false;
        lock.isAuthenticating = false;
        if (!lock.passwordMode) {
            lock.statusText = "Swipe fingerprint to unlock";
        } else {
            lock.statusText = "Enter password";
            passInput.text = "";
            focusTimer.start();
        }
        if (pam.active) pam.abort();
        pam.start();
    }

    function resetToFingerprint() {
        lock.passwordMode = false;
        lock.pendingPassword = "";
        passInput.text = "";
        lock.statusText = "Swipe fingerprint to unlock";
        lock.showError = false;
        // Give fprintd time to reinitialize after wake
        fprintdWakeDelay.start();
    }

    Timer {
        id: fprintdWakeDelay
        interval: 1000
        onTriggered: startAuth()
    }

    function submitPassword() {
        if (lock.isAuthenticating) return;

        // Cancel any pending restart timer
        pwRestart.stop();

        var pw = passInput.text;
        passInput.text = "";
        if (pw.length === 0) return;

        lock.showError = false;
        lock.isAuthenticating = true;

        if (pam.active && pam.responseRequired) {
            // PAM is ready for password, submit immediately
            lock.statusText = "Authenticating...";
            pam.respond(pw);
        } else if (pam.active) {
            // PAM is active but in fingerprint phase - queue password and wait
            lock.statusText = "Tap fingerprint to continue...";
            lock.pendingPassword = pw;
            // Don't abort - wait for PAM to move to password phase
        } else {
            // PAM not active, start it with queued password
            lock.statusText = "Authenticating...";
            lock.pendingPassword = pw;
            pamRestartDelay.start();
        }
    }

    Component.onCompleted: {
        // Small delay to ensure PAM is ready before prompting
        pamStartupDelay.start();
    }

    // ── Timers ──
    Timer { id: focusTimer; interval: 50; onTriggered: passInput.forceActiveFocus() }
    Timer { id: errorReset; interval: 1500; onTriggered: lock.showError = false }
    Timer { id: pamStartupDelay; interval: 150; onTriggered: startAuth() }

    Timer {
        id: fingerErrorReset
        interval: 800
        onTriggered: {
            lock.showError = false;
            if (!lock.passwordMode) lock.statusText = "Swipe fingerprint to unlock";
        }
    }

    Timer {
        id: fingerRestart
        interval: 500
        onTriggered: lock.startAuth()
    }

    Timer {
        id: pwRestart
        interval: 1500
        onTriggered: {
            lock.showError = false;
            lock.authDone = false;
            lock.isAuthenticating = false;
            lock.statusText = "Enter password";
            // Don't clear passInput.text - preserve what user typed
            focusTimer.start();

            // Only restart PAM if no password is pending
            if (lock.pendingPassword.length === 0) {
                if (pam.active) pam.abort();
                pamRestartDelay.start();
            }
        }
    }

    Timer {
        id: pamRestartDelay
        interval: 100
        onTriggered: pam.start()
    }

    // ══════════════════════════════════
    // ── Visual ──
    // ══════════════════════════════════
    Item {
        id: lockVisual
        anchors.fill: parent

        // Background image
        Image {
            id: lockBgImage
            anchors.fill: parent
            source: "file://" + Root.Theme.lockBackground
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
        }

        // Fallback solid color
        Rectangle {
            anchors.fill: parent
            color: Root.Theme.base00
            visible: parent.children[0].status !== Image.Ready
        }

        // Dim overlay for readability
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.2)
        }

        // Content wrapper - this gets animated, not the background
        Item {
            id: lockContent
            anchors.fill: parent
            scale: 1
            opacity: 1

            // Unlock animation: fade out + scale up content only
            ParallelAnimation {
                id: unlockAnim

                NumberAnimation {
                    target: lockContent
                    property: "opacity"
                    to: 0
                    duration: 350
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: lockContent
                    property: "scale"
                    to: 1.03
                    duration: 350
                    easing.type: Easing.OutCubic
                }

                onFinished: lock.unlocked()
            }

            // User icon
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.08
                width: 80
                height: 80
                radius: 40
                color: Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1)

                Text {
                    anchors.centerIn: parent
                    text: Root.Theme.iconUser
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: 40 }
                }
            }

            // Clock
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.22
                spacing: 4

            Text {
                id: clockText
                anchors.horizontalCenter: parent.horizontalCenter
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: 72; bold: true }
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
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 18 }
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

        // Login prompt - with backdrop for readability
        Rectangle {
            id: promptBackdrop
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.08
            width: centerColumn.width + 48
            height: centerColumn.height + 40
            radius: 20
            color: Qt.rgba(Root.Theme.base00.r, Root.Theme.base00.g, Root.Theme.base00.b, 0.75)

            Column {
                id: centerColumn
                anchors.centerIn: parent
                spacing: 16
                width: 320

                // Fingerprint icon — only before password mode
                Text {
                    id: fingerIcon
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰈷"
                    color: lock.showError ? Root.Theme.textCritical : Root.Theme.textAccent
                    font { family: Root.Theme.fontFamily; pixelSize: 64 }
                    visible: !lock.passwordMode

                transform: Translate { id: fingerShakeTranslate; x: 0 }

                SequentialAnimation {
                    id: fingerShake
                    NumberAnimation { target: fingerShakeTranslate; property: "x"; to: -12; duration: 50 }
                    NumberAnimation { target: fingerShakeTranslate; property: "x"; to: 12; duration: 50 }
                    NumberAnimation { target: fingerShakeTranslate; property: "x"; to: -8; duration: 50 }
                    NumberAnimation { target: fingerShakeTranslate; property: "x"; to: 8; duration: 50 }
                    NumberAnimation { target: fingerShakeTranslate; property: "x"; to: -4; duration: 50 }
                    NumberAnimation { target: fingerShakeTranslate; property: "x"; to: 0; duration: 50 }
                }

                SequentialAnimation on opacity {
                    running: !lock.passwordMode && !lock.showError
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            // Lock icon — password mode
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰌾"
                color: lock.showError ? Root.Theme.textCritical : Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 36 }
                visible: lock.passwordMode
            }

            // Status
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: lock.statusText
                color: lock.showError ? Root.Theme.textCritical : Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 14 }
            }

            // Switch to password option
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Use password"
                color: Root.Theme.textAccent
                font { family: Root.Theme.fontFamily; pixelSize: 12; underline: switchMouse.containsMouse }
                visible: !lock.passwordMode
                opacity: 0.8

                MouseArea {
                    id: switchMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        lock.passwordMode = true;
                        lock.statusText = "Enter password";
                        lock.isAuthenticating = false;
                        focusTimer.start();
                    }
                }
            }

            // Password input — always visible in password mode
            Rectangle {
                width: parent.width
                height: 44
                radius: 22
                visible: lock.passwordMode
                color: Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.08)
                border.color: passInput.activeFocus
                    ? Root.Theme.textAccent
                    : lock.showError
                      ? Root.Theme.textCritical
                      : Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.15)
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
                        color: lock.isAuthenticating ? Root.Theme.textDimmed : Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: 14 }
                        echoMode: TextInput.Password
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        readOnly: lock.isAuthenticating

                        Text {
                            anchors.fill: parent
                            text: lock.isAuthenticating ? "" : "Password"
                            color: Root.Theme.textDimmed
                            font: parent.font
                            visible: parent.text.length === 0
                            verticalAlignment: Text.AlignVCenter
                        }

                        Keys.onReturnPressed: lock.submitPassword()
                        Keys.onEnterPressed: lock.submitPassword()
                    }

                    Text {
                        text: "→"
                        color: passInput.text.length > 0 ? Root.Theme.textAccent : Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: 18; bold: true }
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

        // ── Music display above prompt ──
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: promptBackdrop.top
            anchors.bottomMargin: 20
            spacing: 12
            visible: lock.playerService && lock.playerService.hasMedia

            // Album art
            Rectangle {
                width: 48
                height: 48
                radius: 8
                color: Root.Theme.base01
                clip: true

                Image {
                    id: lockAlbumArt
                    anchors.fill: parent
                    source: lock.playerService ? lock.playerService.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: Root.Theme.iconMusic
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: 20 }
                    visible: lockAlbumArt.status !== Image.Ready
                }
            }

            // Track info
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: lock.playerService ? lock.playerService.trackTitle : ""
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: 14; bold: true }
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 250)
                }

                Text {
                    text: lock.playerService ? lock.playerService.trackArtist : ""
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: 12 }
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 250)
                    visible: text.length > 0
                }
            }

            // Play/pause indicator
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (lock.playerService && lock.playerService.isPlaying) ? Root.Theme.iconMediaPause : Root.Theme.iconMediaPlay
                color: Root.Theme.textAccent
                font { family: Root.Theme.fontFamily; pixelSize: 20 }
            }
        }
    } // lockContent Item
    }
}
