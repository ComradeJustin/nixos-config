import QtQuick
import ".." as Root

Item {
    id: root

    property string label: ""
    property real value: 0
    property real minValue: 0
    property real maxValue: 100
    property int decimals: 0
    property string suffix: ""
    property color accent: Root.Theme.textAccent

    signal sliderUpdated(real newValue)

    width: parent ? parent.width : 200
    height: 36

    Text {
        id: labelText
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: root.label
        color: Root.Theme.textPrimary
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
    }

    Text {
        id: valueText
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        text: root.value.toFixed(root.decimals) + root.suffix
        color: Root.Theme.textPrimary
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize; bold: true }
    }

    SliderBar {
        anchors {
            left: labelText.right; leftMargin: Root.Theme.spacingM
            right: valueText.left; rightMargin: Root.Theme.spacingM
            verticalCenter: parent.verticalCenter
        }
        value: root.value
        minValue: root.minValue
        maxValue: root.maxValue
        accentColor: root.accent
        trackHeight: 3
        handleSize: 10

        onValueUpdated: newValue => {
            if (newValue >= root.minValue && newValue <= root.maxValue)
                root.sliderUpdated(newValue);
        }
    }
}
