import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import ".." as Root
import "../components" as Components
import "controlcenter" as CCTabs

Scope {
    id: cc

    property bool showing: false
    property string activeTab: "notifications"
    property bool showHistory: showing

    property var audioService: null
    property var powerMenuRef: null
    property var notifService: null
    property var wifiService: null
    property var bluetoothService: null
    property var widgetOverlayRef: null
    property var idleInhibitService: null

    signal widgetEditRequested()

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
                        NumberAnimation { target: toastCard; property: "x"; to: 0; duration: 250; easing.type: Easing.OutCubic }
                        NumberAnimation { target: toastItem; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                    }

                    NumberAnimation {
                        id: dismissAnim
                        target: toastItem; property: "opacity"; to: 0; duration: 300; easing.type: Easing.InCubic
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

    // ── Panel ──
    PanelWindow {
        id: ccPanel
        visible: false
        anchors { top: true; right: true; bottom: true }
        margins.top: Root.Theme.barHeight + 6
        margins.bottom: 6
        margins.right: 6
        implicitWidth: Root.Theme.ccWidth
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
                x: cc.showing ? 0 : Root.Theme.ccWidth
                Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }
                onXChanged: { if (!cc.showing && x >= Root.Theme.ccWidth - 1) ccPanel.visible = false; }

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

                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 6

                            Components.IconButton {
                                icon: Root.Theme.iconWidgets
                                iconColor: Root.Theme.domainSettings
                                hoverColor: Qt.rgba(Root.Theme.domainSettings.r, Root.Theme.domainSettings.g, Root.Theme.domainSettings.b, 0.15)
                                onClicked: { cc.showing = false; cc.widgetEditRequested(); }
                            }

                            Components.IconButton {
                                icon: Root.Theme.iconShutdown
                                iconColor: Root.Theme.accentDanger
                                hoverColor: Qt.rgba(Root.Theme.accentDanger.r, Root.Theme.accentDanger.g, Root.Theme.accentDanger.b, 0.15)
                                onClicked: { cc.showing = false; if (cc.powerMenuRef) cc.powerMenuRef.toggle(); }
                            }
                        }
                    }

                    // ── Quick toggles (using QuickToggle component) ──
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8; height: 40

                        Components.QuickToggle {
                            isOn: cc.wifiService && cc.wifiService.enabled
                            iconOn: Root.Theme.iconWifiHi; iconOff: Root.Theme.iconWifiOff
                            accent: Root.Theme.domainNetwork
                            onToggled: { if (cc.wifiService) cc.wifiService.toggle(); }
                        }

                        Components.QuickToggle {
                            isOn: cc.notifService ? cc.notifService.dnd : false
                            iconOn: Root.Theme.iconDnd; iconOff: Root.Theme.iconDndOff
                            accent: Root.Theme.domainNotifications
                            onToggled: { if (cc.notifService) cc.notifService.dnd = !cc.notifService.dnd; }
                        }

                        Components.QuickToggle {
                            isOn: cc.audioService ? !cc.audioService.muted : true
                            iconOn: Root.Theme.iconVolHigh; iconOff: Root.Theme.iconVolMute
                            accent: Root.Theme.domainMedia
                            onToggled: { if (cc.audioService) cc.audioService.toggleMute(); }
                        }

                        Components.QuickToggle {
                            isOn: cc.bluetoothService ? cc.bluetoothService.enabled : false
                            iconOn: Root.Theme.iconBtOn; iconOff: Root.Theme.iconBtOff
                            accent: Root.Theme.domainNetwork
                            onToggled: { if (cc.bluetoothService) cc.bluetoothService.toggle(); }
                        }

                        Components.QuickToggle {
                            isOn: cc.idleInhibitService ? cc.idleInhibitService.inhibited : false
                            iconOn: Root.Theme.iconCaffeine; iconOff: Root.Theme.iconCaffeineOff
                            accent: Root.Theme.caffeineAccent
                            onToggled: { if (cc.idleInhibitService) cc.idleInhibitService.toggle(); }
                        }
                    }

                    // ── Tab bar ──
                    Row {
                        width: parent.width; height: 38; spacing: 0

                        Repeater {
                            model: [
                                { tab: "notifications", icon: Root.Theme.iconBell, label: "Notif", accent: Root.Theme.domainNotifications },
                                { tab: "volume", icon: Root.Theme.iconVolHigh, label: "Vol", accent: Root.Theme.domainMedia },
                                { tab: "wifi", icon: Root.Theme.iconWifiHi, label: "Net", accent: Root.Theme.domainNetwork },
                                { tab: "bluetooth", icon: Root.Theme.iconBtOn, label: "Bt", accent: Root.Theme.domainNetwork }
                            ]

                            Rectangle {
                                width: parent.width / 4; height: 38
                                color: tabMouse.containsMouse ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06) : "transparent"
                                radius: Root.Theme.radiusSmall

                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.icon
                                        color: cc.activeTab === modelData.tab ? modelData.accent : (tabMouse.containsMouse ? Root.Theme.textPrimary : Root.Theme.textDimmed)
                                        font { family: Root.Theme.fontFamily; pixelSize: 16 }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: cc.activeTab === modelData.tab ? modelData.accent : (tabMouse.containsMouse ? Root.Theme.textPrimary : Root.Theme.textDimmed)
                                        font { family: Root.Theme.fontFamily; pixelSize: 11 }
                                    }
                                }
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: cc.activeTab === modelData.tab ? modelData.accent : "transparent" }
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

                    Rectangle { width: parent.width; height: 1; color: Root.Theme.textDimmed; opacity: 0.15 }

                    // ── Tab content ──
                    Item {
                        width: parent.width
                        height: parent.height - 28 - 48 - 38 - 1 - 30 - 60

                        CCTabs.NotificationsTab {
                            anchors.fill: parent
                            visible: cc.activeTab === "notifications"
                            notifService: cc.notifService
                        }

                        CCTabs.VolumeTab {
                            anchors.fill: parent
                            visible: cc.activeTab === "volume"
                            audioService: cc.audioService
                        }

                        CCTabs.WifiTab {
                            anchors.fill: parent
                            visible: cc.activeTab === "wifi"
                            wifiService: cc.wifiService
                        }

                        CCTabs.BluetoothTab {
                            anchors.fill: parent
                            visible: cc.activeTab === "bluetooth"
                            bluetoothService: cc.bluetoothService
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
                                    text: isDnd ? Root.Theme.iconDnd + " Silent" : Root.Theme.iconDndOff + " Silent"
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
                                    text: Root.Theme.iconTrash + " Clear"
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
