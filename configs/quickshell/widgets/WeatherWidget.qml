import QtQuick
import Quickshell.Io
import ".." as Root

// Background weather widget with temperature and conditions
Item {
    id: root

    // Config properties
    property bool useMetric: true
    property int fontSize: 32

    implicitWidth: content.implicitWidth + Root.Theme.widgetPadding * 2
    implicitHeight: content.implicitHeight + Root.Theme.widgetPadding * 2

    // Weather state
    property real latitude: 0
    property real longitude: 0
    property string temperature: "--"
    property int weatherCode: -1
    property string weatherIcon: Root.Theme.iconWeatherDefault
    property string condition: ""
    property bool hasLocation: false
    property bool fetching: false

    // WMO Weather codes to icons
    function codeToIcon(code) {
        if (code === 0) return Root.Theme.iconWeatherSunny;
        if (code === 1 || code === 2) return Root.Theme.iconWeatherPartly;
        if (code === 3) return Root.Theme.iconWeatherCloudy;
        if (code >= 45 && code <= 48) return Root.Theme.iconWeatherFog;
        if (code >= 51 && code <= 67) return Root.Theme.iconWeatherRain;
        if (code >= 71 && code <= 77) return Root.Theme.iconWeatherSnow;
        if (code >= 80 && code <= 82) return Root.Theme.iconWeatherRain;
        if (code >= 85 && code <= 86) return Root.Theme.iconWeatherSnow;
        if (code >= 95 && code <= 99) return Root.Theme.iconWeatherStorm;
        return Root.Theme.iconWeatherDefault;
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

    // Geolocation process
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
                        // Validate coordinates are in valid range
                        if (!isNaN(lat) && !isNaN(lon) && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
                            root.latitude = lat;
                            root.longitude = lon;
                            root.hasLocation = true;
                            weatherProc.running = true;
                        }
                    }
                } catch(e) {}
            }
        }
        onExited: (code) => {
            if (code !== 0 || !root.hasLocation) pollTimer.start();
        }
    }

    // Weather API process
    Process {
        id: weatherProc
        property string unit: root.useMetric ? "celsius" : "fahrenheit"
        command: ["curl", "-s", "--max-time", "5",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude +
            "&longitude=" + root.longitude +
            "&current=temperature_2m,weather_code&temperature_unit=" + unit]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let tempMatch = data.match(/"temperature_2m":\s*([-\d.]+)/);
                    let codeMatch = data.match(/"weather_code":\s*(\d+)/);
                    if (tempMatch) {
                        let temp = Math.round(parseFloat(tempMatch[1]));
                        root.temperature = temp + (root.useMetric ? "°C" : "°F");
                    }
                    if (codeMatch) {
                        root.weatherCode = parseInt(codeMatch[1]);
                        root.weatherIcon = root.codeToIcon(root.weatherCode);
                        root.condition = root.codeToCondition(root.weatherCode);
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
        if (root.hasLocation) weatherProc.running = true;
        else geoProc.running = true;
    }

    Timer {
        id: startTimer
        interval: 2000
        running: true
        onTriggered: root.fetchWeather()
    }

    Timer {
        id: pollTimer
        interval: Root.Config.weatherUpdateInterval
        onTriggered: root.fetchWeather()
    }

    // Shadow layer
    Rectangle {
        anchors.fill: bg
        anchors.margins: -2
        anchors.topMargin: 2
        radius: Root.Theme.widgetRadius + 2
        color: Root.Theme.widgetShadowColor
        opacity: 0.4
    }

    // Widget background
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Root.Theme.widgetRadius
        color: Root.Theme.widgetBackground
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 12

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.weatherIcon
            color: Root.Theme.widgetText
            font {
                family: Root.Theme.fontIcons
                pixelSize: root.fontSize * 1.2
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: root.temperature
                color: Root.Theme.widgetText
                font {
                    family: Root.Theme.fontMono
                    pixelSize: root.fontSize
                    bold: true
                }
            }

            Text {
                text: root.condition
                color: Root.Theme.widgetTextDimmed
                font {
                    family: Root.Theme.fontFamily
                    pixelSize: Math.round(root.fontSize * 0.4)
                }
            }
        }
    }
}
