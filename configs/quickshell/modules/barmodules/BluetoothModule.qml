import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

Components.BarItem {
    id: root

    property var svc: Core.ServiceManager.bluetooth

    icon: {
        if (!svc || !svc.enabled) return Root.Icons.btOff;
        if (svc.connected) return Root.Icons.btConnected;
        return Root.Icons.btOn;
    }
    value: {
        if (!svc || !svc.enabled) return "Off";
        if (svc.connected) {
            let name = svc.connectedDevice;
            return name.length > 10 ? name.substring(0, 8) + "\u2026" : name;
        }
        return "On";
    }
    accent: {
        if (!svc || !svc.enabled) return Root.Theme.textDimmed;
        if (svc.connected) return Root.Theme.accentSuccess;
        return Root.Theme.domainNetwork;
    }
}
