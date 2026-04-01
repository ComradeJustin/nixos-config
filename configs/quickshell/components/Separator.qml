import QtQuick
import ".." as Root

// Separator line for control center tabs, lists, and bar modules.
// Set vertical: true for bar separator use.
Rectangle {
    property bool vertical: false

    width: vertical ? 1 : (parent ? parent.width : 100)
    height: vertical ? 14 : 1
    color: Root.Theme.textDimmed
    opacity: 0.15
}
