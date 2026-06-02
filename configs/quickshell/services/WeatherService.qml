import Quickshell
import Quickshell.Io
import QtQuick
import ".." as Root

// Single source of truth for weather data — used by both bar and widget
Scope {
    id: svc

    property string temperature: "--"
    property int weatherCode: -1
    property string condition: ""
    property string icon: Root.Icons.weatherDefault
    property string feelsLike: ""
    // Daily forecast: array of { day, icon, hi, lo }.
    property var forecast: []
    property bool useMetric: true
    property int updateInterval: 900000  // 15 min

    property real latitude: 0
    property real longitude: 0
    property bool hasLocation: false
    property bool fetching: false
    // True after the first fetch attempt has completed (success or failure).
    // Used by bar modules to avoid showing a "degraded" dot during the
    // initial startup delay before the first fetch fires.
    property bool initialized: false

    // WMO Weather codes to icons
    function codeToIcon(code) {
        if (code === 0) return Root.Icons.weatherSunny;
        if (code === 1 || code === 2) return Root.Icons.weatherPartly;
        if (code === 3) return Root.Icons.weatherCloudy;
        if (code >= 45 && code <= 48) return Root.Icons.weatherFog;
        if (code >= 51 && code <= 67) return Root.Icons.weatherRain;
        if (code >= 71 && code <= 77) return Root.Icons.weatherSnow;
        if (code >= 80 && code <= 82) return Root.Icons.weatherRain;
        if (code >= 85 && code <= 86) return Root.Icons.weatherSnow;
        if (code >= 95 && code <= 99) return Root.Icons.weatherStorm;
        return Root.Icons.weatherDefault;
    }

    function codeToCondition(code) {
        if (code === 0) return "Clear";
        if (code === 1 || code === 2) return "Partly Cloudy";
        if (code === 3) return "Overcast";
        if (code >= 45 && code <= 48) return "Foggy";
        if (code >= 51 && code <= 67) return "Rainy";
        if (code >= 71 && code <= 77) return "Snowy";
        if (code >= 80 && code <= 82) return "Showers";
        if (code >= 85 && code <= 86) return "Snow Showers";
        if (code >= 95 && code <= 99) return "Thunderstorm";
        return "Unknown";
    }

    // Step 1: Get location from IP
    Process {
        id: geoProc
        command: ["curl", "-s", "--max-time", "5", "http://ip-api.com/json/?fields=lat,lon"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let latMatch = data.match(/"lat":\s*([-\d.]+)/);
                    let lonMatch = data.match(/"lon":\s*([-\d.]+)/);
                    if (latMatch && lonMatch) {
                        let lat = parseFloat(latMatch[1]);
                        let lon = parseFloat(lonMatch[1]);
                        if (!isNaN(lat) && !isNaN(lon) && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
                            svc.latitude = lat;
                            svc.longitude = lon;
                            svc.hasLocation = true;
                            weatherProc.running = true;
                        }
                    }
                } catch(e) {}
            }
        }
        onExited: (code) => {
            if (code !== 0 || !svc.hasLocation) {
                svc.initialized = true;
                pollTimer.start();
            }
        }
    }

    // Step 2: Get weather from Open-Meteo
    Process {
        id: weatherProc
        property string unit: svc.useMetric ? "celsius" : "fahrenheit"
        command: ["curl", "-s", "--max-time", "5",
            "https://api.open-meteo.com/v1/forecast?latitude=" + svc.latitude +
            "&longitude=" + svc.longitude +
            "&current=temperature_2m,weather_code,apparent_temperature" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min" +
            "&timezone=auto&forecast_days=5&temperature_unit=" + unit]
        stdout: SplitParser {
            onRead: data => {
                let unitSym = svc.useMetric ? "\u00b0C" : "\u00b0F";
                try {
                    let tempMatch = data.match(/"temperature_2m":\s*([-\d.]+)/);
                    let codeMatch = data.match(/"weather_code":\s*(\d+)/);
                    let feelsMatch = data.match(/"apparent_temperature":\s*([-\d.]+)/);
                    if (tempMatch) {
                        let temp = Math.round(parseFloat(tempMatch[1]));
                        svc.temperature = temp + unitSym;
                    }
                    if (codeMatch) {
                        svc.weatherCode = parseInt(codeMatch[1]);
                        svc.icon = svc.codeToIcon(svc.weatherCode);
                        svc.condition = svc.codeToCondition(svc.weatherCode);
                    }
                    if (feelsMatch) {
                        svc.feelsLike = Math.round(parseFloat(feelsMatch[1])) + unitSym;
                    }
                } catch(e) {}
                // Daily forecast \u2014 JSON-parse the arrays (regex can't do arrays).
                try {
                    let j = JSON.parse(data);
                    if (j && j.daily && j.daily.time) {
                        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                        let t = j.daily.time;
                        let codes = j.daily.weather_code || [];
                        let hi = j.daily.temperature_2m_max || [];
                        let lo = j.daily.temperature_2m_min || [];
                        let out = [];
                        for (let i = 0; i < Math.min(t.length, 5); i++) {
                            let d = new Date(t[i] + "T00:00:00");
                            out.push({
                                day: i === 0 ? "Today" : names[d.getDay()],
                                icon: svc.codeToIcon(codes[i]),
                                hi: Math.round(hi[i]),
                                lo: Math.round(lo[i])
                            });
                        }
                        svc.forecast = out;
                    }
                } catch(e) {}
            }
        }
        onExited: {
            svc.fetching = false;
            svc.initialized = true;
            pollTimer.start();
        }
    }

    function fetchWeather() {
        if (svc.fetching) return;
        svc.fetching = true;
        if (svc.hasLocation) weatherProc.running = true;
        else geoProc.running = true;
    }

    Timer {
        id: startTimer
        interval: 1500
        running: true
        onTriggered: svc.fetchWeather()
    }

    Timer {
        id: pollTimer
        interval: svc.updateInterval
        onTriggered: svc.fetchWeather()
    }
}
