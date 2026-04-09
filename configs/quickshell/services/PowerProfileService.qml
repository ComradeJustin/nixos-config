import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../core" as Core

// PowerProfileService — thin wrapper around Quickshell.Services.UPower.PowerProfiles.
//
// PowerProfiles is a reactive singleton that binds to the UPower D-Bus
// interface, so we don't need any polling or subprocess (no shelling out
// to `powerprofilesctl`). We just expose a project-friendly API surface
// (setProfile/cycleProfile/getName/getIcon) and forward the `profile`
// value so bar widgets can bind to it.
//
// `available` is false on systems without a performance profile (most
// desktops, VMs) — consumers should check it before rendering UI.
//
// Signals `profileChanged(int)` on every transition so HooksService can
// fire user scripts on plug-in/performance-mode swaps if desired.
Scope {
    id: root

    readonly property var _pp: PowerProfiles
    readonly property bool available: _pp && _pp.hasPerformanceProfile
    property int profile: _pp ? _pp.profile : PowerProfile.Balanced

    // Transition signal — named powerProfileChanged (not profileChanged)
    // to avoid colliding with the auto-generated `profileChanged` signal
    // QML emits for the `profile` property. Same trick as PowerService.
    signal powerProfileChanged(int profile)

    Connections {
        target: root._pp
        ignoreUnknownSignals: true
        function onProfileChanged() {
            var old = root.profile;
            root.profile = root._pp.profile;
            if (old !== root.profile) {
                Core.Logger.i("PowerProfile", "changed ->", root.getName(root.profile));
                root.powerProfileChanged(root.profile);
            }
        }
    }

    Component.onCompleted: {
        if (available) {
            Core.Logger.i("PowerProfile", "ready, current:", getName(profile));
        } else {
            Core.Logger.i("PowerProfile", "unavailable (no performance profile on this system)");
        }
    }

    // ── Query ──
    function getName(p) {
        var prof = (p !== undefined) ? p : root.profile;
        switch (prof) {
        case PowerProfile.Performance: return "Performance";
        case PowerProfile.Balanced:    return "Balanced";
        case PowerProfile.PowerSaver:  return "Power Saver";
        default:                       return "Unknown";
        }
    }

    // Icon name suitable for a freedesktop icon theme lookup.
    function getIcon(p) {
        var prof = (p !== undefined) ? p : root.profile;
        switch (prof) {
        case PowerProfile.Performance: return "power-profile-performance-symbolic";
        case PowerProfile.Balanced:    return "power-profile-balanced-symbolic";
        case PowerProfile.PowerSaver:  return "power-profile-power-saver-symbolic";
        default:                       return "power-profile-balanced-symbolic";
        }
    }

    // ── Mutate ──
    function setProfile(p) {
        if (!available) {
            Core.Logger.w("PowerProfile", "setProfile ignored — unavailable");
            return;
        }
        try {
            _pp.profile = p;
        } catch (err) {
            Core.Logger.e("PowerProfile", "setProfile failed:", err);
        }
    }

    // Cycle PowerSaver → Balanced → Performance → PowerSaver
    function cycleProfile() {
        if (!available) return;
        switch (root.profile) {
        case PowerProfile.PowerSaver:  setProfile(PowerProfile.Balanced);    break;
        case PowerProfile.Balanced:    setProfile(PowerProfile.Performance); break;
        case PowerProfile.Performance: setProfile(PowerProfile.PowerSaver);  break;
        default:                       setProfile(PowerProfile.Balanced);
        }
    }
}
