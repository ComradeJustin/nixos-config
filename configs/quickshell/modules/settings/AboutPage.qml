import QtQuick
import Quickshell.Io
import "../.." as Root

// About page — hero title, config path, open-folder action.
Column {
    width: parent ? parent.width : 0
    spacing: 24

    // Hero block
    Column {
        width: parent.width
        spacing: 6
        topPadding: 12

        Text {
            text: "QuickShell"
            color: Root.Theme.textPrimary
            font {
                family: Root.Theme.fontFamily
                pixelSize: 28
                bold: true
            }
        }
        Text {
            text: "Desktop Shell for Niri"
            color: Root.Theme.textDimmed
            font {
                family: Root.Theme.fontFamily
                pixelSize: Root.Theme.fontSizeLarge
            }
        }
    }

    // Info block
    Rectangle {
        width: parent.width
        height: infoCol.implicitHeight + 24
        radius: Root.Theme.radiusMedium
        color: Qt.rgba(Root.Theme.base01.r, Root.Theme.base01.g, Root.Theme.base01.b, 0.6)
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor

        Column {
            id: infoCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            spacing: 8

            // Config path row
            Row {
                spacing: 8
                width: parent.width

                Text {
                    text: "Config path"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                    width: 90
                }
                Text {
                    text: Root.Theme.configBase + "/configs/quickshell"
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeSmall }
                    elide: Text.ElideLeft
                    width: parent.width - 98
                }
            }

            // Theming row
            Row {
                spacing: 8
                width: parent.width

                Text {
                    text: "Theming"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                    width: 90
                }
                Text {
                    text: "Base16 / Stylix"
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
                }
            }
        }
    }

    // Open config button
    Rectangle {
        width: parent.width
        height: 36
        radius: Root.Theme.radiusSmall
        color: openMouse.containsMouse
            ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.18)
            : Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.10)
        border.width: Root.Theme.borderWidth
        border.color: Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.3)

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: Root.Icons.edit + "  Open Config Folder"
            color: Root.Theme.accentPrimary
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSize }
        }

        MouseArea {
            id: openMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: openConfigProc.running = true
        }
    }

    Item { width: 1; height: 8 }

    // Process: open the config folder in xdg-open.
    Process {
        id: openConfigProc
        command: [
            "xdg-open",
            Root.Theme.configBase + "/configs/quickshell"
        ]
    }
}
