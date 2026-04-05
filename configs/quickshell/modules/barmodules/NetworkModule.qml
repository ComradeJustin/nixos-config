import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

Components.BarItem {
    id: root

    property var svc: Core.ServiceManager.wifi

    icon: Root.Icons.wifiIcon(svc)
    value: {
        if (!svc || !svc.enabled) return "Off";
        if (!svc.connected) return "No net";
        if (svc.iface === "ethernet") return "Eth";
        return svc.ssid;
    }
    accent: (svc && svc.connected) ? Root.Theme.domainNetwork : Root.Theme.textDimmed
}
