import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import ".." as Root

Scope {
    id: cc

    Root.Theme { id: theme }

    property bool showing: false
    property bool dnd: false
    property int unreadCount: 0
    property string activeTab: "notifications"
    property bool showHistory: showing

    function toggle() {
        showing = !showing;
        if (showing) {
            ccPanel.visible = true;
            unreadCount = 0;
            volProc.running = true;
            wifiScanProc.running = true;
            appVolScanProc.running = true;
        }
    }
    function toggleHistory() { toggle(); }
    function clearHistory() { historyModel.clear(); unreadCount = 0; }

    ListModel { id: popupModel }
    ListModel { id: historyModel }
    ListModel { id: wifiModel }
    ListModel { id: appVolModel }

    // ── Notification Server ──
    NotificationServer {
        id: server
        bodySupported: true; bodyMarkupSupported: true
        imageSupported: true; actionsSupported: true; keepOnReload: false

        onNotification: function(notification) {
            notification.tracked = true;
            let timeout = theme.notifTimeout;
            if (notification.urgency === NotificationUrgency.Critical) timeout *= 3;

            historyModel.insert(0, {
                "summary": notification.summary || "", "body": notification.body || "",
                "appName": notification.appName || "",
                "imagePath": notification.image || notification.appIcon || "", "nId": notification.id
            });
            if (!cc.showing) cc.unreadCount++;
            if (cc.dnd && notification.urgency !== NotificationUrgency.Critical) return;
            if (popupModel.count >= theme.notifMaxVisible) popupModel.remove(popupModel.count - 1);
            popupModel.insert(0, {
                "summary": notification.summary || "", "body": notification.body || "",
                "appName": notification.appName || "",
                "imagePath": notification.image || notification.appIcon || "", "nTimeout": timeout
            });
        }
    }

    // ── Toasts ──
    PanelWindow {
        id: toastPanel; visible: popupModel.count > 0
        anchors { top: true; right: true }
        margins.top: theme.barHeight + theme.notifMarginTop; margins.right: theme.notifMarginRight
        implicitWidth: theme.notifWidth; implicitHeight: toastCol.implicitHeight
        WlrLayershell.namespace: "quickshell-toasts"; WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None; exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        Column {
            id: toastCol; width: parent.width; spacing: theme.notifSpacing
            Repeater {
                model: popupModel
                Item {
                    width: toastCol.width; height: toastCard.height; clip: true
                    Rectangle {
                        id: toastCard; width: parent.width
                        height: toastContent.implicitHeight + theme.notifPadding * 2
                        radius: theme.notifRadius; color: theme.notifBackground
                        Component.onCompleted: { x = parent.width; x = 0; }
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        RowLayout {
                            id: toastContent
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: theme.notifPadding }
                            spacing: 10
                            Image {
                                source: { let p = model.imagePath; if (!p || p === "") return ""; if (p.indexOf("://") !== -1) return p; if (p.startsWith("/")) return "file://" + p; return "image://icon/" + p; }
                                sourceSize.width: theme.notifIconSize; sourceSize.height: theme.notifIconSize
                                Layout.preferredWidth: theme.notifIconSize; Layout.preferredHeight: theme.notifIconSize
                                Layout.alignment: Qt.AlignTop; visible: status === Image.Ready; smooth: true
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Text {
                                    text: model.appName; color: theme.notifAppName
                                    font { family: theme.fontFamily; pixelSize: 12 }
                                    visible: model.appName !== ""
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                                Text {
                                    text: model.summary; color: theme.notifTitle
                                    font { family: theme.fontFamily; pixelSize: 13; bold: true }
                                    Layout.fillWidth: true; wrapMode: Text.Wrap
                                    maximumLineCount: 2; elide: Text.ElideRight
                                }
                                Text {
                                    text: model.body; color: theme.notifBody
                                    font { family: theme.fontFamily; pixelSize: 12 }
                                    Layout.fillWidth: true; wrapMode: Text.Wrap
                                    maximumLineCount: 4; elide: Text.ElideRight
                                    visible: model.body !== ""; textFormat: Text.PlainText
                                }
                            }
                        }
                        Timer { interval: model.nTimeout; running: true; onTriggered: { if (index >= 0 && index < popupModel.count) popupModel.remove(index); } }
                    }
                }
            }
        }
    }

    // ── Volume (optimistic updates) ──
    property int volume: 0
    property bool muted: false

    Process {
        id: volProc; command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser { onRead: data => { cc.muted = data.indexOf("[MUTED]") !== -1; let p = data.split(" "); if (p.length >= 2) { let f = parseFloat(p[1]); if (!isNaN(f)) cc.volume = Math.round(f * 100); } } }
        onExited: { if (cc.showing) volPoll.start(); }
    }
    Timer { id: volPoll; interval: 300; onTriggered: volProc.running = true }
    Process { id: volSetProc; property int vol: 0; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", vol + "%"] }
    Process { id: volMuteProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]; onExited: { cc.muted = !cc.muted; } }

    function setVolume(v) {
        v = Math.max(0, Math.min(100, v));
        cc.volume = v;
        volSetProc.vol = v;
        volSetProc.running = true;
    }

    // ── Per-app volume via pactl ──
    Process {
        id: appVolScanProc
        command: [
            "bash", "-c",
            "pactl list sink-inputs 2>/dev/null | awk '\n" +
            "  /Sink Input #/ { idx=$3; sub(/#/,\"\",idx) }\n" +
            "  /application.name/ { name=$0; sub(/.*= \"/,\"\",name); sub(/\"$/,\"\",name) }\n" +
            "  /application.icon_name/ { icon=$0; sub(/.*= \"/,\"\",icon); sub(/\"$/,\"\",icon) }\n" +
            "  /Volume:/ && idx { vol=$0; match(vol,/([0-9]+)%/,m); pct=m[1]; print idx \"\\t\" name \"\\t\" icon \"\\t\" pct; idx=\"\" }\n" +
            "'"
        ]
        stdout: SplitParser {
            onRead: data => {
                let p = data.split("\t");
                if (p.length < 4) return;
                appVolModel.append({
                    "appIdx": p[0], "appName": p[1] || "Unknown",
                    "appIcon": p[2] || "", "appVol": parseInt(p[3]) || 0
                });
            }
        }
        onStarted: appVolModel.clear()
        onExited: { if (cc.showing && cc.activeTab === "volume") appVolPoll.start(); }
    }
    Timer { id: appVolPoll; interval: 2000; onTriggered: appVolScanProc.running = true }
    Process { id: appVolSetProc; property string idx: ""; property int vol: 0; command: ["pactl", "set-sink-input-volume", idx, vol + "%"] }

    // ── WiFi ──
    property string wifiSsid: ""; property bool wifiConnected: false; property bool wifiEnabled: true
    Process {
        id: wifiScanProc
        command: ["bash", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list --rescan auto 2>/dev/null | while IFS=: read -r active ssid sig sec; do [ -z \"$ssid\" ] && continue; echo \"$active\t$ssid\t$sig\t$sec\"; done | sort -t$'\\t' -k1,1r -k3,3nr"]
        stdout: SplitParser { onRead: data => { let p = data.split("\t"); if (p.length < 4) return; wifiModel.append({ "wifiActive": p[0] === "yes", "wifiSsid": p[1], "wifiSignal": parseInt(p[2]) || 0, "wifiSecurity": p[3] || "" }); if (p[0] === "yes") { cc.wifiSsid = p[1]; cc.wifiConnected = true; } } }
        onStarted: { wifiModel.clear(); cc.wifiConnected = false; cc.wifiSsid = ""; }
    }
    Process { id: wifiConnProc; property string ssid: ""; command: ["nmcli", "dev", "wifi", "connect", ssid] }
    Process { id: wifiDiscProc; command: ["nmcli", "dev", "disconnect", "wlan0"] }
    Process { id: wifiToggleProc; property bool on: true; command: ["nmcli", "radio", "wifi", on ? "on" : "off"] }
    Timer { id: wifiRefresh; interval: 3000; onTriggered: wifiScanProc.running = true }

    // ── Panel ──
    PanelWindow {
        id: ccPanel; visible: false
        anchors { top: true; right: true; bottom: true }
        margins.top: theme.barHeight + 6; margins.bottom: 6; margins.right: 6
        implicitWidth: theme.ccWidth
        WlrLayershell.namespace: "quickshell-cc"; WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None; exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        Item {
            anchors.fill: parent; clip: true

            Rectangle {
                id: ccRect; width: theme.ccWidth; height: parent.height
                radius: theme.ccSectionRadius; color: theme.barBackground
                x: cc.showing ? 0 : theme.ccWidth
                Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }
                onXChanged: { if (!cc.showing && x >= theme.ccWidth - 1) ccPanel.visible = false; }

                Column {
                    anchors { fill: parent; margins: theme.ccPadding }
                    spacing: 12

                    // ── Quick toggles ──
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12; height: 48

                        Rectangle {
                            width: 48; height: 48; radius: 24
                            color: cc.wifiConnected ? Qt.rgba(theme.textAccent.r, theme.textAccent.g, theme.textAccent.b, 0.25) : theme.ccSectionBg
                            Text { anchors.centerIn: parent; text: cc.wifiConnected ? theme.iconWifiHi : theme.iconWifiOff; color: cc.wifiConnected ? theme.textAccent : theme.textDimmed; font { family: theme.fontFamily; pixelSize: 20 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { cc.wifiEnabled = !cc.wifiEnabled; cc.wifiConnected = false; wifiToggleProc.on = cc.wifiEnabled; wifiToggleProc.running = true; wifiRefresh.start(); } }
                        }

                        Rectangle {
                            width: 48; height: 48; radius: 24
                            color: cc.dnd ? Qt.rgba(theme.textWarning.r, theme.textWarning.g, theme.textWarning.b, 0.25) : theme.ccSectionBg
                            Text { anchors.centerIn: parent; text: cc.dnd ? theme.iconDnd : theme.iconDndOff; color: cc.dnd ? theme.textWarning : theme.textDimmed; font { family: theme.fontFamily; pixelSize: 20 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cc.dnd = !cc.dnd }
                        }

                        Rectangle {
                            width: 48; height: 48; radius: 24
                            color: cc.muted ? Qt.rgba(theme.textCritical.r, theme.textCritical.g, theme.textCritical.b, 0.25) : theme.ccSectionBg
                            Text { anchors.centerIn: parent; text: cc.muted ? theme.iconVolMute : theme.iconVolHigh; color: cc.muted ? theme.textCritical : theme.textDimmed; font { family: theme.fontFamily; pixelSize: 20 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { cc.muted = !cc.muted; volMuteProc.running = true; } }
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
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { cc.activeTab = modelData.tab; if (modelData.tab === "volume") appVolScanProc.running = true; if (modelData.tab === "wifi") wifiScanProc.running = true; } }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: theme.textDimmed; opacity: 0.15 }

                    // ── Tab content ──
                    Item {
                        width: parent.width
                        height: parent.height - 48 - 38 - 1 - 34 - 48

                        // ── Notifications ──
                        Flickable {
                            anchors.fill: parent; visible: cc.activeTab === "notifications"
                            contentHeight: notifCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: notifCol; width: parent.width; spacing: 0

                                Text {
                                    visible: historyModel.count === 0; text: "No notifications"
                                    color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 13 }
                                    width: parent.width; height: 60
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }

                                Repeater {
                                    model: historyModel
                                    Rectangle {
                                        width: notifCol.width; height: nContent.implicitHeight + 16
                                        radius: 8
                                        color: nMouse.containsMouse ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.04) : "transparent"

                                        RowLayout {
                                            id: nContent
                                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                                            spacing: 10
                                            Image {
                                                source: { let p = model.imagePath; if (!p || p === "") return ""; if (p.indexOf("://") !== -1) return p; if (p.startsWith("/")) return "file://" + p; return "image://icon/" + p; }
                                                sourceSize.width: 30; sourceSize.height: 30
                                                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                                Layout.alignment: Qt.AlignTop; visible: status === Image.Ready; smooth: true
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 2
                                                Text {
                                                    text: model.appName; color: theme.notifAppName
                                                    font { family: theme.fontFamily; pixelSize: 11 }
                                                    visible: model.appName !== ""; Layout.fillWidth: true; elide: Text.ElideRight
                                                }
                                                Text {
                                                    text: model.summary; color: theme.notifTitle
                                                    font { family: theme.fontFamily; pixelSize: 13; bold: true }
                                                    Layout.fillWidth: true; elide: Text.ElideRight
                                                }
                                                Text {
                                                    text: model.body; color: theme.notifBody
                                                    font { family: theme.fontFamily; pixelSize: 12 }
                                                    Layout.fillWidth: true; wrapMode: Text.Wrap
                                                    maximumLineCount: 2; elide: Text.ElideRight
                                                    visible: model.body !== ""; textFormat: Text.PlainText
                                                }
                                            }
                                        }
                                        Rectangle { anchors.bottom: parent.bottom; width: parent.width - 20; height: 1; anchors.horizontalCenter: parent.horizontalCenter; color: theme.textDimmed; opacity: 0.08 }
                                        MouseArea { id: nMouse; anchors.fill: parent; hoverEnabled: true }
                                    }
                                }
                            }
                        }

                        // ── Volume ──
                        Flickable {
                            anchors.fill: parent; visible: cc.activeTab === "volume"
                            contentHeight: volCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: volCol; width: parent.width; spacing: 12

                                Item { width: 1; height: 4 }

                                // Master volume
                                Rectangle {
                                    width: parent.width; height: 56; radius: theme.ccSectionRadius; color: theme.ccSectionBg

                                    Row {
                                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                                         spacing: 10

                                        Text {
                                            text: cc.muted ? theme.iconVolMute : theme.iconVolHigh
                                            color: cc.muted ? theme.textDimmed : theme.textPrimary
                                            font { family: theme.fontFamily; pixelSize: 20 }
                                            anchors.verticalCenter: parent.verticalCenter
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { cc.muted = !cc.muted; volMuteProc.running = true; } }
                                        }

                                        Item {
                                            width: parent.width - 20 - 50 - 20; height: 24; anchors.verticalCenter: parent.verticalCenter
                                            Rectangle { anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                             height: 4; radius: 2; color: theme.textDimmed; opacity: 0.3 }
                                            Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                             height: 4; radius: 2; color: theme.textAccent; width: parent.width * (cc.volume / 100) }
                                            Rectangle { width: 16; height: 16; radius: 8; color: theme.textAccent; y: (parent.height - 16) / 2; x: (parent.width - 16) * (cc.volume / 100) }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onPressed: function(mouse) { cc.setVolume(Math.round(mouse.x / parent.width * 100)); }
                                                onPositionChanged: function(mouse) { if (pressed) cc.setVolume(Math.round(mouse.x / parent.width * 100)); }
                                            }
                                        }

                                        Text {
                                            text: cc.volume + "%"; color: theme.textPrimary
                                            font { family: theme.fontFamily; pixelSize: 14; bold: true }
                                            width: 44; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }

                                // Per-app header
                                Text {
                                    text: "Applications"
                                    color: theme.textDimmed
                                    font { family: theme.fontFamily; pixelSize: 12 }
                                    leftPadding: 4
                                    visible: appVolModel.count > 0
                                }

                                // Per-app volume sliders
                                Repeater {
                                    model: appVolModel

                                    Rectangle {
                                        width: volCol.width; height: 52; radius: theme.ccSectionRadius; color: theme.ccSectionBg

                                        Row {
                                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                                             spacing: 10

                                            // App icon or fallback
                                            Item {
                                                width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter
                                                Image {
                                                    id: appIcn; anchors.fill: parent
                                                    source: model.appIcon !== "" ? "image://icon/" + model.appIcon : ""
                                                    sourceSize.width: 22; sourceSize.height: 22
                                                    visible: status === Image.Ready; smooth: true
                                                }
                                                Text {
                                                    anchors.centerIn: parent; visible: appIcn.status !== Image.Ready
                                                    text: (model.appName || "?").charAt(0).toUpperCase()
                                                    color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 12; bold: true }
                                                }
                                            }

                                            Column {
                                                width: parent.width - 22 - 20; anchors.verticalCenter: parent.verticalCenter; spacing: 2

                                                Text {
                                                    text: model.appName; color: theme.textPrimary
                                                    font { family: theme.fontFamily; pixelSize: 12 }
                                                    elide: Text.ElideRight; width: parent.width
                                                }

                                                Row {
                                                    width: parent.width; spacing: 8

                                                    Item {
                                                        width: parent.width - 44; height: 16
                                                        Rectangle { anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                                         height: 3; radius: 2; color: theme.textDimmed; opacity: 0.3 }
                                                        Rectangle {
                                                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                                            height: 3; radius: 2; color: theme.textAccent
                                                            width: parent.width * Math.min(1, (model.appVol || 0) / 100)
                                                        }
                                                        Rectangle {
                                                            width: 12; height: 12; radius: 6; color: theme.textAccent
                                                            y: (parent.height - 12) / 2
                                                            x: (parent.width - 12) * Math.min(1, (model.appVol || 0) / 100)
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                            onPressed: function(mouse) {
                                                                let v = Math.max(0, Math.min(100, Math.round(mouse.x / parent.width * 100)));
                                                                appVolModel.setProperty(index, "appVol", v);
                                                                appVolSetProc.idx = model.appIdx; appVolSetProc.vol = v; appVolSetProc.running = true;
                                                            }
                                                            onPositionChanged: function(mouse) {
                                                                if (pressed) {
                                                                    let v = Math.max(0, Math.min(100, Math.round(mouse.x / parent.width * 100)));
                                                                    appVolModel.setProperty(index, "appVol", v);
                                                                    appVolSetProc.idx = model.appIdx; appVolSetProc.vol = v; appVolSetProc.running = true;
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Text {
                                                        text: (model.appVol || 0) + "%"
                                                        color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 11 }
                                                        width: 36; horizontalAlignment: Text.AlignRight
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: appVolModel.count === 0
                                    text: "No active audio streams"
                                    color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 12 }
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
                                    visible: cc.wifiConnected; width: parent.width; height: 44; radius: 8; color: theme.ccSectionBg
                                    Row {
                                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
                                         spacing: 10
                                        Text { text: theme.iconWifiHi; color: theme.textAccent; font { family: theme.fontFamily; pixelSize: 18 }
                                         anchors.verticalCenter: parent.verticalCenter }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text { text: cc.wifiSsid; color: theme.textAccent; font { family: theme.fontFamily; pixelSize: 13; bold: true } }
                                            Text { text: "Connected"; color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 11 } }
                                        }
                                    }
                                }

                                Item { width: 1; height: cc.wifiConnected ? 4 : 0 }

                                Text {
                                    visible: wifiModel.count === 0; text: "Scanning…"; color: theme.textDimmed
                                    font { family: theme.fontFamily; pixelSize: 13 }
                                    width: parent.width; height: 50
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }

                                Repeater {
                                    model: wifiModel
                                    Rectangle {
                                        width: wifiTabCol.width; height: 36; radius: 6
                                        color: wfMouse.containsMouse ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.06) : "transparent"
                                        Row {
                                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12 }
                                             spacing: 10
                                            Text {
                                                text: model.wifiSignal > 75 ? theme.iconWifiHi : model.wifiSignal > 50 ? theme.iconWifiMid : model.wifiSignal > 25 ? theme.iconWifiLow : theme.iconWifiMin
                                                color: model.wifiActive ? theme.textAccent : theme.textDimmed
                                                font { family: theme.fontFamily; pixelSize: 16 }
                                                 anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: model.wifiSsid; color: model.wifiActive ? theme.textAccent : theme.textPrimary
                                                font { family: theme.fontFamily; pixelSize: 13; bold: model.wifiActive }
                                                anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.width - 30
                                            }
                                        }
                                        MouseArea {
                                            id: wfMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (model.wifiActive) wifiDiscProc.running = true;
                                                else { wifiConnProc.ssid = model.wifiSsid; wifiConnProc.running = true; }
                                                wifiRefresh.start();
                                            }
                                        }
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
                            text: historyModel.count + " notification" + (historyModel.count !== 1 ? "s" : "")
                            color: theme.textDimmed; font { family: theme.fontFamily; pixelSize: 12 }
                        }
                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                             spacing: 14
                            Text {
                                text: cc.dnd ? theme.iconDnd + " Silent" : theme.iconDndOff + " Silent"
                                color: cc.dnd ? theme.textWarning : theme.textDimmed
                                font { family: theme.fontFamily; pixelSize: 12 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cc.dnd = !cc.dnd }
                            }
                            Text {
                                text: theme.iconTrash + " Clear"
                                color: historyModel.count > 0 ? theme.textDimmed : Qt.rgba(theme.textDimmed.r, theme.textDimmed.g, theme.textDimmed.b, 0.3)
                                font { family: theme.fontFamily; pixelSize: 12 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cc.clearHistory() }
                            }
                        }
                    }
                }
            }
        }
    }
}
