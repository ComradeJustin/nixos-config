import QtQuick

// A busy mark for something that is in progress: the font's six spinner
// characters shown in turn. It only runs while it is on screen.
Label {
    id: spinner

    readonly property string frames: ""
    property int frame: 0

    text: frames[frame]
    color: Theme.accent

    Timer {
        interval: Theme.spinMs
        repeat: true
        running: spinner.visible
        onTriggered: spinner.frame = (spinner.frame + 1) % spinner.frames.length
    }
}
