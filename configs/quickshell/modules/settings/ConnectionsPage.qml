import QtQuick
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

// Connections page — merged Wi-Fi + Bluetooth with a sub-tab toggle.
// Replaces the Control Center's Connections tab. The services are pulled
// from ServiceManager so the page survives shell.qml rebinds, and the
// page kicks off a fresh scan whenever it mounts or the sub-tab flips.
Column {
    id: root
    width: parent ? parent.width : 0
    spacing: Root.Theme.spacingM

    // ── Service handles (reactive via ServiceManager._rev) ──
    readonly property var wifiSvc: Core.ServiceManager.wifi
    readonly property var btSvc: Core.ServiceManager.bluetooth

    // Which sub-section is showing. Persisted only for the lifetime of
    // this page instance — re-opening Settings returns to "wifi" by design.
    property string activeSection: "wifi"

    // SSID currently expanded for password entry; "" for none.
    // While set, the wifi service is told to freeze model updates so the
    // TextInput's parent row doesn't get recycled under the user.
    property string expandedSsid: ""
    property bool hiddenExpanded: false

    function _setExpanded(ssid) {
        expandedSsid = ssid;
        hiddenExpanded = false;
        if (wifiSvc) wifiSvc.freezeUpdates = (ssid !== "");
    }

    function _setHiddenExpanded(on) {
        hiddenExpanded = on;
        expandedSsid = "";
        if (wifiSvc) wifiSvc.freezeUpdates = on;
    }

    // Kick off scans when the page is first mounted by the Loader.
    // (The Control Center handles this via its own activation; here we do
    // it per-mount because the page is torn down on every nav switch.)
    Component.onCompleted: {
        if (wifiSvc) { wifiSvc.scan(); wifiSvc.loadSaved(); }
        if (btSvc && activeSection === "bluetooth") btSvc.scan();
    }

    // Auto-manage BT discovery based on which sub-tab is visible. Start
    // scanning when the user flips to Bluetooth, stop when they leave
    // (saves power — adapter radio stays in discovery mode otherwise).
    onActiveSectionChanged: {
        if (!btSvc) return;
        if (activeSection === "bluetooth") btSvc.scan();
        else btSvc.stopScan();
    }

    // Also stop discovery when the page is unmounted (user navigates away).
    Component.onDestruction: {
        if (btSvc) btSvc.stopScan();
    }

    // React to connection success: collapse any open password row so the
    // "Connected" card immediately replaces the expanded entry.
    Connections {
        target: root.wifiSvc
        function onConnectFinished(ssid, ok, message) {
            if (ok) {
                root.expandedSsid = "";
                root.hiddenExpanded = false;
            }
        }
    }

    // ── Sub-tab toggle ───────────────────────────────────────────────
    Rectangle {
        width: parent.width
        height: 36
        radius: Root.Theme.radiusSmall
        color: Root.Theme.layer1

        Row {
            anchors.fill: parent
            spacing: 0

            Repeater {
                model: [
                    { key: "wifi",      icon: Root.Icons.wifiHi, label: "Wi-Fi" },
                    { key: "bluetooth", icon: Root.Icons.btOn,   label: "Bluetooth" }
                ]
                Rectangle {
                    required property var modelData
                    width: parent.width / 2
                    height: 36
                    radius: Root.Theme.radiusSmall
                    color: root.activeSection === modelData.key
                        ? Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.2)
                        : (subTabMouse.containsMouse ? Root.Theme.layer1Hover : "transparent")
                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon + "  " + modelData.label
                        color: root.activeSection === modelData.key ? Root.Theme.domainNetwork : Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeL }
                        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                    }
                    MouseArea {
                        id: subTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activeSection = modelData.key;
                            if (modelData.key === "wifi" && root.wifiSvc) {
                                root.wifiSvc.scan();
                                root.wifiSvc.loadSaved();
                            }
                            if (modelData.key === "bluetooth" && root.btSvc) {
                                root.btSvc.scan(false);
                            }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════
    // ── Wi-Fi section ────────────────────────────────────────────────
    // ════════════════════════════════════════════════════════════════
    Column {
        width: parent.width
        spacing: Root.Theme.spacingM
        visible: root.activeSection === "wifi"

        // Connected network card
        Components.SettingSection {
            title: "CURRENT"
            width: parent.width
            visible: root.wifiSvc && root.wifiSvc.connected

            Row {
                spacing: Root.Theme.spacingM
                width: parent.width

                Text {
                    text: Root.Icons.wifiHi
                    color: Root.Theme.domainNetwork
                    font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSize4XL }
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: root.wifiSvc ? root.wifiSvc.ssid : ""
                        color: Root.Theme.textPrimary
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXL; bold: true }
                    }
                    Text {
                        text: "Connected"
                        color: Root.Theme.accentSuccess
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS; letterSpacing: Root.Theme.trackingWide }
                    }
                }
            }
        }

        // Saved networks
        Components.SettingSection {
            title: "SAVED"
            width: parent.width
            visible: root.wifiSvc && root.wifiSvc.savedNetworks.count > 0

            Repeater {
                model: root.wifiSvc ? root.wifiSvc.savedNetworks : null

                Item {
                    width: parent.width
                    height: 32

                    Components.DeviceListItem {
                        anchors { left: parent.left; right: forgetBtn.left; rightMargin: Root.Theme.spacingXS }
                        height: 32
                        icon: Root.Icons.wifiHi
                        label: model.savedSsid
                        isActive: root.wifiSvc && root.wifiSvc.connected
                                  && root.wifiSvc.ssid === model.savedSsid
                        accentColor: Root.Theme.domainNetwork
                        onClicked: {
                            if (root.wifiSvc) root.wifiSvc.connectTo(model.savedSsid, "");
                        }
                    }

                    Rectangle {
                        id: forgetBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 54; height: 22
                        radius: Root.Theme.radiusSmall
                        color: forgetMouse.containsMouse
                            ? Qt.rgba(Root.Theme.accentDanger.r, Root.Theme.accentDanger.g, Root.Theme.accentDanger.b, 0.18)
                            : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.10)
                        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                        Text {
                            anchors.centerIn: parent
                            text: "Forget"
                            color: forgetMouse.containsMouse ? Root.Theme.accentDanger : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                        }
                        MouseArea {
                            id: forgetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (root.wifiSvc) root.wifiSvc.forget(model.savedSsid); }
                        }
                    }
                }
            }
        }

        // Available networks + hidden network entry
        Components.SettingSection {
            title: "AVAILABLE"
            width: parent.width

            // Empty state while first scan is still in flight
            Text {
                visible: (root.wifiSvc ? root.wifiSvc.networks.count : 0) === 0
                text: "Scanning…"
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM }
                leftPadding: 4
                bottomPadding: 4
            }

            Repeater {
                model: root.wifiSvc ? root.wifiSvc.networks : null

                Item {
                    id: networkRow
                    property bool isExpanded: root.expandedSsid === model.wifiSsid
                    visible: !model.wifiActive
                    width: parent.width
                    height: visible ? (isExpanded ? 36 + passwordBox.height + 6 : 36) : 0

                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Components.DeviceListItem {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 36
                        icon: model.wifiSignal > 75 ? Root.Icons.wifiHi
                            : model.wifiSignal > 50 ? Root.Icons.wifiMid
                            : model.wifiSignal > 25 ? Root.Icons.wifiLow
                            : Root.Icons.wifiMin
                        label: (model.wifiSecured ? "🔒  " : "") + model.wifiSsid
                        isActive: networkRow.isExpanded
                        accentColor: Root.Theme.domainNetwork
                        onClicked: {
                            if (!root.wifiSvc) return;
                            // Open networks connect immediately.
                            if (!model.wifiSecured) {
                                root.wifiSvc.connectTo(model.wifiSsid, "");
                                return;
                            }
                            // Secured: toggle the password row.
                            if (networkRow.isExpanded) root._setExpanded("");
                            else root._setExpanded(model.wifiSsid);
                        }
                    }

                    // Inline password entry (visible only when expanded)
                    Rectangle {
                        id: passwordBox
                        anchors { top: parent.top; topMargin: 38; left: parent.left; right: parent.right }
                        height: networkRow.isExpanded ? 32 : 0
                        visible: networkRow.isExpanded
                        radius: Root.Theme.radiusSmall
                        color: Qt.rgba(Root.Theme.layer1.r, Root.Theme.layer1.g, Root.Theme.layer1.b, 0.6)
                        border.width: 1
                        border.color: Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.4)

                        Row {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                            spacing: 6

                            TextInput {
                                id: passInput
                                width: parent.width - connectBtn.width - 12
                                anchors.verticalCenter: parent.verticalCenter
                                color: Root.Theme.textPrimary
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM }
                                echoMode: TextInput.Password
                                selectByMouse: true
                                clip: true
                                focus: networkRow.isExpanded

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Password"
                                    color: Root.Theme.textDimmed
                                    font: passInput.font
                                    visible: passInput.text.length === 0
                                }

                                Keys.onReturnPressed: {
                                    if (root.wifiSvc) root.wifiSvc.connectTo(model.wifiSsid, passInput.text);
                                }
                                Keys.onEscapePressed: { root._setExpanded(""); }
                            }

                            Rectangle {
                                id: connectBtn
                                anchors.verticalCenter: parent.verticalCenter
                                width: 60; height: 22
                                radius: Root.Theme.radiusSmall
                                color: connectMouse.containsMouse
                                    ? Root.Theme.domainNetwork
                                    : Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.6)
                                Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                                Text {
                                    anchors.centerIn: parent
                                    text: (root.wifiSvc && root.wifiSvc.lastConnectStatus === "connecting"
                                           && root.wifiSvc.lastConnectSsid === model.wifiSsid)
                                          ? "…" : "Connect"
                                    color: Root.Theme.textPrimary
                                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS; bold: true }
                                }
                                MouseArea {
                                    id: connectMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.wifiSvc) root.wifiSvc.connectTo(model.wifiSsid, passInput.text);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Hidden network entry
            Item {
                id: hiddenRow
                width: parent.width
                height: root.hiddenExpanded ? 36 + hiddenBox.height + 6 : 32
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 32
                    radius: Root.Theme.radiusSmall
                    color: hiddenMouse.containsMouse
                        ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06)
                        : "transparent"

                    Row {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: Root.Theme.spacingM }
                        spacing: 10
                        Text {
                            text: Root.Icons.add
                            color: Root.Theme.domainNetwork
                            font { family: Root.Theme.fontIcons; pixelSize: Root.Theme.fontSizeXL }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Connect to hidden network"
                            color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: hiddenMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._setHiddenExpanded(!root.hiddenExpanded)
                    }
                }

                Rectangle {
                    id: hiddenBox
                    anchors { top: parent.top; topMargin: 36; left: parent.left; right: parent.right }
                    height: root.hiddenExpanded ? 64 : 0
                    visible: root.hiddenExpanded
                    radius: Root.Theme.radiusSmall
                    color: Qt.rgba(Root.Theme.layer1.r, Root.Theme.layer1.g, Root.Theme.layer1.b, 0.6)
                    border.width: 1
                    border.color: Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.4)

                    Column {
                        anchors { fill: parent; margins: 6 }
                        spacing: Root.Theme.spacingXS

                        Rectangle {
                            width: parent.width; height: 22
                            radius: Root.Theme.radiusSmall
                            color: Qt.rgba(0,0,0,0.25)
                            TextInput {
                                id: hiddenSsidInput
                                anchors { fill: parent; leftMargin: Root.Theme.spacingS; rightMargin: Root.Theme.spacingS }
                                color: Root.Theme.textPrimary
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true; clip: true
                                focus: root.hiddenExpanded
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "SSID"
                                    color: Root.Theme.textDimmed
                                    font: hiddenSsidInput.font
                                    visible: hiddenSsidInput.text.length === 0
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 6

                            Rectangle {
                                width: parent.width - hiddenConnectBtn.width - 6
                                height: 22
                                radius: Root.Theme.radiusSmall
                                color: Qt.rgba(0,0,0,0.25)
                                TextInput {
                                    id: hiddenPassInput
                                    anchors { fill: parent; leftMargin: Root.Theme.spacingS; rightMargin: Root.Theme.spacingS }
                                    color: Root.Theme.textPrimary
                                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                                    echoMode: TextInput.Password
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true; clip: true
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Password (optional)"
                                        color: Root.Theme.textDimmed
                                        font: hiddenPassInput.font
                                        visible: hiddenPassInput.text.length === 0
                                    }
                                    Keys.onReturnPressed: {
                                        if (root.wifiSvc && hiddenSsidInput.text.length > 0)
                                            root.wifiSvc.connectHidden(hiddenSsidInput.text, hiddenPassInput.text);
                                    }
                                }
                            }

                            Rectangle {
                                id: hiddenConnectBtn
                                width: 60; height: 22
                                radius: Root.Theme.radiusSmall
                                color: hiddenConnectMouse.containsMouse
                                    ? Root.Theme.domainNetwork
                                    : Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.6)
                                Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Join"
                                    color: Root.Theme.textPrimary
                                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS; bold: true }
                                }
                                MouseArea {
                                    id: hiddenConnectMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.wifiSvc && hiddenSsidInput.text.length > 0)
                                            root.wifiSvc.connectHidden(hiddenSsidInput.text, hiddenPassInput.text);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════
    // ── Bluetooth section ────────────────────────────────────────────
    // ════════════════════════════════════════════════════════════════
    Column {
        id: btCol
        width: parent.width
        spacing: Root.Theme.spacingM
        visible: root.activeSection === "bluetooth"

        // Derived sorted device lists. Paired devices first (connected on
        // top), then unpaired discovered devices with a real name. The
        // `btSvc.deviceList` read establishes the binding dependency —
        // when BlueZ adds/removes devices over D-Bus, this re-runs.
        readonly property var _pairedDevs: {
            if (!root.btSvc || !root.btSvc.adapter) return [];
            return root.btSvc.deviceList
                .filter(d => d && d.paired)
                .sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0));
        }
        readonly property var _discoveredDevs: {
            if (!root.btSvc || !root.btSvc.adapter) return [];
            return root.btSvc.deviceList
                .filter(d => d && !d.paired && (d.name || d.deviceName || "").length > 0);
        }

        // ── Adapter missing state ──
        Components.SettingSection {
            title: "BLUETOOTH"
            width: parent.width
            visible: !root.btSvc || !root.btSvc.adapter

            Text {
                text: !root.btSvc ? "Service unavailable" : "No Bluetooth adapter detected"
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM }
                leftPadding: 4
            }
        }

        // ── Adapter power toggle ──
        Components.SettingSection {
            title: "ADAPTER"
            width: parent.width
            visible: root.btSvc && root.btSvc.adapter

            Components.SettingToggle {
                label: "Bluetooth"
                description: root.btSvc && root.btSvc.enabled ? "Powered on" : "Powered off"
                isOn: root.btSvc ? root.btSvc.enabled : false
                onToggled: { if (root.btSvc) root.btSvc.toggle(); }
            }
        }

        // ── Paired / known devices ──
        Components.SettingSection {
            title: "PAIRED DEVICES"
            width: parent.width
            visible: root.btSvc && root.btSvc.adapter && root.btSvc.enabled

            Text {
                visible: btCol._pairedDevs.length === 0
                text: "No paired devices"
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeM }
                leftPadding: 4
                bottomPadding: 4
            }

            Repeater {
                model: btCol._pairedDevs

                Item {
                    required property var modelData
                    width: parent.width
                    height: 34

                    Components.DeviceListItem {
                        anchors { left: parent.left; right: forgetBtn.left; rightMargin: Root.Theme.spacingXS }
                        height: 34
                        icon: modelData.connected ? Root.Icons.btConnected : Root.Icons.btOn
                        label: (modelData.name || modelData.deviceName || modelData.address)
                               + (modelData.batteryAvailable ? "  " + Math.round(modelData.battery * 100) + "%" : "")
                        isActive: modelData.connected
                        accentColor: Root.Theme.domainNetwork
                        onClicked: {
                            if (!root.btSvc) return;
                            if (modelData.connected) root.btSvc.disconnectDevice(modelData);
                            else root.btSvc.connectDevice(modelData);
                        }
                    }

                    Rectangle {
                        id: forgetBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 54; height: 22
                        radius: Root.Theme.radiusSmall
                        color: forgetMouse.containsMouse
                            ? Qt.rgba(Root.Theme.accentDanger.r, Root.Theme.accentDanger.g, Root.Theme.accentDanger.b, 0.18)
                            : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.10)
                        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                        Text {
                            anchors.centerIn: parent
                            text: "Forget"
                            color: forgetMouse.containsMouse ? Root.Theme.accentDanger : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeXS }
                        }
                        MouseArea {
                            id: forgetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (root.btSvc) root.btSvc.forgetDevice(modelData); }
                        }
                    }
                }
            }
        }

        // ── Discovered / nearby devices ──
        Components.SettingSection {
            title: "NEARBY"
            width: parent.width
            visible: root.btSvc && root.btSvc.adapter && root.btSvc.enabled

            // Scan status + toggle button
            Row {
                width: parent.width
                spacing: Root.Theme.spacingS

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.btSvc && root.btSvc.scanning)
                          ? "Scanning for devices…"
                          : "Tap a device to pair"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                    width: parent.width - scanBtn.width - 8
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: scanBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 100; height: 26
                    radius: Root.Theme.radiusSmall
                    color: scanMouse.containsMouse
                        ? Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.18)
                        : Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.10)
                    border.width: Root.Theme.borderWidth
                    border.color: Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.3)
                    Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: (root.btSvc && root.btSvc.scanning) ? "Stop" : "Scan"
                        color: Root.Theme.domainNetwork
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS; bold: true }
                    }
                    MouseArea {
                        id: scanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.btSvc) return;
                            if (root.btSvc.scanning) root.btSvc.stopScan();
                            else root.btSvc.scan();
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }

            Text {
                visible: btCol._discoveredDevs.length === 0 && root.btSvc && !root.btSvc.scanning
                text: "No devices found yet"
                color: Root.Theme.textDimmed
                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeS }
                leftPadding: 4
            }

            Repeater {
                model: btCol._discoveredDevs

                Components.DeviceListItem {
                    required property var modelData
                    width: parent.width
                    height: 32
                    icon: Root.Icons.btOn
                    label: (modelData.name || modelData.deviceName || modelData.address)
                           + (modelData.pairing ? "  (pairing…)" : "")
                    accentColor: Root.Theme.domainNetwork
                    onClicked: { if (root.btSvc) root.btSvc.pairDevice(modelData); }
                }
            }
        }
    }

    // Bottom padding
    Item { width: 1; height: 8 }
}
