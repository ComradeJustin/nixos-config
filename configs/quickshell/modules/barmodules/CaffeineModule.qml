import QtQuick
import "../.." as Root
import "../../core" as Core

// Caffeine (idle inhibit) bar toggle. Click to toggle, icon reflects state.
// Hidden when idle inhibit is OFF unless the user explicitly enables show-when-off
// via Config.bar.showCaffeineWhenOff (defaulted off so it's invisible by default).
Item {
    id: root

    property var svc: Core.ServiceManager.idleInhibit
    readonly property bool inhibited: svc ? svc.inhibited : false

    // Show even when idle inhibit is off if user has opted in. Otherwise the
    // module only takes up bar space while caffeine is active — same pattern
    // as TrayModule's auto-hide.
    readonly property bool showWhenOff: Root.Config.bar.showCaffeineWhenOff || false
    readonly property bool contentVisible: inhibited || showWhenOff

    implicitWidth: contentVisible ? icon.implicitWidth + 4 : 0
    implicitHeight: Root.Theme.barHeight
    visible: contentVisible

    Text {
        id: icon
        anchors.centerIn: parent
        text: root.inhibited ? Root.Icons.caffeine : Root.Icons.caffeineOff
        color: root.inhibited ? Root.Theme.accentWarm : Root.Theme.textDimmed
        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.iconSize }

        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { if (root.svc) root.svc.toggle(); }
    }
}
