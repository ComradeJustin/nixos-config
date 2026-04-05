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
    Services.NotifService { id: notifSvc }
    Services.WifiService { id: wifiSvc }
    Services.BluetoothService { id: btSvc }
    Services.BrightnessService { id: briSvc }
    Services.WindowService { id: winSvc }
    Services.IdleInhibitService { id: idleInhibitSvc }
    Services.WeatherService { id: weatherSvc }
    Services.SystemStatsService { id: systemStatsSvc }

    // Register services with ServiceManager for self-wiring
    Item {
        visible: false
        Component.onCompleted: {
            Core.ServiceManager.register("audio", audioSvc);
            Core.ServiceManager.register("player", playerSvc);
            Core.ServiceManager.register("power", powerSvc);
            Core.ServiceManager.register("notif", notifSvc);
            Core.ServiceManager.register("wifi", wifiSvc);
            Core.ServiceManager.register("bluetooth", btSvc);
            Core.ServiceManager.register("brightness", briSvc);
            Core.ServiceManager.register("window", winSvc);
            Core.ServiceManager.register("idleInhibit", idleInhibitSvc);
            Core.ServiceManager.register("weather", weatherSvc);
            Core.ServiceManager.register("systemStats", systemStatsSvc);
        }
    }

    // ── Modules ──
    Modules.PowerMenu {
        id: pmModule
        powerService: powerSvc
        onLockRequested: lock()
    }
    Modules.ControlCenter {
        id: ccModule
        audioService: audioSvc
        powerMenuRef: pmModule
        notifService: notifSvc
        wifiService: wifiSvc
        bluetoothService: btSvc
        idleInhibitService: idleInhibitSvc
    }
    Modules.Spotlight { id: spotModule }
    Modules.Osd {
        audioService: audioSvc
        brightnessService: briSvc
    }
    Modules.Bar {
        id: barModule
        notifRef: ccModule
        powerMenuRef: pmModule
        playerService: playerSvc
    }

    Modules.SettingsWindow { id: settingsWindow; barRef: barModule; widgetOverlayRef: widgetModule }
    Modules.MonitorPanel { id: monitorPanel }

    // Background widgets overlay
    Modules.WidgetOverlay {
        id: widgetModule
        windowService: winSvc
        playerService: playerSvc
        weatherService: weatherSvc
    }

    // ── Session Lock ──
    property bool screenLocked: false
    property int wakeCounter: 0

    WlSessionLock {
        id: sessionLock
        locked: screenLocked

        WlSessionLockSurface {
            Modules.LockScreen {
                anchors.fill: parent
                playerService: playerSvc
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
        function controlcenter(): string { ccModule.toggle(); return "ok" }
        function powermenu(): string { pmModule.toggle(); return "ok" }
        function lockscreen(): string { lock(); return "ok" }
        function wakelock(): string { if (screenLocked) wakeCounter++; return "ok" }
        function widgetsettings(): string { widgetModule.toggleEditMode(); return "ok" }
        function settings(): string { settingsWindow.toggle(); return "ok" }
        function monitors(): string { monitorPanel.toggle(); return "ok" }
        function baredit(): string { barModule.toggleBarEdit(); return "ok" }
        function caffeine(): string { idleInhibitSvc.toggle(); return idleInhibitSvc.inhibited ? "on" : "off" }
        function volumeup(): string { audioSvc.setVolume(audioSvc.volume + 5); return "ok" }
        function volumedown(): string { audioSvc.setVolume(audioSvc.volume - 5); return "ok" }
        function volumemute(): string { audioSvc.toggleMute(); return "ok" }
        function brightnessup(): string { briSvc.increase(5); return "ok" }
        function brightnessdown(): string { briSvc.decrease(5); return "ok" }
    }
}
