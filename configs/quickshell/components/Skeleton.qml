import QtQuick
import ".." as Root

// Shimmer placeholder for content that is still loading (album art, icons, …).
// A subtle base block with a soft highlight sweeping across. Drop it in place of
// (or behind) an Image and show it while `status !== Image.Ready`.
//
// Usage:
//   Skeleton { anchors.fill: parent; radius: 8; visible: img.status !== Image.Ready }
Rectangle {
    id: skel

    property int sweepDuration: 1200
    // Base + highlight tints derived from the foreground so it works on any bg.
    property color tint: Root.Theme.textPrimary

    radius: Root.Theme.radiusSmall
    color: Qt.rgba(tint.r, tint.g, tint.b, 0.06)
    clip: true

    Rectangle {
        id: highlight
        width: Math.max(40, parent.width * 0.5)
        height: parent.height * 2          // overscan so the diagonal covers corners
        anchors.verticalCenter: parent.verticalCenter
        rotation: 16
        transformOrigin: Item.Center

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(skel.tint.r, skel.tint.g, skel.tint.b, 0.10) }
            GradientStop { position: 1.0; color: "transparent" }
        }

        // Sweep left→right on a loop; only runs while the skeleton is shown.
        x: -width
        NumberAnimation on x {
            running: skel.visible
            loops: Animation.Infinite
            from: -highlight.width
            to: skel.width + highlight.width
            duration: skel.sweepDuration
            easing.type: Easing.InOutQuad
        }
    }
}
