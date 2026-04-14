pragma Singleton
import QtQuick

QtObject {
    // ── System ──
    readonly property string cpu:       "󰻠"
    readonly property string ram:       "󰍛"
    readonly property string plug:      "󰚥"
    readonly property string user:      "󰀄"
    readonly property string nixos:     ""

    // ── Volume ──
    readonly property string volHigh:   "󰕾"
    readonly property string volMid:    "󰖀"
    readonly property string volLow:    "󰕿"
    readonly property string volMute:   "󰖁"

    // ── Brightness ──
    readonly property string briHigh:   "󰃠"
    readonly property string briMid:    "󰃝"
    readonly property string briLow:    "󰃞"
    readonly property string briOff:    "󰃜"

    // ── Wifi ──
    readonly property string wifiHi:    "󰤨"
    readonly property string wifiMid:   "󰤥"
    readonly property string wifiLow:   "󰤢"
    readonly property string wifiMin:   "󰤟"
    readonly property string wifiOff:   "󰤭"
    readonly property string wifiLock:  "󰤪"
    readonly property string eth:       "󰈀"

    // ── Battery ──
    readonly property string batChg:    "󰂄"
    readonly property string bat100:    "󰁹"
    readonly property string bat80:     "󰂀"
    readonly property string bat60:     "󰁾"
    readonly property string bat40:     "󰁼"
    readonly property string bat20:     "󰂃"
    readonly property string batNone:   "󰂑"

    // ── Bluetooth ──
    readonly property string btOn:        "󰂯"
    readonly property string btOff:       "󰂲"
    readonly property string btConnected: "󰂱"

    // ── Media ──
    readonly property string headphone: "󰋋"
    readonly property string speaker:   "󰓃"
    readonly property string mediaPlay: "󰐊"
    readonly property string mediaPause:"󰏤"
    readonly property string play:      "󰐊"
    readonly property string pause:     "󰏤"
    readonly property string skipBack:  "󰒮"
    readonly property string skipFwd:   "󰒭"
    readonly property string prev:      "󰒮"
    readonly property string next:      "󰒭"
    readonly property string music:     "󰎆"

    // ── Weather ──
    readonly property string weatherSunny:   "󰖙"
    readonly property string weatherCloudy:  "󰖐"
    readonly property string weatherPartly:  "󰖕"
    readonly property string weatherRain:    "󰖗"
    readonly property string weatherSnow:    "󰖘"
    readonly property string weatherStorm:   "󰖓"
    readonly property string weatherFog:     "󰖑"
    readonly property string weatherNight:   "󰖔"
    readonly property string weatherDefault: "󰖐"

    // ── Actions ──
    readonly property string power:    "⏻"
    readonly property string gear:     "󰒓"
    readonly property string lock:     "󰌾"
    readonly property string logout:   "󰍃"
    readonly property string suspend:  "󰤄"
    readonly property string reboot:   "󰜉"
    readonly property string shutdown: "󰐥"
    readonly property string search:   "󰍉"
    readonly property string launch:   "󰍃"

    // ── Notifications ──
    readonly property string bell:      "󰂚"
    readonly property string bellBadge: "󰂞"
    readonly property string trash:     "󰆴"
    readonly property string dnd:       "󰂛"
    readonly property string dndOff:    "󰂚"

    // ── Misc UI ──
    readonly property string cal:       "󰃶"
    readonly property string clock:     "󰥔"
    readonly property string clipboard: "󰅍"
    readonly property string wallpaper: "󰸉"
    readonly property string cc:        "󱊖"
    readonly property string edit:      "󰏫"
    readonly property string save:      "󰆓"
    readonly property string cancel:    "󰅖"
    readonly property string drag:      "󰘕"
    readonly property string widgets:   "󰕰"
    readonly property string add:       "󰐕"
    readonly property string reset:     "󰦝"

    // ── Monitor ──
    readonly property string monitor:    "󰍹"

    // ── Caffeine ──
    readonly property string caffeine:    "󰛊"
    readonly property string caffeineOff: "󰛩"

    // ── VPN ──
    readonly property string vpnOn:    "󰖂"
    readonly property string vpnOff:   "󰖃"

    // ── Stock ──
    readonly property string stockUp:   "󰜷"
    readonly property string stockDown: "󰜮"
    readonly property string stock:     "󰄪"

    // ── Threshold helpers ──
    function volumeIcon(vol, muted) {
        if (vol < 0 || muted) return volMute;
        if (vol > 60) return volHigh;
        if (vol > 30) return volMid;
        if (vol > 0) return volLow;
        return volMute;
    }

    function brightnessIcon(pct) {
        if (pct > 66) return briHigh;
        if (pct > 33) return briMid;
        if (pct > 0)  return briLow;
        return briOff;
    }

    function batteryIcon(pct, charging) {
        if (pct < 0) return batNone;
        if (charging) return batChg;
        if (pct > 80) return bat100;
        if (pct > 60) return bat80;
        if (pct > 40) return bat60;
        if (pct > 20) return bat40;
        return bat20;
    }

    function wifiIcon(service) {
        if (!service || !service.enabled) return wifiOff;
        if (!service.connected) return wifiMin;
        if (service.iface === "ethernet") return eth;
        if (service.signal > 75) return wifiHi;
        if (service.signal > 50) return wifiMid;
        if (service.signal > 25) return wifiLow;
        return wifiMin;
    }
}
