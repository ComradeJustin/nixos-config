import QtQuick
import Quickshell.Io
import "../.." as Root

Item {
    id: root
    implicitWidth: hasBattery ? row.implicitWidth : 0
    implicitHeight: row.implicitHeight
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

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        // Canvas battery ring
        Item {
            width: 22; height: 22
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: batteryRing
                anchors.fill: parent
                property real animatedCapacity: root.capacity
                property real chargeGlow: 1.0

                Behavior on animatedCapacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                onAnimatedCapacityChanged: requestPaint()
                onChargeGlowChanged: requestPaint()

                onPaint: {
                    let ctx = getContext("2d");
                    let w = width, h = height;
                    let cx = w / 2, cy = h / 2;
                    let r = (Math.min(w, h) - 4) / 2;
                    let lineWidth = 2.5;
                    let startAngle = -Math.PI / 2;
                    let pct = Math.max(0, Math.min(100, animatedCapacity)) / 100;

                    ctx.clearRect(0, 0, w, h);

                    // Background track
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.lineWidth = lineWidth;
                    ctx.strokeStyle = Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.2);
                    ctx.stroke();

                    // Fill arc
                    if (pct > 0) {
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, startAngle, startAngle + pct * 2 * Math.PI);
                        ctx.lineWidth = lineWidth;
                        ctx.lineCap = "round";
                        let alpha = root.charging ? chargeGlow : 1.0;
                        ctx.strokeStyle = Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, alpha);
                        ctx.stroke();
                    }
                }
            }

            // Percentage text inside ring
            Text {
                anchors.centerIn: parent
                text: root.capacity >= 0 ? root.capacity : "--"
                color: root.activeColor
                font { family: Root.Theme.fontFamily; pixelSize: root.capacity >= 100 ? 6 : 7; bold: true }
                opacity: lowBlink.running ? lowBlinkAnim.opacity : 1.0
            }

            // Charging pulse animation
            SequentialAnimation on opacity {
                id: chargePulse
                running: root.charging
                loops: Animation.Infinite
                NumberAnimation { target: batteryRing; property: "chargeGlow"; from: 1.0; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { target: batteryRing; property: "chargeGlow"; from: 0.4; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }

            // Low battery blink
            SequentialAnimation {
                id: lowBlink
                running: root.capacity >= 0 && root.capacity <= 15 && !root.charging
                loops: Animation.Infinite

                NumberAnimation { id: lowBlinkAnim; target: lowBlinkAnim; property: "opacity"; from: 1.0; to: 0.3; duration: 600 }
                NumberAnimation { target: lowBlinkAnim; property: "opacity"; from: 0.3; to: 1.0; duration: 600 }

                property real opacity: 1.0
            }
        }

        Text {
            visible: root.pluggedIn && !root.charging
            text: Root.Icons.plug
            color: Root.Theme.barBatteryCharge
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Check if battery device exists
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
