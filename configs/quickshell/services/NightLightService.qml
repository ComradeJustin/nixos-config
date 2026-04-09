import QtQuick
import Quickshell
import Quickshell.Io
import "../core" as Core
import ".." as Root

// NightLightService — thin supervisor around `wlsunset`.
//
// Design choices (diverges from Noctalia's version):
//   • Auto mode only. Manual HH:MM scheduling is intentionally omitted
//     to keep the surface area small. `wlsunset -l LAT -L LON` already
//     handles sunrise/sunset internally using astronomical data.
//   • Coordinates come from WeatherService so we have exactly one
//     source of truth (and one geolocation HTTP call per session).
//   • Persistence lives in Root.Config under the `nightLight` section —
//     no separate FileView file.
//
// Process lifecycle:
//   1. Component.onCompleted kills any stale wlsunset left over from a
//      prior shell crash (they'd still own the gamma LUT otherwise).
//   2. When WeatherService reports `hasLocation = true` AND the user has
//      `enabled = true`, we spawn wlsunset with the current temps + coords.
//   3. On unexpected exit while enabled, we restart up to 5 times with a
//      2-second backoff. More than that and we give up — something is
//      wrong (missing binary, compositor rejecting gamma control, etc.)
//      and flapping would just spam the log.
//   4. `apply()` is idempotent: it compares the new argv against the last
//      spawned argv and only restarts wlsunset if something actually
//      changed. This matters because the Config sliders will call apply()
//      on every drag tick.
Scope {
    id: root

    // ── Public state ──
    property bool enabled: false
    property int dayTemp: 6500
    property int nightTemp: 4000

    // Derived read-only view of whether wlsunset is actually running
    readonly property bool active: runner.running

    // ── Internal ──
    property var _lastCommand: []
    property int _crashCount: 0
    readonly property int _maxCrashes: 5

    // Bind to weather coordinates (single source of truth).
    // Access via ServiceManager — the WeatherService instance is registered
    // in shell.qml's Component.onCompleted under the key "weather".
    readonly property var _weather: Core.ServiceManager.weather
    readonly property real _lat: _weather ? _weather.latitude : 0
    readonly property real _lon: _weather ? _weather.longitude : 0
    readonly property bool _hasLocation: _weather ? _weather.hasLocation : false

    // ── Load persisted config on startup ──
    Component.onCompleted: {
        // Pull initial values from Config (imported as Root.Config singleton).
        // If the nightLight section doesn't exist yet, fall back to defaults.
        try {
            var cfg = Root.Config.nightLight;
            if (cfg) {
                if (cfg.enabled !== undefined)   root.enabled   = cfg.enabled;
                if (cfg.dayTemp !== undefined)   root.dayTemp   = cfg.dayTemp;
                if (cfg.nightTemp !== undefined) root.nightTemp = cfg.nightTemp;
            }
        } catch (e) {
            Core.Logger.w("NightLight", "config load failed:", e);
        }
        killStaleProc.running = true;
    }

    // Kill any leftover wlsunset from a prior shell session. Without this,
    // restarting quickshell would leave an orphaned wlsunset still holding
    // the gamma LUT — our own spawn would either fail or race with it.
    Process {
        id: killStaleProc
        command: ["pkill", "-x", "wlsunset"]
        onExited: code => {
            if (code === 0) Core.Logger.i("NightLight", "killed stale wlsunset");
            root.apply();
        }
    }

    // ── Public API ──
    function toggle() { setEnabled(!root.enabled); }

    function setEnabled(on) {
        if (root.enabled === on) return;
        root.enabled = on;
        Core.Logger.i("NightLight", on ? "enabled" : "disabled");
        _persist();
        apply();
    }

    function setTemperatures(day, night) {
        root.dayTemp = day;
        root.nightTemp = night;
        _persist();
        apply();
    }

    // Build argv from current state, then spawn/kill as appropriate.
    // Called from: Component.onCompleted, setEnabled, setTemperatures,
    // and the location-ready Connections below.
    function apply() {
        // Without coordinates we can't run auto mode at all — wait.
        if (root.enabled && !root._hasLocation) {
            Core.Logger.d("NightLight", "waiting for location…");
            return;
        }

        if (!root.enabled) {
            if (runner.running) {
                runner.running = false;
                _lastCommand = [];
                Core.Logger.i("NightLight", "stopped");
            }
            return;
        }

        var cmd = [
            "wlsunset",
            "-t", "" + root.nightTemp,
            "-T", "" + root.dayTemp,
            "-l", "" + root._lat,
            "-L", "" + root._lon,
            "-d", "" + (15 * 60)  // 15-minute progressive fade
        ];

        // Idempotent: skip restart if nothing changed.
        if (JSON.stringify(cmd) === JSON.stringify(_lastCommand) && runner.running) {
            return;
        }
        _lastCommand = cmd;
        runner.command = cmd;
        runner.running = false;
        runner.running = true;
    }

    // ── Persistence helper ──
    // Root.Config is a singleton QtObject with a `save()` method that
    // writes the whole tree back to disk. We touch the nightLight section
    // and let Config handle the rest.
    function _persist() {
        try {
            if (!Root.Config.nightLight) return;
            Root.Config.nightLight.enabled = root.enabled;
            Root.Config.nightLight.dayTemp = root.dayTemp;
            Root.Config.nightLight.nightTemp = root.nightTemp;
            Root.Config.save();
        } catch (e) {
            Core.Logger.w("NightLight", "persist failed:", e);
        }
    }

    // ── Location readiness ──
    // When WeatherService finishes the IP-geolocation call, _hasLocation
    // flips true; we re-apply so wlsunset finally starts if the user had
    // it enabled at launch. Using a Connections block with a dynamic target
    // (rather than binding directly to _hasLocation via onChanged) lets the
    // ServiceManager registration race cleanly — if `weather` is null at
    // instantiation, the target updates the moment it's registered.
    Connections {
        target: root._weather
        ignoreUnknownSignals: true
        function onHasLocationChanged() {
            if (root._hasLocation) {
                Core.Logger.i("NightLight", "location ready, lat=" + root._lat + " lon=" + root._lon);
                root.apply();
            }
        }
    }

    // ── wlsunset supervisor ──
    Process {
        id: runner
        onStarted: {
            Core.Logger.i("NightLight", "wlsunset started");
            if (root._crashCount > 0) root._crashCount = 0;
        }
        onExited: (code, status) => {
            if (!root.enabled) {
                Core.Logger.d("NightLight", "wlsunset exited cleanly (disabled)");
                root._crashCount = 0;
                return;
            }
            root._crashCount++;
            if (root._crashCount <= root._maxCrashes) {
                Core.Logger.w("NightLight",
                    "wlsunset exited unexpectedly (code=" + code + "), retrying in 2s (" + root._crashCount + "/" + root._maxCrashes + ")");
                restartTimer.start();
            } else {
                Core.Logger.e("NightLight",
                    "wlsunset crashed " + root._maxCrashes + " times — giving up. Check that wlsunset is installed and the compositor supports wlr-gamma-control.");
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        repeat: false
        onTriggered: if (root.enabled && !runner.running) root.apply()
    }
}
