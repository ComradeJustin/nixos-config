import QtQuick
import ".." as Root

// Canvas-based line graph with fill.
// Pass normalized values (0-1) in the `values` array.
//
// Usage:
//   Graph {
//       width: 60; height: 20
//       values: cpuHistory  // array of 0-1 floats
//       lineColor: Theme.accentPrimary
//   }
Canvas {
    id: graph

    property var values: []           // Array of normalized values (0-1)
    property color lineColor: Root.Theme.accentPrimary
    property color fillColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.15)
    property real lineWidth: 1.5
    property bool alignRight: true    // true = newest values on right

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        let ctx = getContext("2d");
        let w = width, h = height;
        ctx.clearRect(0, 0, w, h);

        let vals = values;
        if (!vals || vals.length < 2) return;

        let count = vals.length;
        let step = w / (count - 1);

        // Build path
        ctx.beginPath();
        for (let i = 0; i < count; i++) {
            let x = alignRight ? w - (count - 1 - i) * step : i * step;
            let y = h - Math.max(0, Math.min(1, vals[i])) * h;
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }

        // Stroke the line
        ctx.strokeStyle = lineColor;
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "round";
        ctx.stroke();

        // Fill under the line
        let lastX = alignRight ? w : (count - 1) * step;
        let firstX = alignRight ? w - (count - 1) * step : 0;
        ctx.lineTo(lastX, h);
        ctx.lineTo(firstX, h);
        ctx.closePath();
        ctx.fillStyle = fillColor;
        ctx.fill();
    }
}
