import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

Components.BarItem {
    id: root

    property var svc: Core.ServiceManager.weather

    icon: svc ? svc.icon : Root.Icons.weatherDefault
    value: svc ? svc.temperature : "--"
    accent: Root.Theme.domainWeather
    // Degraded when fetch completed but returned no data
    degraded: svc ? (svc.initialized && svc.temperature === "--") : false
    tooltipText: {
        if (!svc) return "";
        let tip = svc.condition || "Weather";
        if (svc.temperature) tip += " · " + svc.temperature;
        if (svc.location) tip += " · " + svc.location;
        return tip;
    }
}
