import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.." as Root

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Theme is now a singleton - access via Root.Theme.propertyName

    // Set your coordinates (default: auto-detect via ip-api)
    property real latitude: 0
    property real longitude: 0
    property string temperature: "--"
    property int weatherCode: -1
    property string weatherIcon: Root.Theme.iconWeatherDefault
    property bool fetching: false
    property bool hasLocation: false

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: root.weatherIcon
            color: Root.Theme.domainWeather
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.temperature
            color: Root.Theme.domainWeather
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: true }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // WMO Weather codes to icons
    function codeToIcon(code) {
        // Clear
        if (code === 0) return Root.Theme.iconWeatherSunny;
        // Partly cloudy
        if (code === 1 || code === 2) return Root.Theme.iconWeatherPartly;
        // Overcast
        if (code === 3) return Root.Theme.iconWeatherCloudy;
        // Fog
        if (code >= 45 && code <= 48) return Root.Theme.iconWeatherFog;
        // Drizzle / Rain
        if (code >= 51 && code <= 67) return Root.Theme.iconWeatherRain;
        // Snow
        if (code >= 71 && code <= 77) return Root.Theme.iconWeatherSnow;
        // Showers
        if (code >= 80 && code <= 82) return Root.Theme.iconWeatherRain;
        // Snow showers
        if (code >= 85 && code <= 86) return Root.Theme.iconWeatherSnow;
        // Thunderstorm
        if (code >= 95 && code <= 99) return Root.Theme.iconWeatherStorm;
        return Root.Theme.iconWeatherDefault;
    }

    // Step 1: Get location from IP
    Process {
        id: geoProc
        command: ["curl", "-s", "--max-time", "5", "http://ip-api.com/json/?fields=lat,lon"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    var latMatch = data.match(/"lat":\s*([-\d.]+)/);
                    var lonMatch = data.match(/"lon":\s*([-\d.]+)/);
                    if (latMatch && lonMatch) {
                        root.latitude = parseFloat(latMatch[1]);
                        root.longitude = parseFloat(lonMatch[1]);
                        root.hasLocation = true;
                        weatherProc.running = true;
                    }
                } catch(e) {}
            }
        }

        onExited: {
            if (!root.hasLocation) {
                // Fallback: try again later
                pollTimer.start();
            }
        }
    }

    // Step 2: Get weather from Open-Meteo
    Process {
        id: weatherProc
        command: ["curl", "-s", "--max-time", "5",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude +
            "&longitude=" + root.longitude +
            "&current=temperature_2m,weather_code&temperature_unit=celsius"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    var tempMatch = data.match(/"temperature_2m":\s*([-\d.]+)/);
                    var codeMatch = data.match(/"weather_code":\s*(\d+)/);
                    if (tempMatch) {
                        root.temperature = Math.round(parseFloat(tempMatch[1])) + "°C";
                    }
                    if (codeMatch) {
                        root.weatherCode = parseInt(codeMatch[1]);
                        root.weatherIcon = root.codeToIcon(root.weatherCode);
                    }
                } catch(e) {}
            }
        }

        onExited: {
            root.fetching = false;
            pollTimer.start();
        }
    }

    function fetchWeather() {
        if (root.fetching) return;
        root.fetching = true;
        if (root.hasLocation) {
            weatherProc.running = true;
        } else {
            geoProc.running = true;
        }
    }

    // Initial delay before first fetch
    Timer {
        id: startTimer
        interval: 1000
        running: true
        onTriggered: root.fetchWeather()
    }

    Timer {
        id: pollTimer
        interval: 900000  // Update every 15 minutes
        onTriggered: root.fetchWeather()
    }
}
