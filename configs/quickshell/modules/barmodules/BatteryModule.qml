import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

// BatteryModule — bar surface for battery state.
// Polling lives in PowerService; this module is a pure read view.
Components.BarItem {
    id: root
    custom: true
    accent: root.activeColor
    visible: hasBattery

    readonly property var svc: Core.ServiceManager.power
    readonly property int capacity: svc ? svc.capacity : -1
    readonly property bool charging: svc ? svc.charging : false
    readonly property bool pluggedIn: svc ? svc.pluggedIn : false
    readonly property bool hasBattery: svc ? svc.hasBattery : false

    tooltipText: {
        if (!hasBattery) return "";
        let tip = capacity + "%";
        if (charging) tip += " · Charging";
        else if (pluggedIn) tip += " · Plugged in";
        else tip += " · On battery";
        return tip;
    }

    property color activeColor: root.pluggedIn
        ? Root.Theme.barBatteryCharge
        : (root.capacity >= 0 && root.capacity <= 15
           ? Root.Theme.barBatteryLow : Root.Theme.domainPower)

    // Secondary color for gradient arc
    property color arcEndColor: root.pluggedIn
        ? Qt.lighter(Root.Theme.barBatteryCharge, 1.4)
        : (root.capacity >= 0 && root.capacity <= 15
           ? Qt.lighter(Root.Theme.barBatteryLow, 1.3) : Qt.lighter(Root.Theme.domainPower, 1.4))

    // Battery ring with gradient arc and segments
    Item {
        implicitWidth: 22; implicitHeight: 22
        anchors.verticalCenter: parent.verticalCenter

        Canvas {
            id: batteryRing
            anchors.fill: parent
            property real animatedCapacity: root.capacity
            property real waveOffset: 0

            Behavior on animatedCapacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

            onAnimatedCapacityChanged: requestPaint()
            onWaveOffsetChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                let ctx = getContext("2d");
                let w = width, h = height;
                let cx = w / 2, cy = h / 2;
                let r = (Math.min(w, h) - 3) / 2;
                let lineWidth = 2.5;
                let startAngle = -Math.PI / 2;
                let pct = Math.max(0, Math.min(100, animatedCapacity)) / 100;

                ctx.clearRect(0, 0, w, h);

                // Background track — segmented ticks
                let segments = 12;
                let gapAngle = 0.08;
                let segAngle = (2 * Math.PI - segments * gapAngle) / segments;
                ctx.lineWidth = 1.5;
                ctx.strokeStyle = Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.12);
                for (let i = 0; i < segments; i++) {
                    let a0 = startAngle + i * (segAngle + gapAngle);
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, a0, a0 + segAngle);
                    ctx.stroke();
                }

                // Fill arc — gradient from activeColor to arcEndColor
                if (pct > 0) {
                    let endAngle = startAngle + pct * 2 * Math.PI;

                    // Create gradient along the arc direction
                    let grd = ctx.createLinearGradient(
                        cx + r * Math.cos(startAngle), cy + r * Math.sin(startAngle),
                        cx + r * Math.cos(endAngle), cy + r * Math.sin(endAngle)
                    );
                    grd.addColorStop(0, root.activeColor);
                    grd.addColorStop(1, root.arcEndColor);

                    ctx.beginPath();
                    ctx.arc(cx, cy, r, startAngle, endAngle);
                    ctx.lineWidth = lineWidth;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = grd;
                    ctx.stroke();

                    // End dot — bright cap at the arc tip
                    let dotX = cx + r * Math.cos(endAngle);
                    let dotY = cy + r * Math.sin(endAngle);
                    ctx.beginPath();
                    ctx.arc(dotX, dotY, 1.5, 0, 2 * Math.PI);
                    ctx.fillStyle = root.arcEndColor;
                    ctx.fill();
                }

                // Charging wave effect — subtle inner ripple
                if (root.charging && pct > 0) {
                    let waveR = r - 3;
                    ctx.beginPath();
                    ctx.arc(cx, cy, waveR, startAngle, startAngle + pct * 2 * Math.PI);
                    ctx.lineWidth = 1;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b,
                        0.15 + 0.15 * Math.sin(waveOffset));
                    ctx.stroke();
                }
            }
        }

        // Charging wave animation
        NumberAnimation {
            target: batteryRing; property: "waveOffset"
            from: 0; to: Math.PI * 2
            duration: 2000; loops: Animation.Infinite
            running: root.charging
        }

        // Battery/charging icon centered in ring
        Text {
            anchors.centerIn: parent
            text: root.charging ? Root.Icons.batChg : Root.Icons.batteryIcon(root.capacity, false)
            color: root.activeColor
            font { family: Root.Theme.fontMono; pixelSize: 8 }

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
        font { family: Root.Theme.fontMono; pixelSize: Root.Theme.iconSize }
        anchors.verticalCenter: parent.verticalCenter
    }
}
