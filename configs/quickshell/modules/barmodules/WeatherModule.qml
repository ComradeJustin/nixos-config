import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

Components.BarItem {
    id: root

    property var svc: Core.ServiceManager.weather

    icon: svc ? svc.icon : Root.Theme.iconWeatherDefault
    value: svc ? svc.temperature : "--"
    accent: Root.Theme.domainWeather
}
