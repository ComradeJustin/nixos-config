import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

Components.BarItem {
    id: root

    property var svc: Core.ServiceManager.wifi

    // Degraded when wifi service exists but reports no interface
    degraded: svc ? (svc.enabled && !svc.connected && svc.iface === "") : false

    icon: Root.Icons.wifiIcon(svc)
    value: {
        if (!svc || !svc.enabled) return "Off";
        if (!svc.connected) return "No net";
        if (svc.iface === "ethernet") return "Eth";
        return svc.ssid;
    }
    accent: (svc && svc.connected) ? Root.Theme.domainNetwork : Root.Theme.textDimmed
    tooltipText: {
        if (!svc || !svc.enabled) return "Wi-Fi disabled";
        if (!svc.connected) return "Not connected";
        let tip = svc.ssid || "Connected";
        if (svc.signal >= 0) tip += " · " + svc.signal + "%";
        if (svc.iface) tip += " · " + svc.iface;
        return tip;
    }
}
