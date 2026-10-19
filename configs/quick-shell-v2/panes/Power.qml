import QtQuick
import Quickshell.Io
import ".." as Root

// Session actions. Lock runs immediately. Everything else arms, then
// Enter again (or wait out the countdown) to confirm.
Item {
    id: root
    implicitHeight: inner.implicitHeight + 16

    property int selectedIndex: 0
    property string pendingAction: ""
    property int countdown: 0
    readonly property int resultCount: actions.length

    signal ran()

    readonly property var actions: [
        { key: "l", id: "lock", label: "Lock", icon: Root.Icons.lock, color: Root.Theme.keyword },
        { key: "u", id: "suspend", label: "Suspend", icon: Root.Icons.suspend, color: Root.Theme.warning },
        { key: "o", id: "logout", label: "Logout", icon: Root.Icons.logout, color: Root.Theme.accent },
        { key: "r", id: "reboot", label: "Reboot", icon: Root.Icons.reboot, color: Root.Theme.warm },
        { key: "d", id: "shutdown", label: "Shutdown", icon: Root.Icons.shutdown, color: Root.Theme.danger }
    ]

    function activate() {
        root.selectedIndex = 0;
        cancelPending();
    }

    function reset() {
        cancelPending();
        root.selectedIndex = 0;
    }

    function requestSelected() {
        request(actions[root.selectedIndex].id);
    }

    function handleKey(event) {
        let letter = "";
        if (event.text && event.text.length === 1)
            letter = event.text.toLowerCase();
        else if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
            letter = String.fromCharCode(97 + (event.key - Qt.Key_A));
        if (letter.length === 0)
            return false;
        for (let i = 0; i < actions.length; i++) {
            if (actions[i].key === letter) {
                root.selectedIndex = i;
                request(actions[i].id);
                return true;
            }
        }
        return false;
    }

    function request(id) {
        if (id === "lock") {
            run("lock");
            root.ran();
            return;
        }
        if (root.pendingAction === id) {
            executePending();
            return;
        }
        root.pendingAction = id;
        root.countdown = 5;
        confirmTimer.restart();
    }

    function run(id) {
        if (id === "lock") lockProc.running = true;
        else if (id === "suspend") suspendProc.running = true;
        else if (id === "logout") logoutProc.running = true;
        else if (id === "reboot") rebootProc.running = true;
        else if (id === "shutdown") shutdownProc.running = true;
    }

    function executePending() {
        const id = root.pendingAction;
        cancelPending();
        if (id === "")
            return;
        run(id);
        root.ran();
    }

    function cancelPending() {
        confirmTimer.stop();
        root.pendingAction = "";
        root.countdown = 0;
    }

    Timer {
        id: confirmTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.pendingAction === "") {
                confirmTimer.stop();
                return;
            }
            root.countdown -= 1;
            if (root.countdown <= 0)
                root.executePending();
        }
    }

    Process { id: lockProc; command: ["loginctl", "lock-session"] }
    Process { id: suspendProc; command: ["systemctl", "suspend"] }
    Process { id: logoutProc; command: ["niri", "msg", "action", "quit"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: shutdownProc; command: ["systemctl", "poweroff"] }

    Column {
        id: inner
        width: parent.width
        topPadding: 12
        bottomPadding: 16
        spacing: 16

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Repeater {
                model: root.actions

                Rectangle {
                    required property var modelData
                    required property int index
                    width: 88
                    height: 96
                    radius: 12
                    color: index === root.selectedIndex ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.22) : Root.Theme.tileBg
                    border.width: 1
                    border.color: index === root.selectedIndex ? modelData.color : Root.Theme.border

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = index
                        onClicked: {
                            root.selectedIndex = index;
                            root.request(modelData.id);
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.icon
                            color: modelData.color
                            font { family: Root.Theme.fontIcon; pixelSize: 22 }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.key
                            color: Root.Theme.textMute
                            font { family: Root.Theme.fontMono; pixelSize: 12 }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: Root.Theme.text
                            font { family: Root.Theme.fontUi; pixelSize: 12 }
                        }
                    }
                }
            }
        }

        Text {
            visible: root.pendingAction === ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Enter to arm · again to confirm · Esc cancels"
            color: Root.Theme.textMute
            font { family: Root.Theme.fontUi; pixelSize: 12 }
        }

        Text {
            visible: root.pendingAction !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: {
                let verb = root.pendingAction;
                if (root.pendingAction === "suspend") verb = "Suspending";
                else if (root.pendingAction === "logout") verb = "Logging out";
                else if (root.pendingAction === "reboot") verb = "Rebooting";
                else if (root.pendingAction === "shutdown") verb = "Shutting down";
                return verb + " in " + root.countdown + "s  ·  Enter to confirm now";
            }
            color: Root.Theme.warning
            font { family: Root.Theme.fontUi; pixelSize: 13; weight: Font.DemiBold }
        }
    }
}
