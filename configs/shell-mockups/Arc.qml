import QtQuick
import QtQuick.Shapes

// A circular gauge: a faint full track with a lit arc on top of it.
// The arc starts at 12 o'clock and runs clockwise.
Shape {
    id: root

    // How much of the circle is lit, from 0 to 1.
    property real level: 0
    property real thickness: 4
    property color litColor: Theme.accent
    property color trackColor: Theme.stroke

    readonly property real arcRadius: Math.min(width, height) / 2 - thickness / 2

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: root.trackColor
        strokeWidth: root.thickness
        fillColor: "transparent"

        PathAngleArc {
            centerX: root.width / 2
            centerY: root.height / 2
            radiusX: root.arcRadius
            radiusY: root.arcRadius
            startAngle: -90
            sweepAngle: 360
        }
    }

    ShapePath {
        strokeColor: root.litColor
        strokeWidth: root.thickness
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap

        PathAngleArc {
            centerX: root.width / 2
            centerY: root.height / 2
            radiusX: root.arcRadius
            radiusY: root.arcRadius
            startAngle: -90
            sweepAngle: 360 * Math.max(0, Math.min(1, root.level))
        }
    }
}
