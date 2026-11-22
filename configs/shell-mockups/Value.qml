import QtQuick

// A value that can change while it is on screen, such as the volume number.
// Each time its text changes it shows in bright reverse video for a moment
// (Theme.flashMs), the way a terminal marks a cell it has just rewritten.
Label {
    id: value

    color: flash.running ? Theme.slab : Theme.ink

    onTextChanged: flash.restart()

    // The reverse-video background, drawn behind the text.
    Rectangle {
        anchors.fill: parent
        z: -1
        visible: flash.running
        color: Theme.ink
    }

    // Runs for as long as the flash lasts.
    Timer {
        id: flash

        interval: Theme.flashMs
    }
}
