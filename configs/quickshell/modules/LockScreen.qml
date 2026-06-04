import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import ".." as Root
import "../components" as Components
import "../core" as Core

Item {
    id: lock
    anchors.fill: parent

    // Theme is now a singleton - access via Root.Theme.propertyName

    signal unlocked()

    // ══════════════════════════════════════════════════════
    // ── Non-visual state: LockContext ──
    // ══════════════════════════════════════════════════════
    //
    // All auth logic (PAM state machine, sensor occupier,
    // fingerprint detection, bubble state, power actions) lives in
    // LockContext.qml. This file is purely the visual layer —
    // everything data-related is read through `ctx.*`.
    //
    // Signals from the context drive visual-only side effects
    // (unlock animation, input shake, focus changes) so the context
    // never has to know the visual tree exists.
    LockContext {
        id: ctx
        onAuthSucceeded: unlockAnim.start()
        onFingerprintFailed: fingerShake.start()
        onPasswordFailed: {
            passShake.start();
            if (passInput.text.length > 0) passInput.selectAll();
        }
        onRequestFocusInput: focusTimer.start()
        onClearInput: passInput.text = ""
    }

    // Property aliases: keep the pre-refactor visual bindings
    // working unchanged. Each alias forwards to the corresponding
    // LockContext state, so `lock.passwordMode` still reads and
    // writes the same underlying value.
    property alias statusText: ctx.statusText
    property alias showError: ctx.showError
    property alias authDone: ctx.authDone
    property alias isAuthenticating: ctx.isAuthenticating
    property alias passwordMode: ctx.passwordMode
    property alias hasFingerprint: ctx.hasFingerprint
    property alias waitingForPassword: ctx.waitingForPassword
    property alias bubbleText: ctx.bubbleText
    property alias bubbleKind: ctx.bubbleKind
    property alias pendingPowerAction: ctx.pendingPowerAction
    property alias powerCountdown: ctx.powerCountdown
    property alias wakeSignal: ctx.wakeSignal
    property alias powerService: ctx.powerService

    // Visual-only state still belongs here.
    property var playerService: Core.ServiceManager.player

    // ── Caps Lock indicator state (#1) ──
    // Polled from /sys/class/leds/*::capslock/brightness via capsPoller
    // below. Only bound to a visible chip when passwordMode is active —
    // there's no point warning about caps lock while the user is just
    // swiping a finger.
    property bool capsLockOn: false

    // ── Password visibility toggle (#2) ──
    // Flipped by the eye-icon button in the password input row. Drives
    // passInput.echoMode between Password and Normal so the user can
    // verify a long/complex password without retyping.
    property bool passwordVisible: false

    // Note: auth state (PamContext, bubble, power actions, fingerprint
    // detection) all live in LockContext.qml now. See the `ctx` block
    // above for signal wiring and the alias list for the public
    // surface the visual tree below still reads from.

    // (PAM context, startAuth, submitPassword, cancelAuth,
    // resetToFingerprint, fprintDetect, pamServiceDetect,
    // occupyFingerprintSensor, sensorClaimTimeout, armPowerAction,
    // executePowerAction, cancelPowerAction — all moved to
    // modules/LockContext.qml as part of the #O refactor.)

    

    // ── Timers ──
    Timer { id: focusTimer; interval: 50; onTriggered: passInput.forceActiveFocus() }

    

    

    

    

    // ── Caps Lock polling (#1) ──
    //
    // We read /sys/class/leds/*::capslock/brightness via a one-shot
    // Process (cheaper than shelling a full command). The wildcard in
    // the path matches whatever input device the kernel gave the
    // keyboard (input0, input1, input3…) so this works across
    // machines. A 300ms polling timer is plenty snappy for a key that
    // a human toggles — we don't need keyboard-interrupt latency.
    //
    // Only runs while passwordMode is active: fingerprint mode doesn't
    // care about caps lock, and keeping the poller off at idle saves
    // a few spawns per second on the lockscreen's hot path.
    Process {
        id: capsCheck
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = ("" + text).trim();
                lock.capsLockOn = (v === "1");
            }
        }
    }
    Timer {
        id: capsPoller
        interval: 300
        repeat: true
        running: lock.passwordMode && !lock.authDone
        triggeredOnStart: true
        onTriggered: capsCheck.running = true
    }

    

    // ── Escape handler (#4) ──
    //
    // Shortcut (not Keys.onEscapePressed) because focus always lives on
    // passInput when the user is typing, and we want Escape to work
    // regardless of where focus is. The precedence is deliberate:
    //
    //   1. A running power countdown always wins — Escape cancels it.
    //      Otherwise the user can't back out of an accidental click.
    //   2. Otherwise Escape runs cancelAuth(), which empties the field
    //      and (on fingerprint-capable hosts) returns to fingerprint
    //      mode so the user can just swipe instead.
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: {
            if (ctx.pendingPowerAction !== "") {
                ctx.cancelPowerAction();
            } else {
                ctx.cancelAuth();
            }
        }
    }

    // ══════════════════════════════════
    // ── Visual ──
    // ══════════════════════════════════
    Item {
        id: lockVisual
        anchors.fill: parent

        // ── Parallax (#J) ──
        // Pointer-driven subtle translate for the blurred wallpaper. We
        // store a normalized offset in [-1, 1] per axis based on where
        // the cursor sits relative to the centre, then multiply by the
        // max offset (12px) in the Translate transform below. HoverHandler
        // is preferred over MouseArea here because it is non-intrusive:
        // it reports pointer position without intercepting clicks, so the
        // password field, transport buttons, and session controls still
        // receive their events unmolested.
        //
        // The parallax budget (12px) is well inside the 48px blur margin,
        // so we can never expose the fringe the negative-margin fix was
        // installed to hide. A Behavior on each translate axis smooths
        // the tracking so the wallpaper drifts rather than snaps.
        property real parallaxX: 0
        property real parallaxY: 0
        readonly property real parallaxMax: 12

        HoverHandler {
            id: parallaxHover
            onPointChanged: {
                if (!parallaxHover.hovered) return;
                let p = parallaxHover.point.position;
                let nx = (p.x / lockVisual.width) * 2 - 1;   // [-1, 1]
                let ny = (p.y / lockVisual.height) * 2 - 1;  // [-1, 1]
                // Negate so the wallpaper drifts AWAY from the cursor —
                // the classic "look into the scene" parallax feel rather
                // than the "background sticks to the cursor" feel.
                lockVisual.parallaxX = -nx * lockVisual.parallaxMax;
                lockVisual.parallaxY = -ny * lockVisual.parallaxMax;
            }
        }

        Behavior on parallaxX { NumberAnimation { duration: Root.Theme.animSlow; easing.type: Easing.OutCubic } }
        Behavior on parallaxY { NumberAnimation { duration: Root.Theme.animSlow; easing.type: Easing.OutCubic } }

        // ══════════════════════════════════════════════
        // ── Background wallpaper, blurred (#13) ──
        // ══════════════════════════════════════════════
        //
        // The wallpaper is rendered into its own layer so we can
        // feed it through a MultiEffect shader pass that blurs it
        // in-place (hardware-accelerated on the GPU, no CPU cost).
        //
        // Why blur the wallpaper: a sharp, high-contrast photo
        // behind a translucent prompt backdrop fights the text for
        // attention and leaves readability hostage to whichever
        // image the user happened to pick. A 32px Gaussian-ish
        // blur turns the wallpaper into an ambient wash that still
        // tells you "this is YOUR machine" (the colors are yours)
        // without fighting the foreground chrome.
        //
        // A tiny saturation bump (+0.15) prevents the blur from
        // looking muddy on low-contrast wallpapers — this is the
        // same "frosted-glass" trick PlayerCard uses for the album
        // art backdrop, kept consistent for visual cohesion.
        //
        // layer.smooth: true eliminates the stair-step aliasing
        // that otherwise appears around high-contrast edges when
        // the blurred FBO is sampled at non-integer coordinates.
        Image {
            id: lockBgImage
            // Oversize the image by the blur radius on every edge so
            // the MultiEffect blur kernel never reaches past the FBO
            // bounds into undefined territory. Without this, the
            // shader samples transparent/white pixels outside the
            // image rect and mixes them into the edges — producing
            // the classic "white fringe" artifact around a blurred
            // image.
            //
            // The math: we negative-margin by the same value as
            // `blurMax` (48px). That grows both the Image item AND
            // its layer FBO by 96px on each axis, so the 48px blur
            // radius always has real wallpaper pixels to sample.
            // PreserveAspectCrop absorbs the extra size by clipping
            // a tiny bit more off the wallpaper — visually identical
            // on anything but a pixel-peeping side-by-side diff.
            anchors.fill: parent
            anchors.margins: -48
            source: "file://" + Root.Theme.lockBackground
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            asynchronous: true
            cache: true
            // Parallax transform — we apply the translate at the item
            // level rather than baking it into the anchors so the FBO
            // for layer.effect stays a stable size (moving anchors
            // would force a re-allocation on every mouse event, which
            // is both wasteful and causes flickering in the blur
            // output).
            transform: Translate {
                x: lockVisual.parallaxX
                y: lockVisual.parallaxY
            }
            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
                // Belt-and-braces: also hint the effect to auto-pad
                // the FBO. In Qt 6.5+ this is the default, but
                // setting it explicitly makes the intent readable
                // and protects us if someone downgrades Qt later.
                autoPaddingEnabled: true
                blurEnabled: true
                blurMax: 48
                blur: 0.7
                saturation: 0.15
            }
        }

        // Fallback solid color
        Rectangle {
            anchors.fill: parent
            color: Root.Theme.base00
            visible: lockBgImage.status !== Image.Ready
        }

        // Dim overlay for readability. Slightly darker now that the
        // wallpaper is blurred rather than sharp — blur tends to
        // pull the average brightness UP (mixing dark details into
        // lighter regions), so we compensate by adding a bit more
        // scrim so the text keeps its contrast ratio against the
        // backdrop.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.3)
        }

        // Content wrapper - this gets animated, not the background.
        //
        // Initial values are the START of the entrance animation:
        // slightly smaller, fully transparent, and pushed down by the
        // entranceTranslate transform. entranceAnim (kicked off in
        // Component.onCompleted below) animates these back to the
        // resting state over ~450ms. This gives the lockscreen a
        // visible "assemble" moment on every engage instead of the
        // old snap-to-visible, which felt like a rendering glitch on
        // slow wake-from-suspend.
        Item {
            id: lockContent
            anchors.fill: parent
            scale: 0.97
            opacity: 0

            // Slide-up transform: start 24px below the final position
            // so the whole content "lifts" into place while fading in.
            // We use a Translate (additive to anchors) instead of
            // mutating y, because anchors.fill would immediately
            // overwrite any direct y assignment.
            transform: Translate { id: entranceTranslate; y: 24 }

            // Entrance animation: reverse of unlockAnim — fade in +
            // settle scale up to 1 + lift slide-translate to 0.
            // Kicked off unconditionally on component ready; there's
            // no state check because the lockscreen is a one-shot
            // surface (destroyed and re-created on every lock).
            ParallelAnimation {
                id: entranceAnim

                NumberAnimation {
                    target: lockContent
                    property: "opacity"
                    from: 0; to: 1
                    duration: 450
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: lockContent
                    property: "scale"
                    from: 0.97; to: 1
                    duration: 450
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: entranceTranslate
                    property: "y"
                    from: 24; to: 0
                    duration: 450
                    easing.type: Easing.OutCubic
                }
            }

            Component.onCompleted: entranceAnim.start()

            // Unlock animation: fade out + scale up content only.
            // NOTE: uses explicit `from: 1` on scale so it always
            // starts from the resting state even if the entrance was
            // interrupted mid-animation by a fast unlock.
            ParallelAnimation {
                id: unlockAnim

                NumberAnimation {
                    target: lockContent
                    property: "opacity"
                    from: 1; to: 0
                    duration: Root.Theme.anim.bounceDuration
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: lockContent
                    property: "scale"
                    from: 1; to: 1.03
                    duration: Root.Theme.anim.bounceDuration
                    easing.type: Easing.OutCubic
                }

                onFinished: lock.unlocked()
            }

            // ══════════════════════════════════════════════
            // ── Battery chip (top-right) — #5 ──
            // ══════════════════════════════════════════════
            //
            // Only visible on hosts that actually have a battery
            // (hasBattery guards laptop-vs-desktop). The chip colors
            // itself based on capacity: danger red under 20%, warm
            // orange under 40%, charging yellow while plugged in,
            // otherwise the dimmed neutral. Using Icons.batteryIcon()
            // instead of a locally-written ternary ladder keeps us
            // aligned with the Bar module's battery glyph so both
            // surfaces show the same level bucket.
            Rectangle {
                id: batteryChip
                visible: lock.powerService && lock.powerService.hasBattery
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Root.Theme.spacingXL
                anchors.rightMargin: Root.Theme.spacing2XL
                width: batteryRow.width + 20
                height: 32
                radius: 16
                color: Qt.rgba(Root.Theme.base00.r, Root.Theme.base00.g, Root.Theme.base00.b, 0.75)
                border.width: 1
                border.color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.2)

                readonly property int pct: lock.powerService ? lock.powerService.capacity : 0
                readonly property bool charging: lock.powerService ? lock.powerService.charging : false
                readonly property color tint: {
                    if (!lock.powerService) return Root.Theme.textDimmed;
                    if (charging) return Root.Theme.barBatteryCharge;
                    if (pct <= 20) return Root.Theme.barBatteryLow;
                    if (pct <= 40) return Root.Theme.accentWarm;
                    return Root.Theme.textPrimary;
                }

                Row {
                    id: batteryRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Root.Icons.batteryIcon(batteryChip.pct, batteryChip.charging)
                        color: batteryChip.tint
                        font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize3XL }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: batteryChip.pct + "%"
                        color: batteryChip.tint
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeL; bold: true }
                    }
                }
            }

            // User identity hero — shared ProfileCard in non-compact mode.
            // Same component the Control Center uses, so avatar/greeting/
            // hostname stay in lockstep between surfaces.
            Components.ProfileCard {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.06
                width: 320
                compact: false
            }

            // Clock
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.22
                spacing: Root.Theme.spacingXS

            Text {
                id: clockText
                anchors.horizontalCenter: parent.horizontalCenter
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontDisplay; pixelSize: Root.Theme.fontSizeHero; bold: true; features: ({ "tnum": 1 }) }
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
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize3XL }
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
                spacing: Root.Theme.spacingL
                width: 320

                // Fingerprint icon container (#K: breathing glow).
                //
                // Wrapping the Text in an Item lets us put a sibling
                // glow Rectangle BEHIND it. A bare Text in a Column
                // can't have a glow sibling because Column lays its
                // children out linearly — nothing can overlap. This
                // Item participates in Column as one unit; inside it
                // the glow and Text are free-anchored.
                //
                // The glow is a circle (Rectangle with radius=width/2)
                // slightly larger than the icon. Its opacity pulses
                // antiphase-ish with the icon's breath so the viewer
                // sees a soft "ember" behind the glyph — a visual cue
                // that the sensor is actively listening. When the user
                // swipes a bad print (`showError`), we recolor the
                // glow to red to match the icon's own error state.
                Item {
                    id: fingerIconWrap
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !lock.passwordMode
                    width: 120; height: 120

                    Rectangle {
                        id: fingerGlow
                        anchors.centerIn: parent
                        width: 110; height: 110
                        radius: width / 2
                        color: Qt.rgba(
                            (lock.showError ? Root.Theme.textCritical.r : Root.Theme.textAccent.r),
                            (lock.showError ? Root.Theme.textCritical.g : Root.Theme.textAccent.g),
                            (lock.showError ? Root.Theme.textCritical.b : Root.Theme.textAccent.b),
                            0.22)
                        opacity: 0.45
                        Behavior on color { ColorAnimation { duration: Root.Theme.anim.exitDuration } }

                        // Synced to the icon's 900ms breath. The icon
                        // starts bright (1.0) and animates TO 0.3 on
                        // the first tick — so the glow must start
                        // bright and animate TO its dim value on the
                        // first tick too. Same duration, same phase =
                        // one coherent "inhale / exhale" instead of
                        // two competing pulses.
                        SequentialAnimation on opacity {
                            running: !lock.passwordMode
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.15; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                        }

                        // Scale breath on the same 900ms cycle, also
                        // in phase with the icon: bright + large on
                        // the exhale, dim + small on the inhale.
                        SequentialAnimation on scale {
                            running: !lock.passwordMode
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.00; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.08; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        id: fingerIcon
                        anchors.centerIn: parent
                        text: "󰈷"
                        color: lock.showError ? Root.Theme.textCritical : Root.Theme.textAccent
                        font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.scaled(64) }

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
                }

            // Lock icon — password mode
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰌾"
                color: lock.showError ? Root.Theme.textCritical : Root.Theme.textDimmed
                font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.scaled(36) }
                visible: lock.passwordMode
            }

            // Stable mode hint. Before #6 this Text was the live
            // `statusText` sink, which meant every transient message
            // ("Authenticating…", "Wrong password", etc.) replaced the
            // baseline prompt and then had to be restored. Now the
            // bubble handles all transient feedback and this label
            // just states which mode you're in — calmer visually,
            // less flicker. Fades out when the bubble is visible so
            // the two surfaces don't compete for the user's eye.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: lock.passwordMode ? "Enter password" : "Swipe fingerprint to unlock"
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXL }
                opacity: lock.bubbleText.length > 0 ? 0.35 : 1.0
                Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.microDuration } }
            }

            // Switch to password option
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Use password"
                color: Root.Theme.textAccent
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM; underline: switchMouse.containsMouse }
                visible: !lock.passwordMode
                opacity: 0.8

                MouseArea {
                    id: switchMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        // Flip into password mode AND re-arm the PAM
                        // session. Just toggling passwordMode isn't
                        // enough: the current pam.start() is parked on
                        // fprintd waiting for a finger, and without
                        // calling startAuth() we never (a) spawn the
                        // fingerprint-sensor occupier and (b) abort +
                        // restart PAM so it lands at the password
                        // prompt. startAuth() handles both, reads
                        // `passwordMode` to pick its branch, and is
                        // the same entrypoint the initial load uses —
                        // so this click is now idempotent with the
                        // "password-only host" boot path.
                        lock.passwordMode = true;
                        ctx.startAuth();
                    }
                }
            }

            // Password input — always visible in password mode
            Rectangle {
                id: passwordBox
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

                Behavior on border.color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                // ── Wrong-password shake (#3) ──
                //
                // Six-step back-and-forth translate, ~300ms total. Same
                // shape as fingerShake but with a smaller amplitude
                // because the rectangle is much wider than the glyph
                // and a 12px jolt on a 320px input looks cartoonish.
                // Triggered from pam.onCompleted's failure branch.
                transform: Translate { id: passShakeTranslate; x: 0 }
                SequentialAnimation {
                    id: passShake
                    NumberAnimation { target: passShakeTranslate; property: "x"; to: -8; duration: 50 }
                    NumberAnimation { target: passShakeTranslate; property: "x"; to:  8; duration: 50 }
                    NumberAnimation { target: passShakeTranslate; property: "x"; to: -6; duration: 50 }
                    NumberAnimation { target: passShakeTranslate; property: "x"; to:  6; duration: 50 }
                    NumberAnimation { target: passShakeTranslate; property: "x"; to: -3; duration: 50 }
                    NumberAnimation { target: passShakeTranslate; property: "x"; to:  0; duration: 50 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Root.Theme.spacingL
                    anchors.rightMargin: Root.Theme.spacingL
                    spacing: Root.Theme.spacingS

                    TextInput {
                        id: passInput
                        Layout.fillWidth: true
                        color: lock.isAuthenticating ? Root.Theme.textDimmed : Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXL }
                        // Bound to the visibility toggle (#2). Default
                        // stays Password; flipping passwordVisible true
                        // switches to Normal so the user can verify a
                        // typed password without retyping it.
                        echoMode: lock.passwordVisible ? TextInput.Normal : TextInput.Password
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

                        Keys.onReturnPressed: ctx.submitPassword(passInput.text)
                        Keys.onEnterPressed: ctx.submitPassword(passInput.text)
                    }

                    // ── Caps Lock chip (#1) ──
                    //
                    // Small "CAPS" pill that lives inline with the
                    // password row. Only visible when capsLockOn is
                    // true AND we're actually in password mode —
                    // otherwise it's just chrome that confuses people
                    // during fingerprint mode.
                    Rectangle {
                        visible: lock.capsLockOn
                        Layout.preferredWidth: capsLabel.implicitWidth + 12
                        Layout.preferredHeight: 20
                        Layout.alignment: Qt.AlignVCenter
                        radius: 10
                        color: Qt.rgba(Root.Theme.accentWarning.r,
                                       Root.Theme.accentWarning.g,
                                       Root.Theme.accentWarning.b, 0.22)
                        border.width: 1
                        border.color: Qt.rgba(Root.Theme.accentWarning.r,
                                              Root.Theme.accentWarning.g,
                                              Root.Theme.accentWarning.b, 0.55)
                        Text {
                            id: capsLabel
                            anchors.centerIn: parent
                            text: "CAPS"
                            color: Root.Theme.accentWarning
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXXS; bold: true; letterSpacing: Root.Theme.trackingCaps }
                        }
                    }

                    // ── Eye toggle (#2) ──
                    //
                    // Hardcoded mdi glyphs because Icons.qml doesn't
                    // expose eye / eye-off yet. Using a plain Text +
                    // MouseArea rather than IconButton to match the
                    // visual weight of the arrow submit next to it —
                    // IconButton would introduce its own padded hit
                    // region and look chunkier than the row.
                    Text {
                        text: lock.passwordVisible ? "󰈉" : "󰈈"
                        color: eyeMouse.containsMouse ? Root.Theme.textAccent : Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize3XL }
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                        MouseArea {
                            id: eyeMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: lock.passwordVisible = !lock.passwordVisible
                        }
                    }

                    Text {
                        text: "→"
                        color: passInput.text.length > 0 ? Root.Theme.textAccent : Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize3XL; bold: true }
                        visible: passInput.text.length > 0
                        Layout.alignment: Qt.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ctx.submitPassword(passInput.text)
                        }
                    }
                }
            }
            }
        }

        // ══════════════════════════════════════════════
        // ── Info/error bubble (#6) ──
        // ══════════════════════════════════════════════
        //
        // Floating pill above the prompt backdrop. Content and tint
        // are driven by `bubbleText` / `bubbleKind`; visibility is
        // bound to bubbleText being non-empty. Uses a reveal
        // animation (opacity + slight upward slide) so new messages
        // feel punchy rather than popping in.
        //
        // Tint mapping:
        //   error → accentDanger (red)
        //   busy  → textAccent (blue) with neutral alpha
        //   info  → accentInfo (cyan)
        //
        // Width hugs the text + padding with a sensible cap so a
        // verbose PAM message doesn't stretch across the whole
        // screen. The rectangle's clip is on so the long-text case
        // elides cleanly inside the pill.
        Rectangle {
            id: bubble
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: promptBackdrop.top
            anchors.bottomMargin: Root.Theme.spacingM
            visible: lock.bubbleText.length > 0
            // Hug the content with 12/20 padding + 12/20 margin,
            // clamped so a long PAM error still fits on-screen.
            width: Math.min(bubbleLabel.implicitWidth + 40, promptBackdrop.width - 32)
            height: 36
            radius: 18
            clip: true
            color: {
                var base;
                if (lock.bubbleKind === "error")      base = Root.Theme.accentDanger;
                else if (lock.bubbleKind === "busy")  base = Root.Theme.textAccent;
                else                                   base = Root.Theme.accentInfo;
                return Qt.rgba(base.r, base.g, base.b, 0.22);
            }
            border.width: 1
            border.color: {
                var base;
                if (lock.bubbleKind === "error")      base = Root.Theme.accentDanger;
                else if (lock.bubbleKind === "busy")  base = Root.Theme.textAccent;
                else                                   base = Root.Theme.accentInfo;
                return Qt.rgba(base.r, base.g, base.b, 0.55);
            }
            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

            // Reveal animation: whenever `visible` flips true we run
            // a short fade + slide-up. We can't use `on visibleChanged`
            // because we also want a subtle bounce when the text
            // changes WITHOUT visibility toggling (error → new error).
            // So we also trigger on bubbleText changes from the lock
            // root below.
            opacity: 0
            transform: Translate { id: bubbleTranslate; y: 8 }
            ParallelAnimation {
                id: bubbleReveal
                NumberAnimation { target: bubble; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { target: bubbleTranslate; property: "y"; from: 8; to: 0; duration: 220; easing.type: Easing.OutCubic }
            }
            onVisibleChanged: if (visible) bubbleReveal.start()

            // Color-matched dot + text. The dot is a small cue that
            // works even when glanced at peripherally.
            Row {
                anchors.centerIn: parent
                spacing: Root.Theme.spacingS

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3
                    color: {
                        if (lock.bubbleKind === "error")     return Root.Theme.accentDanger;
                        if (lock.bubbleKind === "busy")      return Root.Theme.textAccent;
                        return Root.Theme.accentInfo;
                    }
                }
                Text {
                    id: bubbleLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: lock.bubbleText
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM; bold: true }
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, promptBackdrop.width - 96)
                }
            }
        }

        // Text-change retrigger: when bubbleText mutates but the
        // bubble stays visible (one error → another), restart the
        // reveal animation so the user notices the change.
        Connections {
            target: lock
            function onBubbleTextChanged() {
                if (lock.bubbleText.length > 0 && bubble.visible) bubbleReveal.restart();
            }
        }

        // ── Music display above prompt ──
        Rectangle {
            id: mediaBg
            anchors.horizontalCenter: parent.horizontalCenter
            // Anchor to the bubble's top when the bubble is visible,
            // otherwise sit directly on top of the prompt. Without
            // this the media card would overlap the bubble.
            anchors.bottom: bubble.visible ? bubble.top : promptBackdrop.top
            anchors.bottomMargin: Root.Theme.spacingL
            width: mediaRow.width + 32
            height: mediaRow.height + 32
            radius: 16
            color: Qt.rgba(Root.Theme.base00.r, Root.Theme.base00.g, Root.Theme.base00.b, 0.75)
            border.width: 1
            border.color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.15)
            visible: lock.playerService && lock.playerService.hasMedia

            Row {
                id: mediaRow
                anchors.centerIn: parent
                spacing: Root.Theme.spacingM

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
                        text: Root.Icons.music
                        color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.scaled(20) }
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
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXL; bold: true }
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 250)
                    }

                    Text {
                        text: lock.playerService ? lock.playerService.trackArtist : ""
                        color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM }
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 250)
                        visible: text.length > 0
                    }
                }

                // Transport controls: prev / play-pause / next. Each glyph
                // is a Text wrapped in a MouseArea; hover bumps scale and
                // opacity for tactile feedback without adding a heavy
                // button component. The outer Row owns vertical centering
                // via its own anchors so we avoid per-child anchor churn.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // Reusable inline "glyph button" via an Item + Text +
                    // MouseArea pattern. We repeat it three times rather
                    // than factor out a Component because the file is
                    // already dense with one-off visual idioms and each
                    // button has a different onClicked handler.
                    Item {
                        id: prevBtn
                        width: 24; height: 24
                        property bool hovered: prevMa.containsMouse
                        Text {
                            anchors.centerIn: parent
                            text: Root.Icons.skipBack
                            color: prevBtn.hovered ? Root.Theme.textPrimary : Root.Theme.domainMedia
                            font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize3XL }
                            scale: prevBtn.hovered ? 1.15 : 1.0
                            Behavior on scale { NumberAnimation { duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                        }
                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (lock.playerService) lock.playerService.previous()
                        }
                    }

                    Item {
                        id: playPauseBtn
                        width: 28; height: 28
                        property bool hovered: ppMa.containsMouse
                        Text {
                            anchors.centerIn: parent
                            text: (lock.playerService && lock.playerService.isPlaying) ? Root.Icons.mediaPause : Root.Icons.mediaPlay
                            color: playPauseBtn.hovered ? Root.Theme.textPrimary : Root.Theme.domainMedia
                            font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize4XL }
                            scale: playPauseBtn.hovered ? 1.15 : 1.0
                            Behavior on scale { NumberAnimation { duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                        }
                        MouseArea {
                            id: ppMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (lock.playerService) lock.playerService.togglePlaying()
                        }
                    }

                    Item {
                        id: nextBtn
                        width: 24; height: 24
                        property bool hovered: nextMa.containsMouse
                        Text {
                            anchors.centerIn: parent
                            text: Root.Icons.skipFwd
                            color: nextBtn.hovered ? Root.Theme.textPrimary : Root.Theme.domainMedia
                            font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize3XL }
                            scale: nextBtn.hovered ? 1.15 : 1.0
                            Behavior on scale { NumberAnimation { duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                        }
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (lock.playerService) lock.playerService.next()
                        }
                    }
                }
            }
        }
        // ══════════════════════════════════════════════
        // ── Session controls row (bottom) — #7 ──
        // ══════════════════════════════════════════════
        //
        // Suspend / Reboot / Shutdown buttons with a two-click
        // countdown confirmation. The layout is:
        //
        //   [suspend]  [reboot]  [shutdown]     ← idle state
        //
        //   [cancel ✕]  [power action in 3…]    ← armed state
        //
        // We collapse to a compact armed-state row instead of keeping
        // the full three-button layout + a badge, because a tiny
        // countdown label next to one of three identical-looking
        // buttons is easy to miss. A dedicated "armed" row draws the
        // eye and makes the cancel target obvious.
        Item {
            id: sessionControls
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Root.Theme.spacingXL
            width: 320
            height: 44

            // Idle row: three IconButton-style buttons. Clicking any
            // of them arms that action — the armed row below then
            // replaces this row until the user confirms or cancels.
            Row {
                anchors.centerIn: parent
                spacing: Root.Theme.spacingL
                visible: lock.pendingPowerAction === ""

                // Small inline factory — a styled circular button with
                // a glyph + tooltip-on-hover label. Kept inline rather
                // than extracting a component because it's only used
                // three times and in one place. If a fourth caller
                // appears, promote it to components/.
                Rectangle {
                    width: 44; height: 44; radius: 22
                    color: suspendMouse.containsMouse
                        ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.15)
                        : Qt.rgba(Root.Theme.base00.r, Root.Theme.base00.g, Root.Theme.base00.b, 0.75)
                    border.width: 1
                    border.color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.2)
                    scale: suspendMouse.pressed ? 0.92 : 1.0
                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                    Behavior on scale { NumberAnimation { duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: Root.Icons.suspend
                        color: Root.Theme.powerSuspend
                        font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize3XL }
                    }
                    MouseArea {
                        id: suspendMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ctx.armPowerAction("suspend")
                    }
                }

                Rectangle {
                    width: 44; height: 44; radius: 22
                    color: rebootMouse.containsMouse
                        ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.15)
                        : Qt.rgba(Root.Theme.base00.r, Root.Theme.base00.g, Root.Theme.base00.b, 0.75)
                    border.width: 1
                    border.color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.2)
                    scale: rebootMouse.pressed ? 0.92 : 1.0
                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                    Behavior on scale { NumberAnimation { duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: Root.Icons.reboot
                        color: Root.Theme.accentWarm
                        font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize3XL }
                    }
                    MouseArea {
                        id: rebootMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ctx.armPowerAction("reboot")
                    }
                }

                Rectangle {
                    width: 44; height: 44; radius: 22
                    color: shutdownMouse.containsMouse
                        ? Qt.rgba(Root.Theme.accentDanger.r, Root.Theme.accentDanger.g, Root.Theme.accentDanger.b, 0.18)
                        : Qt.rgba(Root.Theme.base00.r, Root.Theme.base00.g, Root.Theme.base00.b, 0.75)
                    border.width: 1
                    border.color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.2)
                    scale: shutdownMouse.pressed ? 0.92 : 1.0
                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                    Behavior on scale { NumberAnimation { duration: Root.Theme.anim.microDuration; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: Root.Icons.shutdown
                        color: Root.Theme.accentDanger
                        font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize3XL }
                    }
                    MouseArea {
                        id: shutdownMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ctx.armPowerAction("shutdown")
                    }
                }
            }

            // Armed row: replaces the idle row for the duration of
            // the countdown. Layout is [cancel ✕]  [action in Ns].
            // Clicking the action pill again fires immediately (via
            // armPowerAction's same-action fast-path), clicking the
            // cancel X aborts, and Escape also aborts via the
            // Shortcut above.
            Row {
                anchors.centerIn: parent
                spacing: Root.Theme.spacingM
                visible: lock.pendingPowerAction !== ""

                // Cancel button
                Rectangle {
                    width: 44; height: 44; radius: 22
                    color: cancelMouse.containsMouse
                        ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.15)
                        : Qt.rgba(Root.Theme.base00.r, Root.Theme.base00.g, Root.Theme.base00.b, 0.85)
                    border.width: 1
                    border.color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.2)
                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize3XL; bold: true }
                    }
                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ctx.cancelPowerAction()
                    }
                }

                // Armed action pill — click again to confirm
                Rectangle {
                    height: 44
                    width: confirmLabel.implicitWidth + 28
                    radius: 22
                    color: {
                        // Tint matches the action so the user can see
                        // at a glance what they're about to confirm.
                        var base;
                        if (lock.pendingPowerAction === "suspend") base = Root.Theme.powerSuspend;
                        else if (lock.pendingPowerAction === "reboot") base = Root.Theme.accentWarm;
                        else base = Root.Theme.accentDanger;
                        return confirmMouse.containsMouse
                            ? Qt.rgba(base.r, base.g, base.b, 0.35)
                            : Qt.rgba(base.r, base.g, base.b, 0.22);
                    }
                    border.width: 1
                    border.color: {
                        var base;
                        if (lock.pendingPowerAction === "suspend") base = Root.Theme.powerSuspend;
                        else if (lock.pendingPowerAction === "reboot") base = Root.Theme.accentWarm;
                        else base = Root.Theme.accentDanger;
                        return Qt.rgba(base.r, base.g, base.b, 0.6);
                    }
                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                    Text {
                        id: confirmLabel
                        anchors.centerIn: parent
                        text: {
                            var verb;
                            if (lock.pendingPowerAction === "suspend") verb = "Suspending";
                            else if (lock.pendingPowerAction === "reboot") verb = "Rebooting";
                            else if (lock.pendingPowerAction === "shutdown") verb = "Shutting down";
                            else verb = "";
                            return verb + " in " + lock.powerCountdown + "s · click to confirm";
                        }
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM; bold: true }
                    }
                    MouseArea {
                        id: confirmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ctx.executePowerAction()
                    }
                }
            }
        }
    } // lockContent Item
    }
}
