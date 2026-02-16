import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Niri 0.1
import "./modules/bar/"
import "./modules/widget/"
ShellRoot {
    id: root

    Niri {
        id: niri
        Component.onCompleted: connect()

        onConnected: console.info("Connected to niri")
        onErrorOccurred: function(error) {
        console.error("Niri error:", error)
    }
}

LazyLoader { active: true; component: Bar {} }
LazyLoader { active: true; component: Volume {}}


}
