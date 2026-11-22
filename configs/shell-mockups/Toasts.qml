import QtQuick
import Quickshell
import Quickshell.Wayland
import "sample-data.js" as SampleData

// Notifications: each is a panel titled with its app, stacked under the
// left end of the bar where the bar counts them. A notification is wiped in
// when it arrives and wiped away when its time is up.
PanelWindow {
    id: toasts

    // The shell root (shell.qml). shell.toastList holds one entry per
    // notification on screen: which sample it shows and its serial number.
    required property var shell

    visible: shell.toastList.count > 0
    anchors {
        top: true
        left: true
    }
    margins.left: Theme.cellWidth
    // Directly under the bar, or against the top of the screen when a
    // fullscreen window has covered the bar.
    margins.top: shell.fullscreen ? 0 : Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: stack.width
    implicitHeight: stack.height
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Overlay

    Column {
        id: stack

        Repeater {
            model: toasts.shell.toastList

            Box {
                id: toast

                required property int sample
                required property int serial

                readonly property var message: SampleData.toasts[sample]
                // Set once it exists, so that it is wiped in.
                property bool arrived: false
                // Set when its time is up, so that it is wiped away.
                property bool leaving: false

                columns: 52
                rows: 3
                title: "✦ " + message.app
                titleColor: message.alert ? Theme.alert : Theme.ink
                footer: "now"
                shown: arrived && !leaving ? 1 : 0

                Behavior on shown {
                    NumberAnimation {
                        duration: Theme.wipeMs
                    }
                }

                // Once it has been wiped away it leaves the list. Not from
                // inside this handler, which belongs to the panel being removed.
                onShownChanged: {
                    if (leaving && shown === 0)
                        Qt.callLater(toasts.shell.removeToast, toast.serial);
                }

                Component.onCompleted: arrived = true

                Timer {
                    interval: 4500
                    running: true
                    onTriggered: toast.leaving = true
                }

                Label {
                    text: toast.message.title
                    color: Theme.ink
                }

                Label {
                    y: Theme.cellHeight
                    text: toast.message.body
                }

                // What can be done with it.
                Label {
                    y: 2 * Theme.cellHeight
                    text: toast.message.actions
                    color: Theme.inkDim
                }
            }
        }
    }
}
