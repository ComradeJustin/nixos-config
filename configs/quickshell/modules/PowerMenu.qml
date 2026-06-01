import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import ".." as Root
import "../core" as Core

// Centered power menu overlay.
// Toggle via IPC: qs ipc call quickshell-bar power
Scope {
    id: pm

    // Theme is now a singleton - access via Root.Theme.propertyName

    property bool showing: false
    property int selectedIndex: 0

    property var actions: [
        { icon: Root.Icons.lock, label: "Lock", action: "lock", color: Root.Theme.domainSettings },
        { icon: Root.Icons.suspend, label: "Suspend", action: "suspend", color: Root.Theme.accentWarning },
        { icon: Root.Icons.logout, label: "Logout", action: "logout", color: Root.Theme.domainNetwork },
        { icon: Root.Icons.reboot, label: "Reboot", action: "reboot", color: Root.Theme.accentWarm },
        { icon: Root.Icons.shutdown, label: "Shutdown", action: "shutdown", color: Root.Theme.accentDanger }
    ]

    // ── Confirmation state ──
    //
    // Mirror the LockContext pattern: first click arms the action and
    // starts a 5-second countdown; a second click on the same action
    // fires immediately; Escape / scrim / the cancel button abort; if
    // the countdown reaches zero the action fires automatically.
    //
    // `lock` is deliberately exempt because it's trivially reversible
    // (you can just unlock again) and adding a countdown would make
    // the most-common action feel sluggish. Every other action in
    // this menu loses in-flight work if confirmed by accident, so it
    // earns the friction.
    property string pendingAction: ""
    property int countdown: 0

    function toggle() {
        showing = !showing;
        if (showing) {
            pmPanel.visible = true;
            selectedIndex = 0;
            pm.cancelPendingAction();
        }
    }

    signal lockRequested()

    // Single public entry point for "user wants to perform this
    // action". Lock skips the arm phase; everything else arms and
    // (on second click of the same action) fast-paths to execute.
    function requestAction(action) {
        if (action === "lock") {
            showing = false;
            pm.cancelPendingAction();
            lockRequested();
            return;
        }
        if (pm.pendingAction === action) {
            // Fast path: same action pressed twice → fire now.
            pm.executePendingAction();
            return;
        }
        pm.pendingAction = action;
        pm.countdown = 5;
        confirmCountdown.restart();
    }

    function executePendingAction() {
        var action = pm.pendingAction;
        confirmCountdown.stop();
        pm.pendingAction = "";
        pm.countdown = 0;
        if (action === "") return;
        showing = false;
        let svc = Core.ServiceManager.power;
        if (!svc) return;
        if (action === "suspend") svc.suspend();
        else if (action === "logout") svc.logout();
        else if (action === "reboot") svc.reboot();
        else if (action === "shutdown") svc.shutdown();
    }

    function cancelPendingAction() {
        confirmCountdown.stop();
        pm.pendingAction = "";
        pm.countdown = 0;
    }

    // 1Hz tick while an action is armed. Decrements the visible
    // countdown and auto-executes at zero. Stopped by arm/cancel/
    // execute paths so it can't fire on a stale action.
    Timer {
        id: confirmCountdown
        interval: 1000
        repeat: true
        onTriggered: {
            if (pm.pendingAction === "") {
                confirmCountdown.stop();
                return;
            }
            pm.countdown -= 1;
            if (pm.countdown <= 0) pm.executePendingAction();
        }
    }

    PanelWindow {
        id: pmPanel
        visible: false

        anchors { top: true; bottom: true; left: true; right: true }

        WlrLayershell.namespace: "quickshell-powermenu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        // Scrim
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            opacity: pm.showing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration } }
            MouseArea {
                anchors.fill: parent
                // Scrim click aborts an armed action first, then closes
                // the menu on a second click. Matches the Escape key
                // semantics below so users don't accidentally commit
                // to a shutdown by clicking outside the grid.
                onClicked: {
                    if (pm.pendingAction !== "") pm.cancelPendingAction();
                    else pm.showing = false;
                }
            }
        }

        // Center content
        Column {
            anchors.centerIn: parent
            spacing: 20
            scale: pm.showing ? 1 : 0.92
            opacity: pm.showing ? 1 : 0
            Behavior on scale { NumberAnimation { duration: Root.Theme.anim.bounceDuration; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }

            onOpacityChanged: {
                if (!pm.showing && opacity <= 0.01) {
                    pmPanel.visible = false;
                    // Clear any leftover armed state on hide so the
                    // next open is always a clean slate, even if the
                    // user closed the menu via Esc mid-countdown.
                    pm.cancelPendingAction();
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Session"
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize4XL; bold: true }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Arrow keys to navigate, Enter to select\nEsc or click anywhere to cancel"
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM }
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.3
            }

            // Icon grid
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Root.Theme.spacingM

                Repeater {
                    model: pm.actions

                    Rectangle {
                        id: pmItem
                        width: 90; height: 90
                        radius: pm.selectedIndex === index ? 45 : 16
                        color: pm.selectedIndex === index
                            ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.8)
                            : Root.Theme.ccSectionBg

                        Behavior on radius { NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Root.Theme.anim.moveDuration } }

                        layer.enabled: pm.selectedIndex === index
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.75)
                            shadowBlur: 1.0
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: pm.selectedIndex === index ? Root.Theme.barBackground : modelData.color
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize5XL }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: pm.selectedIndex = index
                            // requestAction dispatches to lock-immediate
                            // vs arm-and-confirm depending on the action.
                            // Clicking an already-armed action fires it
                            // (fast-path handled inside requestAction).
                            onClicked: pm.requestAction(modelData.action)
                        }
                    }
                }
            }

            // Label for selected — hidden during confirmation so the
            // countdown pill below doesn't compete with it.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pm.actions[pm.selectedIndex].label
                color: pm.actions[pm.selectedIndex].color
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXL; bold: true }
                visible: pm.pendingAction === ""
            }

            // ── Confirmation pill row (armed state) ──
            //
            // Structure copied from the LockScreen version: [cancel ✕]
            // [armed action countdown]. Clicking the countdown pill
            // fires immediately via the arm-fast-path inside
            // requestAction(); clicking ✕ aborts. Tint follows the
            // action's own color so there's zero ambiguity about what
            // is about to happen.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Root.Theme.spacingM
                visible: pm.pendingAction !== ""

                // ── Resolve the armed action's entry once per frame. ──
                // Walking the actions[] array inline for every color
                // binding would recompute on every sub-binding change;
                // caching it in a `readonly property var` lets every
                // binding below read a single source of truth.
                readonly property var armed: {
                    for (var i = 0; i < pm.actions.length; i++)
                        if (pm.actions[i].action === pm.pendingAction)
                            return pm.actions[i];
                    return null;
                }

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
                        onClicked: pm.cancelPendingAction()
                    }
                }

                // Armed action pill — click again to confirm
                Rectangle {
                    height: 44
                    width: confirmLabel.implicitWidth + 28
                    radius: 22
                    color: {
                        var base = parent.armed ? parent.armed.color : Root.Theme.accentDanger;
                        return confirmMouse.containsMouse
                            ? Qt.rgba(base.r, base.g, base.b, 0.35)
                            : Qt.rgba(base.r, base.g, base.b, 0.22);
                    }
                    border.width: 1
                    border.color: {
                        var base = parent.armed ? parent.armed.color : Root.Theme.accentDanger;
                        return Qt.rgba(base.r, base.g, base.b, 0.6);
                    }
                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                    Text {
                        id: confirmLabel
                        anchors.centerIn: parent
                        text: {
                            // Gerund form of the action ("Suspending",
                            // "Rebooting"…) reads more naturally in the
                            // "…in Ns" phrasing than a bare label would.
                            var verb;
                            if (pm.pendingAction === "suspend")  verb = "Suspending";
                            else if (pm.pendingAction === "logout")   verb = "Logging out";
                            else if (pm.pendingAction === "reboot")   verb = "Rebooting";
                            else if (pm.pendingAction === "shutdown") verb = "Shutting down";
                            else verb = "";
                            return verb + " in " + pm.countdown + "s · click to confirm";
                        }
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM; bold: true }
                    }
                    MouseArea {
                        id: confirmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pm.executePendingAction()
                    }
                }
            }
        }

        // Keyboard
        Item {
            anchors.fill: parent
            focus: pm.showing

            // Escape: if something is armed, cancel the pending action
            // first (so Esc is always "back one step"); if nothing is
            // armed, Esc closes the whole menu.
            Keys.onEscapePressed: {
                if (pm.pendingAction !== "") pm.cancelPendingAction();
                else pm.showing = false;
            }
            // Enter: arms the currently-highlighted action, and on the
            // second press (while the same action is armed) confirms
            // it — the same two-tap pattern as mouse clicks.
            Keys.onReturnPressed: pm.requestAction(pm.actions[pm.selectedIndex].action)
            // Arrow navigation is disabled while an action is armed so
            // users can't drift the selection off the thing they're
            // about to confirm.
            Keys.onLeftPressed: { if (pm.pendingAction === "" && pm.selectedIndex > 0) pm.selectedIndex--; }
            Keys.onRightPressed: { if (pm.pendingAction === "" && pm.selectedIndex < pm.actions.length - 1) pm.selectedIndex++; }
        }
    }
}
