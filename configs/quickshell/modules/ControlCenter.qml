import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".." as Root
import "controlcenter" as CCTabs

Scope {
    id: cc

    // Theme is now a singleton - access via Root.Theme.propertyName

    property bool showing: false
    property string activeTab: "notifications"
    property bool showHistory: showing

    property var audioService: null
    property var powerMenuRef: null
    property var notifService: null
    property var wifiService: null
    property var bluetoothService: null
    property var widgetOverlayRef: null

    signal widgetEditRequested()

    function toggle() {
        showing = !showing;
        if (showing) {
            ccPanel.visible = true;
            if (notifService) notifService.unreadCount = 0;
            if (wifiService) wifiService.scan();
            if (bluetoothService) bluetoothService.scan(false);  // false = don't force rescan if already loaded
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

                    // ── Appear ──
                    ParallelAnimation {
                        id: appearAnim
                        NumberAnimation { target: toastCard; property: "x"; to: 0; duration: 250; easing.type: Easing.OutCubic }
                        NumberAnimation { target: toastItem; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                    }

                    // ── Dismiss ──
                    NumberAnimation {
                        id: dismissAnim
                        target: toastItem
                        property: "opacity"
                        to: 0
                        duration: 300
                        easing.type: Easing.InCubic
                        onFinished: {
                            if (cc.notifService) cc.notifService.removePopupApp(toastItem.appKey);
                        }
                    }

                    // Watch dismissing flag via local property
                    property bool isDismissing: model.dismissing
                    onIsDismissingChanged: {
                        if (isDismissing && !dismissAnim.running) {
                            dismissAnim.start();
                        }
                    }

                    Rectangle {
                        id: toastCard
                        width: parent.width
                        height: toastInner.implicitHeight + Root.Theme.notifPadding * 2
                        radius: Root.Theme.notifRadius
                        color: Root.Theme.notifBackground
                        border.width: Root.Theme.borderWidth
                        border.color: Root.Theme.borderColor

                        RowLayout {
                            id: toastInner
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Root.Theme.notifPadding }
                            spacing: 10

                            Item {
                                Layout.preferredWidth: Root.Theme.notifIconSize
                                Layout.preferredHeight: Root.Theme.notifIconSize
                                Layout.alignment: Qt.AlignTop

                                Image {
                                    id: tNotifImg
                                    anchors.fill: parent
                                    source: model.imagePath || ""
                                    sourceSize.width: Root.Theme.notifIconSize
                                    sourceSize.height: Root.Theme.notifIconSize
                                    visible: status === Image.Ready
                                    smooth: true
                                    fillMode: Image.PreserveAspectCrop
                                    cache: false  // Disable caching for dynamic notification images
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Root.Theme.radiusSmall
                                    color: Root.Theme.ccIconBg  // Muted icon placeholder
                                    visible: tNotifImg.status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: (model.appName || "?").charAt(0).toUpperCase()
                                        color: Root.Theme.textSubtle
                                        font { family: Root.Theme.fontFamily; pixelSize: 14; bold: true }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: model.appName
                                        color: Root.Theme.notifAppName
                                        font { family: Root.Theme.fontFamily; pixelSize: 12 }
                                        visible: model.appName !== ""
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        visible: model.count > 1
                                        width: Math.max(16, tBadge.implicitWidth + 6)
                                        height: 16
                                        radius: Root.Theme.radiusSmall
                                        color: Root.Theme.domainNotifications

                                        Text {
                                            id: tBadge
                                            anchors.centerIn: parent
                                            text: model.count
                                            color: Root.Theme.barBackground
                                            font { family: Root.Theme.fontFamily; pixelSize: 9; bold: true }
                                        }
                                    }
                                }

                                Text {
                                    text: model.summary
                                    color: Root.Theme.notifTitle
                                    font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true }
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: model.body
                                    color: Root.Theme.notifBody
                                    font { family: Root.Theme.fontFamily; pixelSize: 12 }
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    visible: model.body !== ""
                                    textFormat: Text.PlainText
                                }
                            }
                        }

                        // Click to dismiss
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (cc.notifService) cc.notifService.dismissPopupApp(model.appName);
                            }
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
                radius: Root.Theme.radiusMedium  // Cozy: rounded panel edges
                color: Root.Theme.barBackground
                x: cc.showing ? 0 : Root.Theme.ccWidth
                Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }
                onXChanged: { if (!cc.showing && x >= Root.Theme.ccWidth - 1) ccPanel.visible = false; }

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

                            // Widget Settings Button
                            Rectangle {
                                width: 28; height: 28
                                radius: Root.Theme.radiusSmall
                                color: widgetSettingsMouse.containsMouse ? Qt.rgba(Root.Theme.domainSettings.r, Root.Theme.domainSettings.g, Root.Theme.domainSettings.b, 0.15) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: Root.Theme.iconWidgets
                                    color: widgetSettingsMouse.containsMouse ? Root.Theme.domainSettings : Root.Theme.textDimmed
                                    font { family: Root.Theme.fontFamily; pixelSize: 16 }
                                }
                                MouseArea {
                                    id: widgetSettingsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        cc.showing = false;
                                        cc.widgetEditRequested();
                                    }
                                }
                            }

                            // Power Menu Button (changed icon to shutdown symbol)
                            Rectangle {
                                width: 28; height: 28
                                radius: Root.Theme.radiusSmall
                                color: powerMouse.containsMouse ? Qt.rgba(Root.Theme.accentDanger.r, Root.Theme.accentDanger.g, Root.Theme.accentDanger.b, 0.15) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: Root.Theme.iconShutdown
                                    color: Root.Theme.accentDanger
                                    font { family: Root.Theme.fontFamily; pixelSize: 16 }
                                }
                                MouseArea {
                                    id: powerMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { cc.showing = false; if (cc.powerMenuRef) cc.powerMenuRef.toggle(); }
                                }
                            }
                        }
                    }

                    // ── Quick toggles (cozy: subtle rounding with borders + hover) ──
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8; height: 40

                        Rectangle {
                            id: wifiToggle
                            width: 40; height: 40; radius: Root.Theme.radiusSmall
                            property bool isOn: cc.wifiService && cc.wifiService.enabled
                            color: wifiMouse.containsMouse
                                ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1)
                                : (isOn ? Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.15) : "transparent")
                            border.width: Root.Theme.borderWidth
                            border.color: isOn ? Root.Theme.domainNetwork : Root.Theme.borderColor
                            Text { anchors.centerIn: parent; text: parent.isOn ? Root.Theme.iconWifiHi : Root.Theme.iconWifiOff; color: parent.isOn ? Root.Theme.domainNetwork : Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: 16 } }
                            MouseArea { id: wifiMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.wifiService) cc.wifiService.toggle(); } }
                        }

                        Rectangle {
                            id: dndToggle
                            width: 40; height: 40; radius: Root.Theme.radiusSmall
                            property bool isOn: cc.notifService ? cc.notifService.dnd : false
                            color: dndMouse.containsMouse
                                ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1)
                                : (isOn ? Qt.rgba(Root.Theme.domainNotifications.r, Root.Theme.domainNotifications.g, Root.Theme.domainNotifications.b, 0.15) : "transparent")
                            border.width: Root.Theme.borderWidth
                            border.color: isOn ? Root.Theme.domainNotifications : Root.Theme.borderColor
                            Text { anchors.centerIn: parent; text: parent.isOn ? Root.Theme.iconDnd : Root.Theme.iconDndOff; color: parent.isOn ? Root.Theme.domainNotifications : Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: 16 } }
                            MouseArea { id: dndMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.notifService) cc.notifService.dnd = !cc.notifService.dnd; } }
                        }

                        Rectangle {
                            id: muteToggle
                            width: 40; height: 40; radius: Root.Theme.radiusSmall
                            property bool isOn: cc.audioService ? !cc.audioService.muted : true
                            color: muteMouse.containsMouse
                                ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1)
                                : (isOn ? Qt.rgba(Root.Theme.domainMedia.r, Root.Theme.domainMedia.g, Root.Theme.domainMedia.b, 0.15) : "transparent")
                            border.width: Root.Theme.borderWidth
                            border.color: isOn ? Root.Theme.domainMedia : Root.Theme.borderColor
                            Text { anchors.centerIn: parent; text: parent.isOn ? Root.Theme.iconVolHigh : Root.Theme.iconVolMute; color: parent.isOn ? Root.Theme.domainMedia : Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: 16 } }
                            MouseArea { id: muteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.audioService) cc.audioService.toggleMute(); } }
                        }

                        Rectangle {
                            id: btToggle
                            width: 40; height: 40; radius: Root.Theme.radiusSmall
                            property bool isOn: cc.bluetoothService ? cc.bluetoothService.enabled : false
                            color: btMouse.containsMouse
                                ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.1)
                                : (isOn ? Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.15) : "transparent")
                            border.width: Root.Theme.borderWidth
                            border.color: isOn ? Root.Theme.domainNetwork : Root.Theme.borderColor
                            Text { anchors.centerIn: parent; text: parent.isOn ? Root.Theme.iconBtOn : Root.Theme.iconBtOff; color: parent.isOn ? Root.Theme.domainNetwork : Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: 16 } }
                            MouseArea { id: btMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.bluetoothService) cc.bluetoothService.toggle(); } }
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
                                id: tabItem
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
                            color: Root.Theme.textDimmed; font { family: Root.Theme.fontFamily; pixelSize: 12 }
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
