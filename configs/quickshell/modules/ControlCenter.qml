import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import ".." as Root
import "../components" as Components
import "../core" as Core
import "controlcenter" as CCTabs

Scope {
    id: cc

    property bool showing: false
    property string activeTab: "notifications"
    property bool showHistory: showing

    // Self-wired via ServiceManager
    readonly property var audioService: Core.ServiceManager.audio
    readonly property var notifService: Core.ServiceManager.notif
    readonly property var wifiService: Core.ServiceManager.wifi
    readonly property var bluetoothService: Core.ServiceManager.bluetooth
    readonly property var idleInhibitService: Core.ServiceManager.idleInhibit

    function toggle() {
        showing = !showing;
        if (showing) {
            ccPanel.visible = true;
            if (notifService) notifService.unreadCount = 0;
            if (wifiService) wifiService.scan();
            if (bluetoothService) bluetoothService.scan(false);
            if (audioService) { audioService.refreshApps(); audioService.refreshDevices(); }
            if (notifService) notifService.rebuildStacks();
        }
    }
    function toggleHistory() { toggle(); }

    Timer {
        interval: 2000
        running: cc.showing && cc.activeTab === "volume"
        onTriggered: { if (cc.audioService) cc.audioService.refreshApps(); }
    }

    // ── Toast popups (stacked by app) ──
    PanelWindow {
        id: toastPanel
        visible: cc.notifService ? cc.notifService.popupStacks.count > 0 : false
        anchors { top: true; right: true }
        margins.top: Root.Theme.barHeight + Root.Theme.notifMarginTop
        margins.right: Root.Theme.notifMarginRight
        implicitWidth: Root.Theme.notifWidth
        implicitHeight: toastCol.implicitHeight
        WlrLayershell.namespace: "quickshell-toasts"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        Column {
            id: toastCol
            width: parent.width
            spacing: Root.Theme.notifSpacing

            Repeater {
                model: cc.notifService ? cc.notifService.popupStacks : null

                Item {
                    id: toastItem
                    width: toastCol.width
                    height: toastCard.height
                    clip: true
                    opacity: 0

                    property string appKey: model.appName

                    Component.onCompleted: {
                        toastCard.x = toastItem.width;
                        if (model.dismissing) {
                            toastItem.opacity = 0;
                        } else {
                            appearAnim.start();
                        }
                    }

                    ParallelAnimation {
                        id: appearAnim
                        NumberAnimation { target: toastCard; property: "x"; to: 0; duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic }
                        NumberAnimation { target: toastItem; property: "opacity"; to: 1; duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic }
                    }

                    NumberAnimation {
                        id: dismissAnim
                        target: toastItem; property: "opacity"; to: 0; duration: Root.Theme.anim.exitDuration; easing.type: Easing.InCubic
                        onFinished: { if (cc.notifService) cc.notifService.removePopupApp(toastItem.appKey); }
                    }

                    property bool isDismissing: model.dismissing
                    onIsDismissingChanged: { if (isDismissing && !dismissAnim.running) dismissAnim.start(); }

                    Rectangle {
                        id: toastCard
                        width: parent.width
                        height: toastContent.implicitHeight
                        radius: Root.Theme.notifRadius
                        color: Root.Theme.notifBackground
                        border.width: Root.Theme.borderWidth
                        border.color: Root.Theme.borderColor

                        layer.enabled: true
                        layer.effect: DropShadow {
                            transparentBorder: true
                            color: Qt.rgba(0, 0, 0, 0.35)
                            radius: 12; samples: 25
                        }

                        Components.NotificationCard {
                            id: toastContent
                            width: parent.width
                            appName: model.appName
                            summary: model.summary
                            body: model.body
                            imagePath: model.imagePath
                            count: model.count
                            compact: false
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (cc.notifService) cc.notifService.dismissPopupApp(model.appName); }
                        }
                    }
                }
            }
        }
    }

    // ── Click-outside dismiss scrim ──
    PanelWindow {
        id: ccScrim
        visible: cc.showing
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.namespace: "quickshell-cc-scrim"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: cc.showing = false
        }
    }

    // ── Panel ──
    PanelWindow {
        id: ccPanel
        visible: false
        anchors { top: true; right: true; bottom: true }
        margins.top: Root.Theme.barHeight + 6
        margins.bottom: 6
        margins.right: 0
        implicitWidth: Root.Theme.ccWidth + 6
        WlrLayershell.namespace: "quickshell-cc"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                id: ccRect
                width: Root.Theme.ccWidth
                height: parent.height
                radius: Root.Theme.radiusMedium
                color: Root.Theme.barBackground
                x: cc.showing ? 0 : (Root.Theme.ccWidth + 6)
                Behavior on x { NumberAnimation { duration: Root.Theme.anim.slideDuration; easing.type: Easing.OutCubic } }
                onXChanged: { if (!cc.showing && x >= Root.Theme.ccWidth + 5) ccPanel.visible = false; }

                layer.enabled: cc.showing
                layer.effect: DropShadow {
                    transparentBorder: true
                    color: Qt.rgba(0, 0, 0, 0.45)
                    radius: 20; samples: 41; horizontalOffset: -4
                }

                Column {
                    anchors { fill: parent; margins: Root.Theme.ccPadding }
                    spacing: 12

                    // ── Header ──
                    Item {
                        width: parent.width; height: 28

                        Text {
                            text: "Control Center"
                            color: Root.Theme.textPrimary
                            font { family: Root.Theme.fontFamily; pixelSize: 12; bold: true; letterSpacing: 2 }
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        }

                        Components.IconButton {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            icon: Root.Icons.shutdown
                            iconColor: Root.Theme.accentDanger
                            hoverColor: Qt.rgba(Root.Theme.accentDanger.r, Root.Theme.accentDanger.g, Root.Theme.accentDanger.b, 0.15)
                            onClicked: { cc.showing = false; let pm = Core.ServiceManager.powerMenu; if (pm) pm.toggle(); }
                        }
                    }

                    // ── Quick toggles (using QuickToggle component) ──
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8; height: 40

                        Components.QuickToggle {
                            isOn: cc.wifiService && cc.wifiService.enabled
                            iconOn: Root.Icons.wifiHi; iconOff: Root.Icons.wifiOff
                            accent: Root.Theme.domainNetwork
                            onToggled: { if (cc.wifiService) cc.wifiService.toggle(); }
                        }

                        Components.QuickToggle {
                            isOn: cc.notifService ? cc.notifService.dnd : false
                            iconOn: Root.Icons.dnd; iconOff: Root.Icons.dndOff
                            accent: Root.Theme.domainNotifications
                            onToggled: { if (cc.notifService) cc.notifService.dnd = !cc.notifService.dnd; }
                        }

                        Components.QuickToggle {
                            isOn: cc.audioService ? !cc.audioService.muted : true
                            iconOn: Root.Icons.volHigh; iconOff: Root.Icons.volMute
                            accent: Root.Theme.domainMedia
                            onToggled: { if (cc.audioService) cc.audioService.toggleMute(); }
                        }

                        Components.QuickToggle {
                            isOn: cc.bluetoothService ? cc.bluetoothService.enabled : false
                            iconOn: Root.Icons.btOn; iconOff: Root.Icons.btOff
                            accent: Root.Theme.domainNetwork
                            onToggled: { if (cc.bluetoothService) cc.bluetoothService.toggle(); }
                        }

                        Components.QuickToggle {
                            isOn: cc.idleInhibitService ? cc.idleInhibitService.inhibited : false
                            iconOn: Root.Icons.caffeine; iconOff: Root.Icons.caffeineOff
                            accent: Root.Theme.caffeineAccent
                            onToggled: { if (cc.idleInhibitService) cc.idleInhibitService.toggle(); }
                        }
                    }

                    // ── Tab bar with sliding indicator ──
                    Item {
                        id: tabBar
                        width: parent.width; height: 38

                        property var tabs: [
                            { tab: "notifications", icon: Root.Icons.bell, label: "Notif", accent: Root.Theme.domainNotifications },
                            { tab: "volume", icon: Root.Icons.volHigh, label: "Vol", accent: Root.Theme.domainMedia },
                            { tab: "wifi", icon: Root.Icons.wifiHi, label: "Net", accent: Root.Theme.domainNetwork },
                            { tab: "bluetooth", icon: Root.Icons.btOn, label: "Bt", accent: Root.Theme.domainNetwork }
                        ]

                        property int activeIndex: {
                            for (let i = 0; i < tabs.length; i++)
                                if (tabs[i].tab === cc.activeTab) return i;
                            return 0;
                        }

                        // Sliding indicator
                        Rectangle {
                            id: tabIndicator
                            y: tabBar.height - 2
                            width: tabBar.width / tabBar.tabs.length
                            height: 2
                            color: tabBar.tabs[tabBar.activeIndex].accent
                            x: tabBar.activeIndex * width

                            Behavior on x { NumberAnimation { duration: Root.Theme.anim.moveDuration; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Root.Theme.anim.moveDuration } }
                        }

                        Row {
                            anchors.fill: parent
                            spacing: 0

                            Repeater {
                                model: tabBar.tabs

                                Rectangle {
                                    width: tabBar.width / tabBar.tabs.length; height: 38
                                    color: tabMouse.containsMouse ? Root.Theme.layer1Hover : "transparent"
                                    radius: Root.Theme.radiusSmall
                                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                                    Column {
                                        anchors.centerIn: parent; spacing: 2
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.icon
                                            color: cc.activeTab === modelData.tab ? modelData.accent : (tabMouse.containsMouse ? Root.Theme.textPrimary : Root.Theme.textDimmed)
                                            font { family: Root.Theme.fontFamily; pixelSize: 16 }
                                            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.label
                                            color: cc.activeTab === modelData.tab ? modelData.accent : (tabMouse.containsMouse ? Root.Theme.textPrimary : Root.Theme.textDimmed)
                                            font { family: Root.Theme.fontFamily; pixelSize: 11 }
                                            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                                        }
                                    }
                                    MouseArea {
                                        id: tabMouse
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            cc.activeTab = modelData.tab;
                                            if (modelData.tab === "volume" && cc.audioService) { cc.audioService.refreshApps(); cc.audioService.refreshDevices(); }
                                            if (modelData.tab === "wifi" && cc.wifiService) cc.wifiService.scan();
                                            if (modelData.tab === "bluetooth" && cc.bluetoothService) cc.bluetoothService.scan(false);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Root.Theme.textDimmed; opacity: 0.15 }

                    // ── Tab content ──
                    Item {
                        width: parent.width
                        height: parent.height - 28 - 48 - 38 - 1 - 30 - 60

                        CCTabs.NotificationsTab {
                            anchors.fill: parent
                            visible: opacity > 0
                            notifService: cc.notifService
                            opacity: cc.activeTab === "notifications" ? 1 : 0
                            transform: Translate {
                                y: cc.activeTab === "notifications" ? 0 : 6
                                Behavior on y { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
                            }
                            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
                        }

                        CCTabs.VolumeTab {
                            anchors.fill: parent
                            visible: opacity > 0
                            audioService: cc.audioService
                            opacity: cc.activeTab === "volume" ? 1 : 0
                            transform: Translate {
                                y: cc.activeTab === "volume" ? 0 : 6
                                Behavior on y { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
                            }
                            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
                        }

                        CCTabs.WifiTab {
                            anchors.fill: parent
                            visible: opacity > 0
                            wifiService: cc.wifiService
                            opacity: cc.activeTab === "wifi" ? 1 : 0
                            transform: Translate {
                                y: cc.activeTab === "wifi" ? 0 : 6
                                Behavior on y { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
                            }
                            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
                        }

                        CCTabs.BluetoothTab {
                            anchors.fill: parent
                            visible: opacity > 0
                            bluetoothService: cc.bluetoothService
                            opacity: cc.activeTab === "bluetooth" ? 1 : 0
                            transform: Translate {
                                y: cc.activeTab === "bluetooth" ? 0 : 6
                                Behavior on y { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
                            }
                            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
                        }
                    }

                    // ── Footer ──
                    Item {
                        width: parent.width; height: 30

                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: {
                                let c = cc.notifService ? cc.notifService.items.length : 0;
                                return c + " notification" + (c !== 1 ? "s" : "");
                            }
                            color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: 12 }
                        }

                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 8

                            Rectangle {
                                width: silentText.implicitWidth + 12; height: 24
                                radius: Root.Theme.radiusSmall
                                color: silentMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.08) : "transparent"

                                Text {
                                    id: silentText
                                    anchors.centerIn: parent
                                    property bool isDnd: cc.notifService ? cc.notifService.dnd : false
                                    text: isDnd ? Root.Icons.dnd + " Silent" : Root.Icons.dndOff + " Silent"
                                    color: isDnd ? Root.Theme.domainNotifications : (silentMouse.containsMouse ? Root.Theme.textPrimary : Root.Theme.textDimmed)
                                    font { family: Root.Theme.fontFamily; pixelSize: 12 }
                                }
                                MouseArea { id: silentMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.notifService) cc.notifService.dnd = !cc.notifService.dnd; } }
                            }

                            Rectangle {
                                width: clearText.implicitWidth + 12; height: 24
                                radius: Root.Theme.radiusSmall
                                color: clearMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.08) : "transparent"

                                Text {
                                    id: clearText
                                    anchors.centerIn: parent
                                    text: Root.Icons.trash + " Clear"
                                    color: {
                                        if (!(cc.notifService && cc.notifService.items.length > 0))
                                            return Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.3);
                                        return clearMouse.containsMouse ? Root.Theme.textPrimary : Root.Theme.textDimmed;
                                    }
                                    font { family: Root.Theme.fontFamily; pixelSize: 12 }
                                }
                                MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.notifService) cc.notifService.clearAll(); } }
                            }
                        }
                    }
                }
            }
        }
    }
}
