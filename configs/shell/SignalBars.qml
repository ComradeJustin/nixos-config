import QtQuick

// Signal strength as four rising bars, for Wi-Fi: the lit ones in the
// accent colour, the rest dim.
Row {
    id: root

    // How strong the signal is, from 0 to 1.
    property real level: 0

    readonly property string bars: "▂▄▆█"
    readonly property int litBars: Math.round(Math.max(0, Math.min(1, level)) * bars.length)

    Label {
        text: root.bars.slice(0, root.litBars)
        color: Theme.accent
    }

    Label {
        text: root.bars.slice(root.litBars)
        color: Theme.line
    }
}
