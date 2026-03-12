import Quickshell
import "modules" as Modules

ShellRoot {
    Modules.Notifications { id: notifs }
    Modules.Osd {}
    Modules.Bar { notifRef: notifs }
}
