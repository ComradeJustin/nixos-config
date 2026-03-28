//@ pragma UseQApplication
//@ pragma IconTheme Gruvbox-Plus-Dark
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "modules" as Modules
import "utils" as Utils

ShellRoot {
    Utils.AudioService { id: audioSvc }
    Utils.PlayerService { id: playerSvc }
    Utils.PowerService { id: powerSvc }
    Utils.NotifService { id: notifSvc }
    Utils.WifiService { id: wifiSvc }
    Utils.BluetoothService { id: btSvc }
    Utils.BrightnessService { id: briSvc }
    Utils.WindowService { id: winSvc }
    Utils.IdleInhibitService { id: idleInhibitSvc }

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
        widgetOverlayRef: widgetModule
        idleInhibitService: idleInhibitSvc
        onWidgetEditRequested: widgetModule.toggleEditMode()
    }
    Modules.Spotlight { id: spotModule }
    Modules.Osd {
        audioService: audioSvc
        brightnessService: briSvc
    }
    Modules.Bar {
        notifRef: ccModule
        playerService: playerSvc
        powerService: powerSvc
        audioService: audioSvc
        powerMenuRef: pmModule
        wifiService: wifiSvc
        bluetoothService: btSvc
    }

    // Background widgets overlay
    Modules.WidgetOverlay {
        id: widgetModule
        windowService: winSvc
        playerService: playerSvc
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
        function caffeine(): string { idleInhibitSvc.toggle(); return idleInhibitSvc.inhibited ? "on" : "off" }
    }
}
