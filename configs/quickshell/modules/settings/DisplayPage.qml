import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

// Display page — currently just Night Light. Named generically so
// screen-related settings (scale, color profile, etc.) can land here
// later without a rename.
Column {
    width: parent ? parent.width : 0
    spacing: 16

    Components.SettingSection {
        title: "NIGHT LIGHT"
        width: parent.width
        resetCallback: () => Root.Config.resetSection("nightLight")

        Components.SettingToggle {
            label: "Enable night light"
            description: {
                let svc = Core.ServiceManager.nightLight;
                if (!svc) return "Service unavailable";
                if (Root.Config.nightLight.enabled && !svc._hasLocation)
                    return "Waiting for location…";
                if (svc.active) return "Active — wlsunset running";
                return "Automatic sunrise/sunset schedule";
            }
            isOn: Root.Config.nightLight.enabled
            onToggled: {
                let svc = Core.ServiceManager.nightLight;
                if (svc) svc.toggle();
            }
        }

        Components.SettingSlider {
            label: "Day temperature"
            value: Root.Config.nightLight.dayTemp
            minValue: 3000; maxValue: 6500; suffix: "K"
            onSliderUpdated: newValue => {
                let svc = Core.ServiceManager.nightLight;
                let day = Math.round(newValue);
                let night = Root.Config.nightLight.nightTemp;
                if (svc) svc.setTemperatures(day, night);
                else {
                    Root.Config.nightLight.dayTemp = day;
                    Root.Config.save();
                }
            }
        }

        Components.SettingSlider {
            label: "Night temperature"
            value: Root.Config.nightLight.nightTemp
            minValue: 2500; maxValue: 6500; suffix: "K"
            onSliderUpdated: newValue => {
                let svc = Core.ServiceManager.nightLight;
                let day = Root.Config.nightLight.dayTemp;
                let night = Math.round(newValue);
                if (svc) svc.setTemperatures(day, night);
                else {
                    Root.Config.nightLight.nightTemp = night;
                    Root.Config.save();
                }
            }
        }
    }

    Item { width: 1; height: 8 }
}
