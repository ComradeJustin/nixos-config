import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick
import "../core" as Core

// LockContext — the non-visual "brain" of the lockscreen.
//
// This component owns everything the LockScreen needs to authenticate
// the user and drive session-control actions: the PAM state machine,
// the fingerprint-sensor occupier + readiness handshake, PAM service
// auto-detection, bubble state (info/error toast surface), and the
// power-action countdown.
//
// Why extract this from LockScreen.qml: the visual file had grown past
// 1500 lines and every new feature made the next feature harder to
// slot in. Splitting auth logic into its own component drops the
// visual file back under 1000 lines and means the logic can be
// reasoned about (and tested) independently of how it's drawn.
//
// API contract
// ------------
// The visual LockScreen instantiates this as `ctx` and:
//   1. Reads state via `ctx.statusText`, `ctx.passwordMode`, etc. —
//      bindings update automatically, no polling needed.
//   2. Calls mutator functions: `ctx.startAuth()`, `ctx.submitPassword()`,
//      `ctx.cancelAuth()`, `ctx.armPowerAction()`, etc.
//   3. Connects to signals to drive visual-only side effects:
//        - authSucceeded       → start the unlock animation
//        - fingerprintFailed   → run the fingerprint-glyph shake
//        - passwordFailed      → run the input-box shake + selectAll
//        - requestFocusInput   → force focus onto the password field
//        - clearInput          → empty the password field
//
// The separation is strict: LockContext NEVER reaches into the visual
// subtree (no `passInput.text`, no `fingerShake.start()`). Anything
// that touches the UI goes through a signal. This is what makes the
// split meaningful — you could swap LockScreen.qml for a completely
// different visual layout without rewriting a line of LockContext.
Item {
    id: ctx
    visible: false

    // ── Signals to the visual layer ──
    signal authSucceeded()
    signal fingerprintFailed()
    signal passwordFailed()
    signal requestFocusInput()
    signal clearInput()

    // ── Public state ──
    //
    // These are read-only by convention from the visual side. QML
    // doesn't enforce const on properties, but every mutation below
    // goes through a function, so external writes would just fight
    // the state machine and produce weird transitions.
    property string statusText: ""
    property bool showError: false
    property bool authDone: false
    property bool isAuthenticating: false
    property bool passwordMode: false
    property bool hasFingerprint: false
    property bool waitingForPassword: false

    // ── Bubble state ──
    // See showBubble() for semantics. kind ∈ {info, busy, error}.
    property string bubbleText: ""
    property string bubbleKind: "info"

    // ── Power action state ──
    property var powerService: Core.ServiceManager.power
    property string pendingPowerAction: ""
    property int powerCountdown: 0

    // ── Wake handling ──
    // External code (wake event source) bumps wakeSignal; we reset
    // to fingerprint mode on the tick.
    property int wakeSignal: 0
    onWakeSignalChanged: if (wakeSignal > 0 && hasFingerprint) resetToFingerprint()

    // ── PAM service config ──
    // Auto-detected by pamServiceDetect below; seeded with the
    // preferred NixOS-module value as a fallback for the first tick.
    property string pamConfig: "quickshell-bar"

    // ── Internal state ──
    // pendingPamStart: set by startAuth() in password-with-fingerprint
    // mode, cleared by either the SplitParser handshake on the
    // sensor occupier or the safety-fallback timer. See startAuth()
    // for the full race-condition rationale.
    property bool pendingPamStart: false

    // ══════════════════════════════════════════════════════
    // ── PAM session ──
    // ══════════════════════════════════════════════════════
    PamContext {
        id: pam
        config: ctx.pamConfig

        onPamMessage: {
            // Dispatch on PAM's own flags (responseRequired, isError)
            // rather than substring-matching human text. That way
            // locale changes and fprintd revisions don't break us.
            var needsResp = pam.responseRequired;
            var isErr = pam.messageIsError;
            var msg = "" + (pam.message || "");

            console.log("PAM msg='" + msg + "' needsResp=" + needsResp + " err=" + isErr);

            if (needsResp) {
                // PAM parked at the password prompt. With the sensor
                // occupier trick we reach this almost instantly.
                ctx.passwordMode = true;
                ctx.waitingForPassword = true;
                ctx.showError = false;
                ctx.isAuthenticating = false;
                ctx.statusText = "Enter password";
                ctx.hideBubble();
                ctx.requestFocusInput();
            } else if (isErr) {
                // PAM-supplied error text is always more accurate than
                // anything we'd guess — forward it directly.
                var errText = msg.length > 0 ? msg : "Authentication error";
                ctx.statusText = errText;
                ctx.showError = true;
                ctx.showBubble(errText, "error");
                if (!ctx.passwordMode) {
                    ctx.fingerprintFailed();
                    fingerErrorReset.start();
                }
            } else if (msg.length > 0 && !ctx.passwordMode) {
                // Informational message — mirror it through.
                ctx.statusText = msg;
                ctx.showError = false;
                ctx.showBubble(msg, "info");
            }
        }

        onCompleted: function(result) {
            console.log("PAM completed: result=" + result);
            ctx.isAuthenticating = false;
            ctx.waitingForPassword = false;
            if (ctx.authDone) return;

            if (result === 0) {
                ctx.authDone = true;
                ctx.statusText = "Welcome back";
                ctx.showError = false;
                ctx.showBubble("Welcome back", "info");
                // Release the fingerprint sensor and clear any pending
                // handshake state before handing off to the visual.
                ctx.pendingPamStart = false;
                sensorClaimTimeout.stop();
                occupyFingerprintSensor.running = false;
                ctx.authSucceeded();
            } else if (ctx.passwordMode) {
                let pamMsg = "" + (pam.message || "");
                let wrongText = pamMsg.length > 0 ? pamMsg : "Wrong password — try again";
                ctx.statusText = wrongText;
                ctx.showError = true;
                ctx.showBubble(wrongText, "error");
                ctx.passwordFailed();
                ctx.requestFocusInput();
                // Rebuild the PAM session so the next submit has
                // somewhere to go. Sensor is still occupied so we
                // land at the password prompt within a few ms.
                authRestart.delay = 300;
                authRestart.start();
            } else {
                ctx.statusText = "Fingerprint not recognized";
                ctx.showError = true;
                ctx.showBubble("Fingerprint not recognized", "error");
                ctx.fingerprintFailed();
                authRestart.delay = 500;
                authRestart.start();
            }
        }

        onError: function(err) {
            console.log("PAM system error: " + err);
            ctx.isAuthenticating = false;
            ctx.waitingForPassword = false;
            if (ctx.authDone) return;
            ctx.statusText = "Auth error — retrying";
            ctx.showError = true;
            ctx.showBubble("Auth error — retrying", "error");
            authRestart.delay = 500;
            authRestart.start();
        }
    }

    // ══════════════════════════════════════════════════════
    // ── Public API ──
    // ══════════════════════════════════════════════════════

    function startAuth() {
        ctx.showError = false;
        ctx.authDone = false;
        ctx.isAuthenticating = false;
        ctx.waitingForPassword = false;
        if (!ctx.hasFingerprint) ctx.passwordMode = true;

        if (!ctx.passwordMode) {
            // Fingerprint mode: release the sensor and start PAM.
            ctx.statusText = "Swipe fingerprint to unlock";
            occupyFingerprintSensor.running = false;
            ctx.pendingPamStart = false;
            sensorClaimTimeout.stop();
            if (pam.active) pam.abort();
            pam.start();
        } else if (ctx.hasFingerprint) {
            // Password mode on a host with a fingerprint reader.
            // Two-phase start: spawn fprintd-verify as the occupier,
            // wait for its "Verify started!" line via the SplitParser
            // below, THEN call pam.start() so pam_fprintd fails fast
            // with ClaimDevice.AlreadyInUse and falls through to
            // pam_unix → password prompt.
            ctx.statusText = "Enter password";
            ctx.requestFocusInput();
            if (pam.active) pam.abort();
            ctx.pendingPamStart = true;
            // Toggle running false→true to guarantee a fresh spawn
            // even if a stale occupier is still around.
            occupyFingerprintSensor.running = false;
            occupyFingerprintSensor.running = true;
            sensorClaimTimeout.restart();
        } else {
            // Password mode, no fingerprint hardware.
            ctx.statusText = "Enter password";
            ctx.requestFocusInput();
            ctx.pendingPamStart = false;
            sensorClaimTimeout.stop();
            if (pam.active) pam.abort();
            pam.start();
        }
    }

    function resetToFingerprint() {
        if (!ctx.hasFingerprint) return;
        ctx.passwordMode = false;
        ctx.waitingForPassword = false;
        ctx.pendingPamStart = false;
        sensorClaimTimeout.stop();
        ctx.clearInput();
        ctx.statusText = "Swipe fingerprint to unlock";
        ctx.showError = false;
        // Release the sensor so fprintd can re-initialize after the
        // suspend/wake cycle without fighting our occupier process.
        occupyFingerprintSensor.running = false;
        authRestart.delay = 1000;
        authRestart.start();
    }

    function submitPassword(pw) {
        if (ctx.isAuthenticating) return;
        if (!pw || pw.length === 0) return;

        ctx.showError = false;
        ctx.isAuthenticating = true;

        if (pam.active && ctx.waitingForPassword) {
            // Common path: PAM is parked at the password prompt and
            // ready for respond() directly.
            ctx.statusText = "Authenticating...";
            ctx.showBubble("Authenticating…", "busy");
            ctx.waitingForPassword = false;
            pam.respond(pw);
        } else {
            // Rare path: PAM isn't ready yet. Restart it and the
            // user can press Enter again when it comes up.
            ctx.statusText = "Authenticating...";
            ctx.showBubble("Authenticating…", "busy");
            if (pam.active) pam.abort();
            pamDelay.delay = 80;
            pamDelay.start();
        }
    }

    function cancelAuth() {
        if (ctx.authDone) return;
        ctx.clearInput();
        ctx.showError = false;
        ctx.isAuthenticating = false;
        ctx.waitingForPassword = false;
        if (ctx.hasFingerprint) {
            // Return to fingerprint mode and release the occupier.
            ctx.passwordMode = false;
            ctx.pendingPamStart = false;
            sensorClaimTimeout.stop();
            if (pam.active) pam.abort();
            occupyFingerprintSensor.running = false;
            ctx.statusText = "Swipe fingerprint to unlock";
            authRestart.delay = 100;
            authRestart.start();
        } else {
            ctx.statusText = "Enter password";
        }
    }

    // ── Bubble API ──
    function showBubble(text, kind) {
        ctx.bubbleText = text;
        ctx.bubbleKind = kind;
        if (kind !== "error") bubbleDismiss.restart();
        else bubbleDismiss.stop();
    }
    function hideBubble() {
        ctx.bubbleText = "";
        bubbleDismiss.stop();
    }

    // ── Power action API ──
    function armPowerAction(action) {
        if (ctx.pendingPowerAction === action) {
            // Second click on the same action fires immediately.
            executePowerAction();
            return;
        }
        ctx.pendingPowerAction = action;
        ctx.powerCountdown = 5;
        powerCountdownTimer.restart();
    }
    function executePowerAction() {
        var action = ctx.pendingPowerAction;
        powerCountdownTimer.stop();
        ctx.pendingPowerAction = "";
        ctx.powerCountdown = 0;
        if (!ctx.powerService) return;
        if (action === "suspend")       ctx.powerService.suspend();
        else if (action === "reboot")   ctx.powerService.reboot();
        else if (action === "shutdown") ctx.powerService.shutdown();
    }
    function cancelPowerAction() {
        powerCountdownTimer.stop();
        ctx.pendingPowerAction = "";
        ctx.powerCountdown = 0;
    }

    // ══════════════════════════════════════════════════════
    // ── Processes and Timers ──
    // ══════════════════════════════════════════════════════

    // Detect if fprintd is available and has enrolled fingerprints.
    Process {
        id: fprintDetect
        command: ["bash", "-c", "command -v fprintd-list >/dev/null 2>&1 && fprintd-list \"$USER\" 2>/dev/null | grep -qP '^\\s+-\\s+#\\d+'"]
        running: true
        onExited: function(code) {
            ctx.hasFingerprint = (code === 0);
            if (!ctx.hasFingerprint) ctx.passwordMode = true;
            pamDelay.delay = 150;
            pamDelay.start();
        }
    }

    // PAM service auto-detect. Probes /etc/pam.d in priority order
    // so the lockscreen works on hosts without our NixOS module.
    Process {
        id: pamServiceDetect
        running: true
        command: ["sh", "-c",
            "for s in quickshell-bar login system-auth common-auth; do " +
            "  if [ -f /etc/pam.d/$s ]; then echo $s; exit 0; fi; " +
            "done; echo login"]
        stdout: StdioCollector {
            onStreamFinished: {
                let svc = ("" + text).trim();
                if (svc.length > 0) {
                    ctx.pamConfig = svc;
                    console.log("PAM service auto-detected: " + svc);
                }
            }
        }
    }

    // Fingerprint sensor occupier. See startAuth() and the top-of-file
    // comment in the old LockScreen.qml for the full race-condition
    // rationale — short version: we spawn fprintd-verify to claim the
    // sensor exclusively so pam_fprintd fails fast, then call
    // pam.start() only after we see "Verify started!" on the
    // occupier's stdout (the explicit handshake signal).
    Process {
        id: occupyFingerprintSensor
        command: ["sh", "-c", "exec fprintd-verify 2>&1"]
        stdout: SplitParser {
            onRead: function(data) {
                console.log("fprintd-verify: " + data);
                if (data.indexOf("Verify started") !== -1) {
                    if (ctx.pendingPamStart) {
                        ctx.pendingPamStart = false;
                        sensorClaimTimeout.stop();
                        console.log("Sensor claimed by occupier, restarting PAM");
                        pam.start();
                    }
                }
            }
        }
    }

    // Safety fallback for the sensor-claim handshake. If the stdout
    // line never arrives (unexpected fprintd version / locale), we
    // start PAM anyway after 1s so the user isn't stuck.
    Timer {
        id: sensorClaimTimeout
        interval: 1000
        onTriggered: {
            if (ctx.pendingPamStart) {
                ctx.pendingPamStart = false;
                console.log("fprintd-verify claim handshake timed out, starting PAM anyway");
                pam.start();
            }
        }
    }

    // Resets showError back off 800ms after a fingerprint failure so
    // the glyph stops rendering in critical-red while the user is
    // still trying again.
    Timer {
        id: fingerErrorReset
        interval: 800
        onTriggered: {
            ctx.showError = false;
            if (!ctx.passwordMode) ctx.statusText = "Swipe fingerprint to unlock";
        }
    }

    // Generic "start PAM after a short delay" timer. Used by
    // fprintDetect's onExited (initial boot) and submitPassword's
    // rare path (PAM wasn't ready when user pressed Enter).
    Timer {
        id: pamDelay
        property int delay: 150
        interval: delay
        onTriggered: pam.start()
    }

    // Generic "run startAuth() after a short delay" timer. Used by
    // the onCompleted failure paths to rebuild the session and by
    // resetToFingerprint.
    Timer {
        id: authRestart
        property int delay: 500
        interval: delay
        onTriggered: ctx.startAuth()
    }

    // Info/busy bubbles auto-dismiss after 3s. Errors persist until
    // the next PAM event explicitly overwrites them.
    Timer {
        id: bubbleDismiss
        interval: 3000
        onTriggered: {
            if (ctx.bubbleKind !== "error") ctx.bubbleText = "";
        }
    }

    // Power action countdown: 1Hz tick while an action is armed.
    Timer {
        id: powerCountdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (ctx.pendingPowerAction === "") {
                powerCountdownTimer.stop();
                return;
            }
            ctx.powerCountdown -= 1;
            if (ctx.powerCountdown <= 0) ctx.executePowerAction();
        }
    }
}
