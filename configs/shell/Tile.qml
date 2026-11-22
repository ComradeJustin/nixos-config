import QtQuick

// One applet's tile: a small panel with the applet's title and its four
// lines of summary. Used on the desktop, for the playing track. An applet
// in trouble has its border and title in the alert colour.
Panel {
    // The applet shown: { title, summary, alert }.
    property var applet: null

    readonly property bool inTrouble: applet !== null && applet.alert === true

    columns: 40
    valueColumn: 10
    levelCells: 16
    page: applet
    entries: applet ? applet.summary : []
    // Nothing in a tile is selected.
    selectedIndex: -1
    footer: ""
    titleColor: inTrouble ? Theme.alert : Theme.ink
    lineColor: inTrouble ? Theme.alert : Theme.line
}
