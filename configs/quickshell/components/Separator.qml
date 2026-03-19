import QtQuick
import ".." as Root

// Horizontal separator line for control center tabs and lists
Rectangle {
    width: parent ? parent.width : 100
    height: 1
    color: Root.Theme.textDimmed
    opacity: 0.15
}
