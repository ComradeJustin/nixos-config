import QtQuick
import QtQuick.Layouts
import "../.." as Root
import "../../components" as Components

// Merged Wifi + Bluetooth connections tab for ControlCenter
Item {
    id: root

    property var wifiService: null
    property var bluetoothService: null

    property string activeSection: "wifi"  // "wifi" or "bluetooth"

    // SSID currently expanded for password entry; "" for none.
    // While set, the wifi service is told to freeze model updates.
    property string expandedSsid: ""
    property bool hiddenExpanded: false

    function _setExpanded(ssid) {
        expandedSsid = ssid;
        hiddenExpanded = false;
        if (root.wifiService) root.wifiService.freezeUpdates = (ssid !== "");
    }

    function _setHiddenExpanded(on) {
        hiddenExpanded = on;
        expandedSsid = "";
        if (root.wifiService) root.wifiService.freezeUpdates = on;
    }

    // React to connection success: collapse password row.
    Connections {
        target: root.wifiService
        function onConnectFinished(ssid, ok, message) {
            if (ok) {
                root.expandedSsid = "";
                root.hiddenExpanded = false;
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 6

        // ── Sub-tab toggle ──
        Rectangle {
            width: parent.width; height: 28
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
                        width: parent.width / 2; height: 28
                        radius: Root.Theme.radiusSmall
                        color: root.activeSection === modelData.key
                            ? Qt.rgba(Root.Theme.domainNetwork.r, Root.Theme.domainNetwork.g, Root.Theme.domainNetwork.b, 0.2)
                            : (subTabMouse.containsMouse ? Root.Theme.layer1Hover : "transparent")
                        Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon + "  " + modelData.label
                            color: root.activeSection === modelData.key ? Root.Theme.domainNetwork : Root.Theme.textDimmed
                            font { family: Root.Theme.fontFamily; pixelSize: 11 }
                            Behavior on color { ColorAnimation { duration: Root.Theme.anim.microDuration } }
                        }
                        MouseArea {
                            id: subTabMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeSection = modelData.key;
                                if (modelData.key === "wifi" && root.wifiService) {
                                    root.wifiService.scan();
                                    root.wifiService.loadSaved();
                                }
                                if (modelData.key === "bluetooth" && root.bluetoothService) root.bluetoothService.scan(false);
                            }
                        }
                    }
                }
            }
        }

        // ── Wifi content ──
        Components.SmoothFlickable {
            width: parent.width
            height: parent.height - 34
            visible: opacity > 0
            opacity: root.activeSection === "wifi" ? 1 : 0
            transform: Translate {
                y: root.activeSection === "wifi" ? 0 : 4
                Behavior on y { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
            }
            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
            contentHeight: wifiCol.implicitHeight
            clip: true

            Column {
                id: wifiCol
                width: parent.width
                spacing: 4

                // Connected network card
                Rectangle {
                    visible: root.wifiService && root.wifiService.connected
                    width: parent.width
                    height: 44
                    radius: Root.Theme.ccSectionRadius
                    color: Root.Theme.ccSectionBg

                    Row {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
                        spacing: 10

                        Text {
                            text: Root.Icons.wifiHi
                            color: Root.Theme.domainNetwork
                            font { family: Root.Theme.fontFamily; pixelSize: 18 }
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: root.wifiService ? root.wifiService.ssid : ""
                                color: Root.Theme.textPrimary
                                font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true }
                            }
                            Text {
                                text: "Connected"
                                color: Root.Theme.accentSuccess
                                font { family: Root.Theme.fontFamily; pixelSize: 10; letterSpacing: 1 }
                            }
                        }
                    }
                }

                Components.Separator {
                    visible: root.wifiService && root.wifiService.connected
                }

                Components.EmptyState {
                    visible: (root.wifiService ? root.wifiService.networks.count : 0) === 0
                    message: "Scanning..."
                }

                // ── Saved networks ──
                Text {
                    visible: root.wifiService ? root.wifiService.savedNetworks.count > 0 : false
                    text: "Saved"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: 12 }
                    leftPadding: 4
                }

                Repeater {
                    model: root.wifiService ? root.wifiService.savedNetworks : null

                    Item {
                        width: wifiCol.width
                        height: 32

                        Components.DeviceListItem {
                            anchors { left: parent.left; right: forgetBtn.left; rightMargin: 4 }
                            height: 32
                            icon: Root.Icons.wifiHi
                            label: model.savedSsid
                            isActive: root.wifiService && root.wifiService.connected
                                      && root.wifiService.ssid === model.savedSsid
                            accentColor: Root.Theme.domainNetwork
                            onClicked: {
                                if (root.wifiService) root.wifiService.connectTo(model.savedSsid, "");
                            }
                        }

                        // Forget button
                        Rectangle {
                            id: forgetBtn
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 50; height: 22
                            radius: Root.Theme.radiusSmall
                            color: forgetMouse.containsMouse
                                ? Qt.rgba(Root.Theme.accentDanger.r, Root.Theme.accentDanger.g, Root.Theme.accentDanger.b, 0.18)
                                : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.10)
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "Forget"
                                color: forgetMouse.containsMouse ? Root.Theme.accentDanger : Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: 10 }
                            }
                            MouseArea {
                                id: forgetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { if (root.wifiService) root.wifiService.forget(model.savedSsid); }
                            }
                        }
                    }
                }

                // ── Available networks ──
                Text {
                    visible: {
                        if (!root.wifiService) return false;
                        var count = 0;
                        for (var i = 0; i < root.wifiService.networks.count; i++) {
                            if (!root.wifiService.networks.get(i).wifiActive) count++;
                        }
                        return count > 0;
                    }
                    text: "Available"
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontFamily; pixelSize: 12 }
                    leftPadding: 4
                }

                Repeater {
                    model: root.wifiService ? root.wifiService.networks : null

                    // Wrapper that grows vertically when this network is expanded
                    // for password entry. Inactive (non-connected) entries only.
                    Item {
                        id: networkRow
                        property bool isExpanded: root.expandedSsid === model.wifiSsid
                        visible: !model.wifiActive
                        width: wifiCol.width
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
                                if (!root.wifiService) return;
                                // Open networks: connect immediately.
                                if (!model.wifiSecured) {
                                    root.wifiService.connectTo(model.wifiSsid, "");
                                    return;
                                }
                                // Secured: toggle password entry expansion
                                if (networkRow.isExpanded) {
                                    root._setExpanded("");
                                } else {
                                    root._setExpanded(model.wifiSsid);
                                }
                            }
                        }

                        // ── Password entry row (expanded) ──
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
                                    font { family: Root.Theme.fontFamily; pixelSize: 12 }
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
                                        if (root.wifiService) root.wifiService.connectTo(model.wifiSsid, passInput.text);
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
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: (root.wifiService && root.wifiService.lastConnectStatus === "connecting"
                                               && root.wifiService.lastConnectSsid === model.wifiSsid)
                                              ? "..." : "Connect"
                                        color: Root.Theme.textPrimary
                                        font { family: Root.Theme.fontFamily; pixelSize: 10; bold: true }
                                    }
                                    MouseArea {
                                        id: connectMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.wifiService) root.wifiService.connectTo(model.wifiSsid, passInput.text);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Hidden network entry ──
                Item {
                    id: hiddenRow
                    width: wifiCol.width
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
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
                            spacing: 10
                            Text {
                                text: Root.Icons.add
                                color: Root.Theme.domainNetwork
                                font { family: Root.Theme.fontFamily; pixelSize: 14 }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Connect to hidden network"
                                color: Root.Theme.textDimmed
                                font { family: Root.Theme.fontFamily; pixelSize: 12 }
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
                            spacing: 4

                            Rectangle {
                                width: parent.width; height: 22
                                radius: Root.Theme.radiusSmall
                                color: Qt.rgba(0,0,0,0.25)
                                TextInput {
                                    id: hiddenSsidInput
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                    color: Root.Theme.textPrimary
                                    font { family: Root.Theme.fontFamily; pixelSize: 11 }
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
                                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                        color: Root.Theme.textPrimary
                                        font { family: Root.Theme.fontFamily; pixelSize: 11 }
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
                                            if (root.wifiService && hiddenSsidInput.text.length > 0)
                                                root.wifiService.connectHidden(hiddenSsidInput.text, hiddenPassInput.text);
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
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Join"
                                        color: Root.Theme.textPrimary
                                        font { family: Root.Theme.fontFamily; pixelSize: 10; bold: true }
                                    }
                                    MouseArea {
                                        id: hiddenConnectMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.wifiService && hiddenSsidInput.text.length > 0)
                                                root.wifiService.connectHidden(hiddenSsidInput.text, hiddenPassInput.text);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Bluetooth content ──
        Components.SmoothFlickable {
            width: parent.width
            height: parent.height - 34
            visible: opacity > 0
            opacity: root.activeSection === "bluetooth" ? 1 : 0
            transform: Translate {
                y: root.activeSection === "bluetooth" ? 0 : 4
                Behavior on y { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
            }
            Behavior on opacity { NumberAnimation { duration: Root.Theme.anim.enterDuration; easing.type: Easing.OutCubic } }
            contentHeight: btCol.implicitHeight
            clip: true

            Column {
                id: btCol
                width: parent.width
                spacing: 4

                // Connected device card
                Rectangle {
                    visible: root.bluetoothService && root.bluetoothService.connected
                    width: parent.width
                    height: 44
                    radius: Root.Theme.ccSectionRadius
                    color: Root.Theme.ccSectionBg

                    Row {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
                        spacing: 10

                        Text {
                            text: Root.Icons.btConnected
                            color: Root.Theme.domainNetwork
                            font { family: Root.Theme.fontFamily; pixelSize: 18 }
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: root.bluetoothService ? root.bluetoothService.connectedDevice : ""
                                color: Root.Theme.textPrimary
                                font { family: Root.Theme.fontFamily; pixelSize: 13; bold: true }
                            }
                            Text {
                                text: "Connected"
                                color: Root.Theme.accentSuccess
                                font { family: Root.Theme.fontFamily; pixelSize: 10; letterSpacing: 1 }
                            }
                        }
                    }
                }

                Components.Separator {
                    visible: root.bluetoothService && root.bluetoothService.connected
                }

                Components.EmptyState {
                    visible: root.bluetoothService ? root.bluetoothService.scanning : false
                    message: "Scanning..."
                    preferredHeight: 40
                }

                Components.EmptyState {
                    visible: (root.bluetoothService ? root.bluetoothService.devices.count : 0) === 0 && !(root.bluetoothService && root.bluetoothService.scanning)
                    message: "No devices"
                }

                Text {
                    visible: root.bluetoothService ? root.bluetoothService.devices.count > 0 : false
                    text: "Paired"
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: 12; bold: true }
                    leftPadding: 4
                }

                Repeater {
                    model: root.bluetoothService ? root.bluetoothService.devices : null

                    Components.DeviceListItem {
                        width: btCol.width
                        icon: model.btConnected ? Root.Icons.btConnected : Root.Icons.btOn
                        label: model.btName
                        isActive: model.btConnected
                        accentColor: Root.Theme.domainNetwork
                        onClicked: {
                            if (root.bluetoothService) {
                                if (model.btConnected)
                                    root.bluetoothService.disconnect(model.btMac);
                                else
                                    root.bluetoothService.connect(model.btMac);
                            }
                        }
                    }
                }
            }
        }
    }
}
