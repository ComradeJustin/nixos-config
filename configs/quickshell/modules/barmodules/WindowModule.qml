import QtQuick
import QtQuick.Layouts
import Niri 0.1
import "../.." as Root

// Shows focused window with "AppName - Title" format.
// Overflowing text scrolls like the media module.
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: theme.barHeight

    Root.Theme { id: theme }

    property int maxTextWidth: 180
    property real scrollSpeed: 30

    Niri {
        id: niri
        Component.onCompleted: connect()
        onErrorOccurred: function(error) {
            console.warn("WindowModule: niri error:", error);
        }
    }

    property string appId:       niri.focusedWindow?.appId ?? ""
    property string windowTitle: niri.focusedWindow?.title ?? ""
    property string windowIcon:  niri.focusedWindow?.iconPath ?? ""

    // Format: "AppName - Title"
    property string displayText: {
        if (windowTitle.length === 0) return "";
        let app = appId;
        // Clean up app ID: "com.mitchellh.ghostty" -> "Ghostty"
        if (app.indexOf(".") !== -1) {
            let parts = app.split(".");
            app = parts[parts.length - 1];
        }
        // Capitalize first letter
        if (app.length > 0)
            app = app.charAt(0).toUpperCase() + app.substring(1);

        if (app.length > 0 && windowTitle.indexOf(app) === -1)
            return app + " — " + windowTitle;
        return windowTitle;
    }

    visible: displayText.length > 0

    Row {
        id: row
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        height: theme.barHeight

        Image {
            source: root.windowIcon.length > 0 ? "file://" + root.windowIcon : ""
            sourceSize.width: theme.iconSize
            sourceSize.height: theme.iconSize
            width: theme.iconSize
            height: theme.iconSize
            visible: root.windowIcon.length > 0
            smooth: true
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            id: textContainer
            width: Math.min(innerText.implicitWidth, root.maxTextWidth)
            height: theme.barHeight
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            property bool needsScroll: innerText.implicitWidth > root.maxTextWidth

            Row {
                id: scrollRow
                x: 0
                height: theme.barHeight

                Text {
                    id: innerText
                    text: root.displayText
                    color: theme.textDimmed
                    font { family: theme.fontFamily; pixelSize: theme.fontSize; bold: theme.fontBold }
                    height: theme.barHeight
                    verticalAlignment: Text.AlignVCenter
                }

                Item { width: 40; height: 1; visible: textContainer.needsScroll }

                Text {
                    text: root.displayText
                    color: theme.textDimmed
                    font: innerText.font
                    height: theme.barHeight
                    verticalAlignment: Text.AlignVCenter
                    visible: textContainer.needsScroll
                }
            }

            NumberAnimation {
                id: scrollAnim
                target: scrollRow
                property: "x"
                from: 0
                to: -(innerText.implicitWidth + 40)
                duration: (innerText.implicitWidth + 40) / root.scrollSpeed * 1000
                loops: Animation.Infinite
                running: textContainer.needsScroll
            }

            Connections {
                target: root
                function onDisplayTextChanged() {
                    scrollAnim.stop();
                    scrollRow.x = 0;
                    if (textContainer.needsScroll)
                        scrollAnim.start();
                }
            }
        }
    }
}
