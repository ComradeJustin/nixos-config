import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

Components.BarItem {
    id: root

    property var svc: Core.ServiceManager.audio
    property int vol: svc ? svc.volume : -1
    property bool muted: svc ? svc.muted : false

    icon: Root.Icons.volumeIcon(vol, muted)
    value: vol >= 0 ? vol + "%" : "--"
    accent: muted ? Root.Theme.textDimmed : Root.Theme.domainMedia
    tooltipText: {
        let tip = muted ? "Muted" : "Volume " + vol + "%";
        if (svc && svc.activeDeviceLabel)
            tip += " · " + svc.activeDeviceLabel;
        return tip;
    }
}
