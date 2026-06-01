import QtQuick
import QtQuick.Effects
import "../../.." as Root
import "../../../components" as Components
import "../../../core" as Core

// PlayerCard — the Control Center's media showpiece.
//
// Visual layers (back → front):
//   1. Solid base color (ccSectionBg)           — fallback before art loads
//   2. Blurred album art via MultiEffect.blur   — hero background
//   3. Dark scrim                               — readability
//   4. Subtle top border stroke                 — separation
//   5. Cava spectrum bars along bottom          — motion accent while playing
//   6. Content row: album art thumbnail, title/artist column, transport buttons
//   7. Progress bar at very bottom              — scrub/position indicator
//
// Bound entirely to Core.ServiceManager.player (PlayerService), so it
// auto-hides when no media is playing and the parent Repeater filter
// (Config.cc.cards.player) respects the user opt-in.
Rectangle {
    id: card

    // When placed inside a Loader (via sourceComponent) our parent is the
    // Loader itself, so width follows whatever width the Loader is bound
    // to. `implicitHeight` propagates back up to the Loader so a plain
    // Column can lay us out using implicit sizing.
    width: parent ? parent.width : 320
    implicitHeight: 160

    readonly property var svc: Core.ServiceManager.player
    readonly property bool hasMedia: svc ? svc.hasMedia : false
    readonly property string title:  svc ? svc.trackTitle  : ""
    readonly property string artist: svc ? svc.trackArtist : ""
    readonly property string artUrl: svc ? svc.trackArtUrl : ""
    readonly property bool isPlaying: svc ? svc.isPlaying : false
    readonly property real progress: (svc && svc.length > 0) ? (svc.position / svc.length) : 0

    radius: Root.Theme.radiusMedium
    color: Root.Theme.ccSectionBg
    clip: true
    border.width: Root.Theme.borderWidth
    border.color: Root.Theme.borderColor

    // ── Layer 2: Blurred artwork background ────────────────────────────
    Image {
        id: artBg
        anchors.fill: parent
        source: card.artUrl
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 256
        sourceSize.height: 256
        visible: source.toString().length > 0 && status === Image.Ready
        asynchronous: true
        cache: true
        // MultiEffect blurs the image in-place, hardware-accelerated.
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 32
            blur: 0.7
            // A tiny saturation bump makes the blur feel like a "glass" backdrop
            // rather than mud.
            saturation: 0.2
        }
    }

    // ── Layer 3: Dark readability scrim ────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Root.Theme.base00
        opacity: artBg.visible ? 0.55 : 0.0
        Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.exitDuration } }
    }

    // ── Layer 5: Cava spectrum bars along bottom ───────────────────────
    // Rendered as a Canvas so we can cheaply repaint on every cavaBars tick
    // without instantiating 24 Rectangles. Vertically centered above the
    // progress bar, with a radial fade so the center bars read brighter.
    Canvas {
        id: spectrum
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 4 }
        height: 36
        opacity: card.isPlaying ? 0.55 : 0.0
        Behavior on opacity { NumberAnimation { duration: Root.Theme.animNormal } }

        readonly property var bars: (card.svc && card.svc.cavaBars) ? card.svc.cavaBars : []
        readonly property color barColor: Root.Theme.domainMedia

        onBarsChanged: requestPaint()
        onWidthChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!bars || bars.length === 0) return;

            const n = bars.length;
            const gap = 2;
            const bw = (width - gap * (n - 1)) / n;
            const h  = height;
            ctx.fillStyle = barColor;

            for (let i = 0; i < n; i++) {
                const v = Math.max(0, Math.min(1, bars[i] || 0));
                // Center the spectrum vertically so bars grow up AND down
                // slightly, like an equalizer.
                const bh = Math.max(1, v * h);
                const x = i * (bw + gap);
                const y = h - bh;
                ctx.fillRect(x, y, bw, bh);
            }
        }
    }

    // ── Layer 6: Content row ───────────────────────────────────────────
    Row {
        id: contentRow
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 12

        // Foreground album art thumbnail (sharp, not blurred)
        Rectangle {
            id: artFg
            width: 72; height: 72
            radius: Root.Theme.radiusSmall
            color: Root.Theme.base02
            clip: true

            Image {
                anchors.fill: parent
                source: card.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 144
                sourceSize.height: 144
                visible: source.toString().length > 0 && status === Image.Ready
                asynchronous: true
                cache: true
            }

            Text {
                anchors.centerIn: parent
                visible: !card.artUrl || card.artUrl.length === 0
                text: Root.Icons.music
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontIcons; pixelSize: 28 }
            }
        }

        // Title / artist / transport column
        Column {
            width: parent.width - artFg.width - 12
            spacing: 4

            // Title — scrolling text handles overflow gracefully if available,
            // but a straight elide keeps this card dependency-free.
            Text {
                width: parent.width
                text: card.hasMedia ? card.title : "Nothing playing"
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true }
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: card.hasMedia ? card.artist : ""
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 11 }
                elide: Text.ElideRight
                visible: text.length > 0
            }

            Item { width: 1; height: 4 }

            // Transport row
            // Prev/Next use the standard IconButton (dimmed → hover reveal).
            // Play/Pause is a custom always-lit accent pill so playing state
            // is visible at a glance without requiring hover.
            Row {
                spacing: 14
                anchors.left: parent.left

                Components.IconButton {
                    icon: Root.Icons.skipBack
                    iconColor: Root.Theme.textPrimary
                    size: 24
                    onClicked: if (card.svc) card.svc.previous()
                }

                // Always-lit play/pause pill
                Rectangle {
                    id: playPauseBtn
                    width: 30; height: 30
                    radius: width / 2
                    color: ppMouse.containsMouse
                        ? Qt.rgba(Root.Theme.domainMedia.r, Root.Theme.domainMedia.g, Root.Theme.domainMedia.b, 0.28)
                        : Qt.rgba(Root.Theme.domainMedia.r, Root.Theme.domainMedia.g, Root.Theme.domainMedia.b, 0.18)
                    border.width: 1
                    border.color: Qt.rgba(Root.Theme.domainMedia.r, Root.Theme.domainMedia.g, Root.Theme.domainMedia.b, 0.5)
                    scale: ppMouse.pressed ? 0.92 : 1.0

                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: card.isPlaying ? Root.Icons.pause : Root.Icons.play
                        color: Root.Theme.domainMedia
                        font { family: Root.Theme.fontFamily; pixelSize: 16 }
                    }

                    MouseArea {
                        id: ppMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (card.svc) card.svc.togglePlaying()
                    }
                }

                Components.IconButton {
                    icon: Root.Icons.skipFwd
                    iconColor: Root.Theme.textPrimary
                    size: 24
                    onClicked: if (card.svc) card.svc.next()
                }
            }
        }
    }

    // ── Layer 7: Progress bar at very bottom ──────────────────────────
    Rectangle {
        id: progressTrack
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 3
        color: Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.2)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, card.progress))
            height: parent.height
            color: Root.Theme.domainMedia
            Behavior on width { NumberAnimation { duration: Root.Theme.animSlow; easing.type: Easing.OutCubic } }
        }
    }
}
