import QtQuick
import Quickshell
import ".." as Root
import "../core" as Core

// ProfileCard — user identity surface.
//
// Renders the user's avatar (from ~/.face with a graceful fallback to the
// Icons.user glyph), a time-aware greeting, the hostname, and the system
// uptime, plus an optional row of quick action buttons (Settings, Lock,
// Power).
//
// Two visual modes, selected via `compact`:
//
//   compact: true  (default) — Control Center card. Horizontal layout
//       with a 64px avatar tile on the left, an identity column in the
//       middle, and three action buttons on the right. Lives inside a
//       rounded ccSectionBg rectangle so it lines up visually with the
//       other CC cards (PlayerCard, NetworkCard).
//
//   compact: false            — LockScreen hero. Vertical stack with
//       a larger 96px circular avatar, username in display size, and
//       the hostname · uptime subtitle. Transparent background so it
//       can sit directly on top of the lock wallpaper. Action buttons
//       hidden since the LockScreen has its own unlock flow.
Item {
    id: card

    // ── Public API ──
    property bool compact: true
    // When false, the three action buttons are suppressed regardless of
    // `compact`. This exists so callers who want a "quiet" profile surface
    // (e.g. a future "about this system" widget) can opt out without
    // having to re-implement the layout.
    property bool showActions: compact

    // ── Data sources ──
    readonly property var svc: Core.ServiceManager.systemStats
    readonly property string username: svc ? svc.username : ""
    readonly property string hostname: svc ? svc.hostname : ""
    readonly property string uptime:   svc ? svc.uptime   : ""

    // Avatar path: $HOME/.face. If the file doesn't exist the Image's
    // `status` will never reach Ready and we fall back to the glyph.
    readonly property string avatarPath: "file://" + (Quickshell.env("HOME") || "") + "/.face"

    // Greeting updates once per minute — plenty for a field that only
    // changes three times a day. We avoid the 1Hz clock tick other
    // widgets use because this surface doesn't need subsecond accuracy.
    property int _greetingTick: 0
    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: card._greetingTick++
    }
    readonly property string greeting: {
        void(_greetingTick); // force re-evaluation on tick
        let h = new Date().getHours();
        if (h < 5)  return "Still up";
        if (h < 12) return "Good morning";
        if (h < 17) return "Good afternoon";
        if (h < 22) return "Good evening";
        return "Good night";
    }

    // Sizing scales with mode. In compact mode the height is fixed; in
    // hero mode it grows to fit the larger avatar and stacked text.
    // Compact is deliberately tight (64px) — the hostname line was
    // redundant chrome once ProfileCard moved into the CC header slot,
    // where a taller strip would crowd out the toggle pill below.
    implicitWidth: parent ? parent.width : 320
    implicitHeight: compact ? 64 : 200

    // ══════════════════════════════════════════════════════
    // ── COMPACT (CC) ──
    // ══════════════════════════════════════════════════════
    Rectangle {
        id: compactRoot
        visible: card.compact
        anchors.fill: parent
        radius: Root.Theme.radiusMedium
        color: Root.Theme.ccSectionBg
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor

        Row {
            anchors { fill: parent; margins: 8 }
            spacing: 10

            // Avatar tile (rounded square). The Image is parented to a
            // clipping Rectangle so rounded corners work without a mask
            // effect — cheaper than MultiEffect mask for a 48px thumbnail.
            // Sized to fit the 64px compact height with 8px margins
            // (64 - 8*2 = 48).
            Rectangle {
                id: compactAvatar
                width: 48; height: 48
                radius: Root.Theme.radiusSmall
                color: Qt.rgba(Root.Theme.domainSettings.r,
                               Root.Theme.domainSettings.g,
                               Root.Theme.domainSettings.b, 0.15)
                border.width: 1
                border.color: Qt.rgba(Root.Theme.domainSettings.r,
                                      Root.Theme.domainSettings.g,
                                      Root.Theme.domainSettings.b, 0.4)
                clip: true

                Image {
                    id: compactAvatarImg
                    anchors.fill: parent
                    source: card.avatarPath
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 128
                    sourceSize.height: 128
                    visible: status === Image.Ready
                    asynchronous: true
                    cache: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: compactAvatarImg.status !== Image.Ready
                    text: Root.Icons.user
                    color: Root.Theme.domainSettings
                    font { family: Root.Theme.fontFamily; pixelSize: 24 }
                }
            }

            // Identity column — two lines now that hostname has been
            // dropped. Greeting on top (bold), uptime subtitle below.
            // The 10px spacing after the avatar + the right-side actions
            // row are subtracted from the available width so elide works.
            Column {
                width: parent.width - compactAvatar.width - compactActions.width - 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: card.greeting + (card.username.length > 0 ? ", " + card.username : "")
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true }
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: card.uptime.length > 0 ? ("up " + card.uptime) : "this machine"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: 10 }
                    elide: Text.ElideRight
                }
            }

            // Actions row — Settings, Lock, Power. Collapses to zero width
            // (and is `visible: false`) when showActions is off so the
            // identity column reclaims the freed horizontal space.
            Row {
                id: compactActions
                visible: card.showActions
                width: visible ? implicitWidth : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                IconButton {
                    icon: Root.Icons.gear
                    iconColor: Root.Theme.textDimmed
                    tooltipText: "Settings"
                    onClicked: {
                        let sw = Core.ServiceManager.settingsWindow;
                        if (sw && sw.toggle) sw.toggle();
                    }
                }
                IconButton {
                    icon: Root.Icons.lock
                    iconColor: Root.Theme.textDimmed
                    tooltipText: "Lock"
                    onClicked: {
                        let pm = Core.ServiceManager.powerMenu;
                        if (pm && pm.execute) pm.execute("lock");
                    }
                }
                IconButton {
                    icon: Root.Icons.shutdown
                    iconColor: Root.Theme.accentDanger
                    hoverColor: Qt.rgba(Root.Theme.accentDanger.r,
                                        Root.Theme.accentDanger.g,
                                        Root.Theme.accentDanger.b, 0.15)
                    tooltipText: "Power menu"
                    onClicked: {
                        let pm = Core.ServiceManager.powerMenu;
                        if (pm && pm.toggle) pm.toggle();
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════
    // ── HERO (LockScreen) ──
    // ══════════════════════════════════════════════════════
    // Transparent; sits directly on top of the lock wallpaper/scrim. The
    // avatar is a circle here (not a rounded square) because the hero
    // framing is more iconic, and the text is centered rather than
    // left-aligned.
    Item {
        id: heroRoot
        visible: !card.compact
        anchors.fill: parent

        Column {
            anchors.centerIn: parent
            spacing: 12

            // Circular avatar — 96px. Uses a full-circle radius so the
            // clip crops the image into a disk. Same fallback-to-glyph
            // pattern as compact mode.
            Rectangle {
                id: heroAvatar
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96; height: 96
                radius: width / 2
                color: Qt.rgba(Root.Theme.textPrimary.r,
                               Root.Theme.textPrimary.g,
                               Root.Theme.textPrimary.b, 0.08)
                border.width: 2
                border.color: Qt.rgba(Root.Theme.textPrimary.r,
                                      Root.Theme.textPrimary.g,
                                      Root.Theme.textPrimary.b, 0.25)
                clip: true

                Image {
                    id: heroAvatarImg
                    anchors.fill: parent
                    source: card.avatarPath
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 192
                    sourceSize.height: 192
                    visible: status === Image.Ready
                    asynchronous: true
                    cache: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: heroAvatarImg.status !== Image.Ready
                    text: Root.Icons.user
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: 48 }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.greeting + (card.username.length > 0 ? ", " + card.username : "")
                color: Root.Theme.textPrimary
                font { family: Root.Theme.fontFamily; pixelSize: 20; bold: true }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: card.hostname.length > 0 || card.uptime.length > 0
                text: {
                    let parts = [];
                    if (card.hostname.length > 0) parts.push(card.hostname);
                    if (card.uptime.length > 0)   parts.push("up " + card.uptime);
                    return parts.join("  ·  ");
                }
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: 13 }
            }
        }
    }
}
