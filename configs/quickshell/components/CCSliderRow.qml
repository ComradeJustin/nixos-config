import QtQuick
import ".." as Root

// CCSliderRow — Control Center style slider row.
//
// Rounded rectangle "pill" containing a leading icon (optionally clickable),
// a SliderBar, and a trailing value label. Used by the Control Center volume
// and brightness rows so they share identical spacing, typography and
// background color rather than each rolling its own bespoke layout.
//
// Typical usage:
//     CCSliderRow {
//         icon: Root.Icons.volHigh
//         iconColor: Root.Theme.domainMedia
//         accentColor: Root.Theme.domainMedia
//         value: audioService.volume
//         iconClickable: true
//         onIconClicked: audioService.toggleMute()
//         onValueUpdated: v => audioService.setVolume(Math.round(v))
//     }
Rectangle {
    id: row

    // ── Public API ──
    property string icon: ""
    property color iconColor: Root.Theme.textPrimary
    property color accentColor: Root.Theme.textAccent
    property real value: 0
    property real minValue: 0
    property real maxValue: 100
    property string suffix: "%"
    property bool iconClickable: false

    signal iconClicked()
    signal valueUpdated(real newValue)

    // Fixed row height keeps every CC slider aligned to the same vertical
    // rhythm regardless of which sliders are visible.
    implicitHeight: 40
    radius: Root.Theme.ccSectionRadius
    color: Root.Theme.ccSectionBg

    Row {
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        spacing: 8

        // Leading icon. When iconClickable is true it picks up a hover
        // highlight + pointer cursor and emits iconClicked(); otherwise it
        // renders as a plain decorative glyph with no interaction area.
        Rectangle {
            id: iconWrap
            width: 24; height: 24
            radius: Root.Theme.radiusSmall
            anchors.verticalCenter: parent.verticalCenter
            color: (row.iconClickable && iconMouse.containsMouse)
                ? Qt.rgba(Root.Theme.textPrimary.r,
                          Root.Theme.textPrimary.g,
                          Root.Theme.textPrimary.b, 0.1)
                : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: row.icon
                color: row.iconColor
                font { family: Root.Theme.fontFamily; pixelSize: 16 }
            }

            MouseArea {
                id: iconMouse
                anchors.fill: parent
                enabled: row.iconClickable
                hoverEnabled: row.iconClickable
                cursorShape: row.iconClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: row.iconClicked()
            }
        }

        // The slider takes the middle — width is parent minus icon(24) minus
        // trailing value label(32) minus both 8px gaps between children.
        //
        // The Binding { when: !bar.dragging } is the classic anti-feedback
        // pattern: while the user is dragging, external value updates from
        // the service are suppressed so the thumb doesn't fight the finger.
        // As soon as the drag ends the binding reactivates and any drift
        // (e.g. service clamping) is reconciled.
        SliderBar {
            id: bar
            width: parent.width - iconWrap.width - valueLabel.width - 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            accentColor: row.accentColor
            trackHeight: 3
            handleSize: 12
            minValue: row.minValue
            maxValue: row.maxValue
            onValueUpdated: newValue => row.valueUpdated(newValue)

            Binding {
                target: bar
                property: "value"
                value: row.value
                when: !bar.dragging
            }
        }

        Text {
            id: valueLabel
            text: Math.round(row.value) + row.suffix
            color: Root.Theme.textPrimary
            font { family: Root.Theme.fontFamily; pixelSize: 11 }
            width: 32
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
        }
    }
}
