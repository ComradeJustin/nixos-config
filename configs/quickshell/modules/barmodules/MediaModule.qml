import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../.." as Root

// Media player indicator with scrolling text.
// Click to toggle cava visualizer (handled by parent).
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: theme.barHeight

    Root.Theme { id: theme }

    property int maxTextWidth: 200
    property real scrollSpeed: 30

    signal cavaToggled()

    property var player: {
        let players = Mpris.players.values;
        if (!players || players.length === 0) return null;
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i];
        }
        return players[0];
    }

    property bool isPlaying: player ? player.playbackState === MprisPlaybackState.Playing : false
    property string mediaText: {
        if (!player) return "";
        let title = player.trackTitle || "";
        let artist = player.trackArtist || "";
        if (title.length === 0) return "";
        if (artist.length > 0) return artist + " — " + title;
        return title;
    }

    visible: mediaText.length > 0

    Row {
        id: row
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        height: theme.barHeight

        // ── Play/pause icon ──
        Text {
            text: root.isPlaying ? theme.iconMediaPlay : theme.iconMediaPause
            color: theme.textAccent
            font { family: theme.fontFamily; pixelSize: theme.iconSize }
            height: theme.barHeight
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.player && root.player.canTogglePlaying)
                        root.player.isPlaying = !root.player.isPlaying;
                }
            }
        }

        // ── Scrolling text area ──
        Item {
            id: textContainer
            width: Math.min(innerText.implicitWidth, root.maxTextWidth)
            height: theme.barHeight
            clip: true

            property bool needsScroll: innerText.implicitWidth > root.maxTextWidth

            Row {
                id: scrollRow
                x: 0
                height: theme.barHeight

                Text {
                    id: innerText
                    text: root.mediaText
                    color: theme.textDimmed
                    font {
                        family: theme.fontFamily
                        pixelSize: theme.fontSize
                        bold: theme.fontBold
                    }
                    height: theme.barHeight
                    verticalAlignment: Text.AlignVCenter
                }

                Item { width: 40; height: 1; visible: textContainer.needsScroll }

                Text {
                    text: root.mediaText
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
                running: textContainer.needsScroll && root.isPlaying
            }

            Connections {
                target: root
                function onMediaTextChanged() {
                    scrollAnim.stop();
                    scrollRow.x = 0;
                    if (textContainer.needsScroll && root.isPlaying)
                        scrollAnim.start();
                }
                function onIsPlayingChanged() {
                    if (!root.isPlaying) {
                        scrollAnim.stop();
                        scrollRow.x = 0;
                    } else if (textContainer.needsScroll) {
                        scrollAnim.start();
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cavaToggled()
            }
        }
    }
}
