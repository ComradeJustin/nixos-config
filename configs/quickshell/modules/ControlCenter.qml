import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".." as Root

Scope {
    id: cc

    Root.Theme { id: theme }

    property bool showing: false
    property string activeTab: "notifications"
    property bool showHistory: showing

    property var audioService: null
    property var powerMenuRef: null
    property var notifService: null
    property var wifiService: null

    function toggle() {
        showing = !showing;
        if (showing) {
            ccPanel.visible = true;
            if (notifService) notifService.unreadCount = 0;
            if (wifiService) wifiService.scan();
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
        margins.top: theme.barHeight + theme.notifMarginTop
        margins.right: theme.notifMarginRight
        implicitWidth: theme.notifWidth
        implicitHeight: toastCol.implicitHeight
        WlrLayershell.namespace: "quickshell-toasts"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        Column {
            id: toastCol
            width: parent.width
            spacing: theme.notifSpacing

            Repeater {
                model: cc.notifService ? cc.notifService.popupStacks : null

                Item {
                    width: toastCol.width
                    height: toastCard.height
                    clip: true

                    Rectangle {
                        id: toastCard
                        width: parent.width
                        height: toastInner.implicitHeight + theme.notifPadding * 2
                        radius: theme.notifRadius
                        color: theme.notifBackground
                        x: 0
                        Component.onCompleted: { x = parent.width; x = 0; }
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        RowLayout {
                            id: toastInner
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: theme.notifPadding }
                            spacing: 10

                            Item {
                                Layout.preferredWidth: theme.notifIconSize
                                Layout.preferredHeight: theme.notifIconSize
                                Layout.alignment: Qt.AlignTop

                                Image {
                                    id: tNotifImg
                                    anchors.fill: parent
                                    source: model.imagePath || ""
                                    sourceSize.width: theme.notifIconSize
                                    sourceSize.height: theme.notifIconSize
                                    visible: status === Image.Ready
                                    smooth: true
                                    fillMode: Image.PreserveAspectCrop
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: theme.ccSectionBg
                                    visible: tNotifImg.status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: (model.appName || "?").charAt(0).toUpperCase()
                                        color: theme.textDimmed
                                        font { family: theme.fontFamily; pixelSize: 14; bold: true }
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
                                        color: theme.notifAppName
                                        font { family: theme.fontFamily; pixelSize: 12 }
                                        visible: model.appName !== ""
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        visible: model.count > 1
                                        width: Math.max(16, tBadge.implicitWidth + 6)
                                        height: 16
                                        radius: 8
                                        color: theme.textAccent

                                        Text {
                                            id: tBadge
                                            anchors.centerIn: parent
                                            text: model.count
                                            color: theme.barBackground
                                            font { family: theme.fontFamily; pixelSize: 9; bold: true }
                                        }
                                    }
                                }

                                Text {
                                    text: model.summary
                                    color: theme.notifTitle
                                    font { family: theme.fontFamily; pixelSize: 13; bold: true }
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: model.body
                                    color: theme.notifBody
                                    font { family: theme.fontFamily; pixelSize: 12 }
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    visible: model.body !== ""
                                    textFormat: Text.PlainText
                                }
                            }
                        }

                        // Swipe to dismiss
                        MouseArea {
                            anchors.fill: parent
                            property real startX: 0
                            onPressed: function(mouse) { startX = mouse.x; }
                            onPositionChanged: function(mouse) { if (pressed) toastCard.x = mouse.x - startX; }
                            onReleased: {
                                if (Math.abs(toastCard.x) > toastCard.width * 0.3) {
                                    if (cc.notifService) cc.notifService.dismissPopupApp(model.appName);
                                } else {
                                    toastCard.x = 0;
                                }
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
        margins.top: theme.barHeight + 6
        margins.bottom: 6
        margins.right: 6
        implicitWidth: theme.ccWidth
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
                width: theme.ccWidth
                height: parent.height
                radius: theme.ccSectionRadius
                color: theme.barBackground
                x: cc.showing ? 0 : theme.ccWidth
                Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }
                onXChanged: { if (!cc.showing && x >= theme.ccWidth - 1) ccPanel.visible = false; }

                Column {
                    anchors { fill: parent; margins: theme.ccPadding }
                    spacing: 12

                    // ── Header ──
                    Item {
                        width: parent.width; height: 28

                        Text {
                            text: "Control Center"
                            color: theme.textPrimary
                            font { family: theme.fontFamily; pixelSize: 14; bold: true }
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        }

                        Text {
                            text: theme.iconPower
                            color: theme.textCritical
                            font { family: theme.fontFamily; pixelSize: 18 }
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { cc.showing = false; if (cc.powerMenuRef) cc.powerMenuRef.toggle(); }
                            }
                        }
                    }

                    // ── Quick toggles ──
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12; height: 48

                        Rectangle {
                            width: 48; height: 48; radius: 24
                            color: (cc.wifiService && cc.wifiService.connected) ? Qt.rgba(theme.textAccent.r, theme.textAccent.g, theme.textAccent.b, 0.25) : theme.ccSectionBg
                            Text { anchors.centerIn: parent; text: (cc.wifiService && cc.wifiService.connected) ? theme.iconWifiHi : theme.iconWifiOff; color: (cc.wifiService && cc.wifiService.connected) ? theme.textAccent : theme.textDimmed; font { family: theme.fontFamily; pixelSize: 20 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.wifiService) cc.wifiService.toggle(); } }
                        }

                        Rectangle {
                            width: 48; height: 48; radius: 24
                            property bool isDnd: cc.notifService ? cc.notifService.dnd : false
                            color: isDnd ? Qt.rgba(theme.textWarning.r, theme.textWarning.g, theme.textWarning.b, 0.25) : theme.ccSectionBg
                            Text { anchors.centerIn: parent; text: parent.isDnd ? theme.iconDnd : theme.iconDndOff; color: parent.isDnd ? theme.textWarning : theme.textDimmed; font { family: theme.fontFamily; pixelSize: 20 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.notifService) cc.notifService.dnd = !cc.notifService.dnd; } }
                        }

                        Rectangle {
                            width: 48; height: 48; radius: 24
                            property bool isMuted: cc.audioService ? cc.audioService.muted : false
                            color: isMuted ? Qt.rgba(theme.textCritical.r, theme.textCritical.g, theme.textCritical.b, 0.25) : theme.ccSectionBg
                            Text { anchors.centerIn: parent; text: parent.isMuted ? theme.iconVolMute : theme.iconVolHigh; color: parent.isMuted ? theme.textCritical : theme.textDimmed; font { family: theme.fontFamily; pixelSize: 20 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.audioService) cc.audioService.toggleMute(); } }
                        }
                    }

                    // ── Tab bar ──
                    Row {
                        width: parent.width; height: 38; spacing: 0

                        Repeater {
                            model: [
                                { tab: "notifications", icon: theme.iconBell, label: "Notifications" },
                                { tab: "volume", icon: theme.iconVolHigh, label: "Volume" },
                                { tab: "wifi", icon: theme.iconWifiHi, label: "Wi-Fi" }
                            ]

                            Rectangle {
                                width: parent.width / 3; height: 38; color: "transparent"

                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: cc.activeTab === modelData.tab ? theme.textAccent : theme.textDimmed; font { family: theme.fontFamily; pixelSize: 16 } }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: cc.activeTab === modelData.tab ? theme.textAccent : theme.textDimmed; font { family: theme.fontFamily; pixelSize: 11 } }
                                }
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: cc.activeTab === modelData.tab ? theme.textAccent : "transparent" }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        cc.activeTab = modelData.tab;
                                        if (modelData.tab === "volume" && cc.audioService) { cc.audioService.refreshApps(); cc.audioService.refreshDevices(); }
                                        if (modelData.tab === "wifi") if (cc.wifiService) cc.wifiService.scan();
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: theme.textDimmed; opacity: 0.15 }

                    // ── Tab content ──
                    Item {
                        width: parent.width
                        height: parent.height - 28 - 48 - 38 - 1 - 30 - 60

                        // ── Notifications ──
                        Flickable {
                            anchors.fill: parent
                            visible: cc.activeTab === "notifications"
                            contentHeight: notifCol.implicitHeight
                            clip: true; boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: notifCol; width: parent.width; spacing: 4

                                Text {
                                    visible: cc.notifService ? cc.notifService.stacks.count === 0 : true
                                    text: "No notifications"
                                    color: theme.textDimmed
                                    font { family: theme.fontFamily; pixelSize: 13 }
                                    width: parent.width; height: 60
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }

                                Repeater {
                                    model: cc.notifService ? cc.notifService.stacks : null

                                    Rectangle {
                                        id: notifItem
                                        width: notifCol.width
                                        height: nRow.implicitHeight + 14
                                        radius: 8
                                        color: nHover.containsMouse ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.04) : "transparent"
                                        clip: true
                                        x: 0
                                        Behavior on x { NumberAnimation { duration: 150 } }

                                        RowLayout {
                                            id: nRow
                                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                                            spacing: 10

                                            // Notification icon
                                            Item {
                                                Layout.preferredWidth: 30
                                                Layout.preferredHeight: 30
                                                Layout.alignment: Qt.AlignTop

                                                Image {
                                                    id: nNotifImg
                                                    anchors.fill: parent
                                                    source: model.imagePath || ""
                                                    sourceSize.width: 30
                                                    sourceSize.height: 30
                                                    visible: status === Image.Ready
                                                    smooth: true
                                                    fillMode: Image.PreserveAspectCrop
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 6
                                                    color: theme.ccSectionBg
                                                    visible: nNotifImg.status !== Image.Ready

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: (model.appName || "?").charAt(0).toUpperCase()
                                                        color: theme.textDimmed
                                                        font { family: theme.fontFamily; pixelSize: 13; bold: true }
                                                    }
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 1

                                                RowLayout {
                                                    Layout.fillWidth: true

                                                    Text { text: model.appName; color: theme.notifAppName; font { family: theme.fontFamily; pixelSize: 11 }
                                                     Layout.fillWidth: true; elide: Text.ElideRight }

                                                    Text { text: model.timestamp; color: theme.textSubtle; font { family: theme.fontFamily; pixelSize: 10 } }

                                                    Rectangle {
                                                        visible: model.isHeader && model.count > 1
                                                        width: Math.max(18, bdgTxt.implicitWidth + 8); height: 18; radius: 9
                                                        color: theme.textAccent

                                                        Text { id: bdgTxt; anchors.centerIn: parent; text: model.count; color: theme.barBackground; font { family: theme.fontFamily; pixelSize: 10; bold: true } }
                                                    }

                                                    Text {
                                                        visible: model.isHeader && model.count > 1
                                                        text: model.expanded ? "▾" : "▸"
                                                        color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 12 }
                                                    }
                                                }

                                                Text { text: model.summary; color: theme.notifTitle; font { family: theme.fontFamily; pixelSize: 13; bold: true }
                                                 Layout.fillWidth: true; elide: Text.ElideRight }
                                                Text {
                                                    text: model.body; color: theme.notifBody
                                                    font { family: theme.fontFamily; pixelSize: 12 }
                                                    Layout.fillWidth: true; wrapMode: Text.Wrap
                                                    maximumLineCount: 2; elide: Text.ElideRight
                                                    visible: model.body !== ""; textFormat: Text.PlainText
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: !model.isHeader
                                            anchors { left: parent.left; leftMargin: 50; right: parent.right; rightMargin: 10; bottom: parent.bottom }
                                            height: 1; color: theme.textDimmed; opacity: 0.06
                                        }

                                        MouseArea {
                                            id: nHover; anchors.fill: parent; hoverEnabled: true
                                            property real startX: 0

                                            onPressed: function(mouse) { startX = mouse.x; }
                                            onPositionChanged: function(mouse) { if (pressed) notifItem.x = mouse.x - startX; }
                                            onReleased: function(mouse) {
                                                if (Math.abs(notifItem.x) > notifItem.width * 0.35) {
                                                    if (model.isHeader && model.count > 1)
                                                        cc.notifService.removeApp(model.appName);
                                                    else
                                                        cc.notifService.removeOne(model.nId);
                                                } else {
                                                    notifItem.x = 0;
                                                    if (model.isHeader && model.count > 1)
                                                        cc.notifService.toggleExpand(model.appName);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Volume ──
                        Flickable {
                            anchors.fill: parent; visible: cc.activeTab === "volume"
                            contentHeight: volCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: volCol; width: parent.width; spacing: 10

                                Item { width: 1; height: 2 }

                                Rectangle {
                                    width: parent.width; height: 56; radius: theme.ccSectionRadius; color: theme.ccSectionBg

                                    Row {
                                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                                         spacing: 10

                                        Text {
                                            text: (cc.audioService && cc.audioService.muted) ? theme.iconVolMute : theme.iconVolHigh
                                            color: (cc.audioService && cc.audioService.muted) ? theme.textDimmed : theme.textPrimary
                                            font { family: theme.fontFamily; pixelSize: 20 }
                                             anchors.verticalCenter: parent.verticalCenter
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.audioService) cc.audioService.toggleMute(); } }
                                        }

                                        Item {
                                            width: parent.width - 20 - 50 - 20; height: 24; anchors.verticalCenter: parent.verticalCenter
                                            Rectangle { anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                             height: 4; radius: 2; color: theme.textDimmed; opacity: 0.3 }
                                            Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                             height: 4; radius: 2; color: theme.textAccent; width: parent.width * ((cc.audioService ? cc.audioService.volume : 0) / 100) }
                                            Rectangle { width: 16; height: 16; radius: 8; color: theme.textAccent; y: (parent.height - 16) / 2; x: (parent.width - 16) * ((cc.audioService ? cc.audioService.volume : 0) / 100) }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onPressed: function(mouse) { if (cc.audioService) cc.audioService.setVolume(Math.round(mouse.x / parent.width * 100)); }
                                                onPositionChanged: function(mouse) { if (pressed && cc.audioService) cc.audioService.setVolume(Math.round(mouse.x / parent.width * 100)); }
                                            }
                                        }

                                        Text {
                                            text: (cc.audioService ? cc.audioService.volume : 0) + "%"
                                            color: theme.textPrimary; font { family: theme.fontFamily; pixelSize: 14; bold: true }
                                            width: 44; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }

                                Text { text: "Output"; color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 12 }
                                 leftPadding: 4; visible: cc.audioService ? cc.audioService.sinks.count > 0 : false }

                                Repeater {
                                    model: cc.audioService ? cc.audioService.sinks : null
                                    Rectangle {
                                        width: volCol.width; height: 36; radius: 8
                                        color: model.devActive ? Qt.rgba(theme.textAccent.r, theme.textAccent.g, theme.textAccent.b, 0.1) : theme.ccSectionBg
                                        Row {
                                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
                                             spacing: 8
                                            Text { text: theme.iconSpeaker; color: model.devActive ? theme.textAccent : theme.textDimmed; font { family: theme.fontFamily; pixelSize: 14 }
                                             anchors.verticalCenter: parent.verticalCenter }
                                            Text { text: model.devDesc; color: model.devActive ? theme.textAccent : theme.textPrimary; font { family: theme.fontFamily; pixelSize: 12; bold: model.devActive }
                                             anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: volCol.width - 50 }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.audioService) cc.audioService.setSink(model.devName); } }
                                    }
                                }

                                Text { text: "Input"; color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 12 }
                                 leftPadding: 4; visible: cc.audioService ? cc.audioService.sources.count > 0 : false }

                                Repeater {
                                    model: cc.audioService ? cc.audioService.sources : null
                                    Rectangle {
                                        width: volCol.width; height: 36; radius: 8
                                        color: model.devActive ? Qt.rgba(theme.textAccent.r, theme.textAccent.g, theme.textAccent.b, 0.1) : theme.ccSectionBg
                                        Row {
                                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
                                             spacing: 8
                                            Text { text: theme.iconHeadphone; color: model.devActive ? theme.textAccent : theme.textDimmed; font { family: theme.fontFamily; pixelSize: 14 }
                                             anchors.verticalCenter: parent.verticalCenter }
                                            Text { text: model.devDesc; color: model.devActive ? theme.textAccent : theme.textPrimary; font { family: theme.fontFamily; pixelSize: 12; bold: model.devActive }
                                             anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: volCol.width - 50 }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.audioService) cc.audioService.setSource(model.devName); } }
                                    }
                                }

                                Text { text: "Applications"; color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 12 }
                                 leftPadding: 4; visible: cc.audioService ? cc.audioService.appStreams.count > 0 : false }

                                Repeater {
                                    model: cc.audioService ? cc.audioService.appStreams : null
                                    Rectangle {
                                        width: volCol.width; height: 52; radius: theme.ccSectionRadius; color: theme.ccSectionBg
                                        Row {
                                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                                             spacing: 10
                                            Item {
                                                width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter
                                                Image { id: appIcn; anchors.fill: parent; source: model.appIcon !== "" ? "image://icon/" + model.appIcon : ""; sourceSize.width: 22; sourceSize.height: 22; visible: status === Image.Ready; smooth: true }
                                                Text { anchors.centerIn: parent; visible: appIcn.status !== Image.Ready; text: (model.appName || "?").charAt(0).toUpperCase(); color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 12; bold: true } }
                                            }
                                            Column {
                                                width: parent.width - 22 - 20; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                                Text { text: model.appName; color: theme.textPrimary; font { family: theme.fontFamily; pixelSize: 12 }
                                                 elide: Text.ElideRight; width: parent.width }
                                                Row {
                                                    width: parent.width; spacing: 8
                                                    Item {
                                                        width: parent.width - 44; height: 16
                                                        Rectangle { anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                                         height: 3; radius: 2; color: theme.textDimmed; opacity: 0.3 }
                                                        Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                                         height: 3; radius: 2; color: theme.textAccent; width: parent.width * Math.min(1, (model.appVol || 0) / 100) }
                                                        Rectangle { width: 12; height: 12; radius: 6; color: theme.textAccent; y: (parent.height - 12) / 2; x: (parent.width - 12) * Math.min(1, (model.appVol || 0) / 100) }
                                                        MouseArea {
                                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                            onPressed: function(mouse) { if (cc.audioService) cc.audioService.setAppVolume(model.appIdx, Math.round(mouse.x / parent.width * 100)); }
                                                            onPositionChanged: function(mouse) { if (pressed && cc.audioService) cc.audioService.setAppVolume(model.appIdx, Math.round(mouse.x / parent.width * 100)); }
                                                        }
                                                    }
                                                    Text { text: (model.appVol || 0) + "%"; color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 11 }
                                                     width: 36; horizontalAlignment: Text.AlignRight }
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: cc.audioService ? cc.audioService.appStreams.count === 0 : true
                                    text: "No active audio streams"; color: theme.textDimmed
                                    font { family: theme.fontFamily; pixelSize: 12 }
                                    width: parent.width; height: 40
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        // ── WiFi ──
                        Flickable {
                            anchors.fill: parent; visible: cc.activeTab === "wifi"
                            contentHeight: wifiTabCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: wifiTabCol; width: parent.width; spacing: 4

                                Rectangle {
                                    visible: (cc.wifiService && cc.wifiService.connected); width: parent.width; height: 44; radius: 8; color: theme.ccSectionBg
                                    Row {
                                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
                                         spacing: 10
                                        Text { text: theme.iconWifiHi; color: theme.textAccent; font { family: theme.fontFamily; pixelSize: 18 }
                                         anchors.verticalCenter: parent.verticalCenter }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text { text: (cc.wifiService ? cc.wifiService.ssid : ""); color: theme.textAccent; font { family: theme.fontFamily; pixelSize: 13; bold: true } }
                                            Text { text: "Connected"; color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 11 } }
                                        }
                                    }
                                }

                                Item { width: 1; height: (cc.wifiService && cc.wifiService.connected) ? 4 : 0 }

                                Text { visible: (cc.wifiService ? cc.wifiService.networks.count : 0) === 0; text: "Scanning…"; color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 13 }
                                 width: parent.width; height: 50; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }

                                Repeater {
                                    model: cc.wifiService ? cc.wifiService.networks : null
                                    Rectangle {
                                        width: wifiTabCol.width; height: 36; radius: 6
                                        color: wfMouse.containsMouse ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.06) : "transparent"
                                        Row {
                                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12 }
                                             spacing: 10
                                            Text { text: model.wifiSignal > 75 ? theme.iconWifiHi : model.wifiSignal > 50 ? theme.iconWifiMid : model.wifiSignal > 25 ? theme.iconWifiLow : theme.iconWifiMin; color: model.wifiActive ? theme.textAccent : theme.textDimmed; font { family: theme.fontFamily; pixelSize: 16 }
                                             anchors.verticalCenter: parent.verticalCenter }
                                            Text { text: model.wifiSsid; color: model.wifiActive ? theme.textAccent : theme.textPrimary; font { family: theme.fontFamily; pixelSize: 13; bold: model.wifiActive }
                                             anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.width - 30 }
                                        }
                                        MouseArea { id: wfMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.wifiService) { if (model.wifiActive) cc.wifiService.disconnect(); else cc.wifiService.connectTo(model.wifiSsid); } } }
                                    }
                                }
                            }
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
                            color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 12 }
                        }

                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                             spacing: 14

                            Text {
                                property bool isDnd: cc.notifService ? cc.notifService.dnd : false
                                text: isDnd ? theme.iconDnd + " Silent" : theme.iconDndOff + " Silent"
                                color: isDnd ? theme.textWarning : theme.textDimmed
                                font { family: theme.fontFamily; pixelSize: 12 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.notifService) cc.notifService.dnd = !cc.notifService.dnd; } }
                            }

                            Text {
                                text: theme.iconTrash + " Clear"
                                color: (cc.notifService && cc.notifService.items.length > 0) ? theme.textDimmed : Qt.rgba(theme.textDimmed.r, theme.textDimmed.g, theme.textDimmed.b, 0.3)
                                font { family: theme.fontFamily; pixelSize: 12 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (cc.notifService) cc.notifService.clearAll(); } }
                            }
                        }
                    }
                }
            }
        }
    }
}
