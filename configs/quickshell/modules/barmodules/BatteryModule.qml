import QtQuick
import Quickshell.Io
import "../.." as Root
import "../../components" as Components

Components.BarItem {
    id: root
    custom: true
    accent: root.activeColor
    visible: hasBattery

    property string device: "BAT0"
    property int capacity: -1
    property bool charging: false
    property bool pluggedIn: false
    property bool hasBattery: false

    property color activeColor: root.pluggedIn
        ? Root.Theme.barBatteryCharge
        : (root.capacity >= 0 && root.capacity <= 15
           ? Root.Theme.barBatteryLow : Root.Theme.domainPower)

    // Battery icon inside ring
    Item {
        implicitWidth: 20; implicitHeight: 20
        anchors.verticalCenter: parent.verticalCenter

        Canvas {
            id: batteryRing
            anchors.fill: parent
            property real animatedCapacity: root.capacity

            Behavior on animatedCapacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            onAnimatedCapacityChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                let ctx = getContext("2d");
                let w = width, h = height;
                let cx = w / 2, cy = h / 2;
                let r = (Math.min(w, h) - 3) / 2;
                let lineWidth = 2;
                let startAngle = -Math.PI / 2;
                let pct = Math.max(0, Math.min(100, animatedCapacity)) / 100;

                ctx.clearRect(0, 0, w, h);

                // Background track
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.lineWidth = lineWidth;
                ctx.strokeStyle = Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.15);
                ctx.stroke();

                // Fill arc
                if (pct > 0) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, startAngle, startAngle + pct * 2 * Math.PI);
                    ctx.lineWidth = lineWidth;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = root.activeColor;
                    ctx.stroke();
                }
            }
        }

        // Battery/charging icon centered in ring
        Text {
            anchors.centerIn: parent
            text: root.charging ? Root.Icons.batChg : Root.Icons.batteryIcon(root.capacity, false)
            color: root.activeColor
            font { family: Root.Theme.fontFamily; pixelSize: 9 }

            // Charging pulse
            SequentialAnimation on opacity {
                running: root.charging
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }
        }
    }

    // Percentage text outside the ring
    Text {
        text: root.capacity >= 0 ? root.capacity + "%" : "--"
        color: root.activeColor
        font: root.valueFont
        anchors.verticalCenter: parent.verticalCenter

        // Low battery blink
        SequentialAnimation on opacity {
            running: root.capacity >= 0 && root.capacity <= 15 && !root.charging
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
        }
    }

    // Plug icon when connected but not charging (full)
    Text {
        visible: root.pluggedIn && !root.charging
        text: Root.Icons.plug
        color: Root.Theme.barBatteryCharge
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
        anchors.verticalCenter: parent.verticalCenter
    }

    // ── Battery detection & polling ──
    Process {
        id: detectProc
        command: ["test", "-d", "/sys/class/power_supply/" + root.device]
        running: true
        onExited: function(exitCode) {
            root.hasBattery = (exitCode === 0);
            if (root.hasBattery) {
                capProc.running = true;
                statusProc.running = true;
            }
        }
    }

    Process {
        id: capProc
        command: ["cat", "/sys/class/power_supply/" + root.device + "/capacity"]
        stdout: SplitParser {
            onRead: data => {
                let val = parseInt(data);
                if (!isNaN(val)) root.capacity = val;
            }
        }
        onExited: pollTimer.start()
    }

    Process {
        id: statusProc
        command: ["cat", "/sys/class/power_supply/" + root.device + "/status"]
        stdout: SplitParser {
            onRead: data => {
                root.charging = (data === "Charging");
                root.pluggedIn = (data === "Charging" || data === "Not charging" || data === "Full");
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 5000
        onTriggered: {
            if (root.hasBattery) {
                capProc.running = true;
                statusProc.running = true;
            }
        }
    }
}
