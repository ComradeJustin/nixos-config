//@ pragma UseQApplication
//@ pragma IconTheme Gruvbox-Plus-Dark
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "modules" as Modules
import "services" as Services
import "core" as Core

ShellRoot {
    // ── Services ──
    Services.AudioService { id: audioSvc }
    Services.PlayerService { id: playerSvc }
    Services.PowerService { id: powerSvc }
    Services.PowerProfileService { id: powerProfileSvc }
    Services.NotifService { id: notifSvc }
    Services.WifiService { id: wifiSvc }
    Services.BluetoothService { id: btSvc }
    Services.BrightnessService { id: briSvc }
    Services.WindowService { id: winSvc }
    Services.IdleInhibitService { id: idleInhibitSvc }
    Services.WeatherService { id: weatherSvc }
    Services.SystemStatsService { id: systemStatsSvc }
    Services.NightLightService { id: nightLightSvc }
    Services.HooksService {
        id: hooksSvc
        services: ({
            "audio": audioSvc,
            "brightness": briSvc,
            "wifi": wifiSvc,
            "bluetooth": btSvc,
            "power": powerSvc,
            "powerProfile": powerProfileSvc,
            "idleInhibit": idleInhibitSvc,
            "notif": notifSvc,
            "weather": weatherSvc,
            "systemStats": systemStatsSvc,
            "nightLight": nightLightSvc
        })
    }

    // Register services and modules with ServiceManager for self-wiring
    Item {
        visible: false
        Component.onCompleted: {
            // Services
            Core.ServiceManager.register("audio", audioSvc);
            Core.ServiceManager.register("player", playerSvc);
            Core.ServiceManager.register("power", powerSvc);
            Core.ServiceManager.register("powerProfile", powerProfileSvc);
            Core.ServiceManager.register("notif", notifSvc);
            Core.ServiceManager.register("wifi", wifiSvc);
            Core.ServiceManager.register("bluetooth", btSvc);
            Core.ServiceManager.register("brightness", briSvc);
            Core.ServiceManager.register("window", winSvc);
            Core.ServiceManager.register("idleInhibit", idleInhibitSvc);
            Core.ServiceManager.register("weather", weatherSvc);
            Core.ServiceManager.register("systemStats", systemStatsSvc);
            Core.ServiceManager.register("nightLight", nightLightSvc);
            Core.ServiceManager.register("hooks", hooksSvc);
            // Modules
            Core.ServiceManager.register("bar", barModule);
            Core.ServiceManager.register("controlCenter", ccModule);
            Core.ServiceManager.register("powerMenu", pmModule);
            Core.ServiceManager.register("widgetOverlay", widgetModule);
            Core.ServiceManager.register("settingsWindow", settingsWindow);
        }
    }

    // ── Modules ──
    Modules.PowerMenu {
        id: pmModule
        onLockRequested: lock()
    }
    Modules.ControlCenter { id: ccModule }
    Modules.Spotlight { id: spotModule }
    Modules.Osd {}
    Modules.Bar { id: barModule }

    Modules.SettingsWindow { id: settingsWindow }
    Modules.MonitorPanel { id: monitorPanel }

    // Background widgets overlay
    Modules.WidgetOverlay { id: widgetModule }

    // ── Session Lock ──
    property bool screenLocked: false
    property int wakeCounter: 0

    WlSessionLock {
        id: sessionLock
        locked: screenLocked

        WlSessionLockSurface {
            Modules.LockScreen {
                anchors.fill: parent
                wakeSignal: wakeCounter
                onUnlocked: screenLocked = false
            }
        }
    }

    function lock() {
        screenLocked = true;
    }

    IpcHandler {
        target: "quickshell-bar"

        function launcher(): string { spotModule.toggle("launcher"); return "ok" }
        function clipboard(): string { spotModule.toggle("clipboard"); return "ok" }
        function wallpaper(): string { spotModule.toggle("wallpaper"); return "ok" }
        function calculator(): string { spotModule.toggle("calculator"); return "ok" }
        function emoji(): string { spotModule.toggle("emoji"); return "ok" }
        function controlcenter(): string { ccModule.toggle(); return "ok" }
        function powermenu(): string { pmModule.toggle(); return "ok" }
        function lockscreen(): string { lock(); return "ok" }
        function wakelock(): string { if (screenLocked) wakeCounter++; return "ok" }
        function widgetsettings(): string { widgetModule.toggleEditMode(); return "ok" }
        function settings(): string { settingsWindow.toggle(); return "ok" }
        function settingsOpen(page: string): string { settingsWindow.open(page); return "ok" }
        function monitors(): string { monitorPanel.toggle(); return "ok" }
        function baredit(): string { barModule.toggleBarEdit(); return "ok" }
        function caffeine(): string { idleInhibitSvc.toggle(); return idleInhibitSvc.inhibited ? "on" : "off" }
        function nightlight(): string { nightLightSvc.toggle(); return nightLightSvc.enabled ? "on" : "off" }
        function volumeup(): string { audioSvc.setVolume(audioSvc.volume + 5); return "ok" }
        function volumedown(): string { audioSvc.setVolume(audioSvc.volume - 5); return "ok" }
        function volumemute(): string { audioSvc.toggleMute(); return "ok" }
        function brightnessup(): string { briSvc.increase(5); return "ok" }
        function brightnessdown(): string { briSvc.decrease(5); return "ok" }
        function hooksReload(): string { hooksSvc.reload(); return "ok" }
        function hooksFire(event: string): string { hooksSvc.fire(event); return "ok" }
        function hooksList(): string { return JSON.stringify(hooksSvc.listEvents()); }
        function hooksRecent(): string { return JSON.stringify(hooksSvc.recentFires); }

        // Test handlers — fire the built-in power notifications on demand
        // so you can verify the app-name/synchronous-hint config without
        // waiting for a real AC plug or battery charge transition.
        function testNotifyCharged(): string { powerSvc.testFireCharged(); return "ok" }
        function testNotifyPlugged(): string { powerSvc.testFirePlugged(); return "ok" }
        function testNotifyLow(): string { powerSvc.testFireLow(); return "ok" }
    }
}
