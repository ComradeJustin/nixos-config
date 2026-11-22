import QtQuick

// A word in a reverse-video block, with a space before it: something is on
// that should not be missed, such as the microphone or caps lock.
Row {
    id: flag

    property string word: ""
    property color blockColor: Theme.alert

    Label {
        text: " "
    }

    Rectangle {
        width: flagWord.width
        height: Theme.cellHeight
        color: flag.blockColor

        Label {
            id: flagWord

            text: " " + flag.word + " "
            color: Theme.slab
            smallCaps: true
        }
    }
}
