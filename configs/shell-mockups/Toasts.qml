import QtQuick
import Quickshell
import Quickshell.Wayland
import "sample-data.js" as SampleData

// Notifications: each is a panel titled with its app, stacked under the
// left end of the bar where the bar counts them. A notification is wiped in
// when it arrives and wiped away when its time is up.
//
// Each one keeps the place in the stack it was given until it leaves, and a
// new one takes the highest free place. So nothing ever jumps: when one
// leaves, the ones under it stay where they are.
PanelWindow {
    id: toasts

    // The shell root (shell.qml). shell.toastList holds one entry per
    // notification on screen: which sample it shows, its serial number and
    // its place in the stack.
    required property var shell

    // The height one place takes: the panel and its shadow.
    readonly property int placeHeight: (panelRows + 2) * Theme.cellHeight + Theme.shadowOffset
    readonly property int panelRows: 3
    readonly property int panelColumns: 52

    // How many places the stack reaches down to.
    function placesInUse(): int {
        let places = 0;
        for (let index = 0; index < toasts.shell.toastList.count; index++)
            places = Math.max(places, toasts.shell.toastList.get(index).place + 1);
        return places;
    }

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
    implicitWidth: panelColumns * Theme.cellWidth + Theme.shadowOffset
    implicitHeight: Math.max(1, placesInUse()) * placeHeight
    color: "transparent"
    WlrLayershell.namespace: "shell-mockup"
    WlrLayershell.layer: WlrLayer.Overlay

    Repeater {
        model: toasts.shell.toastList

        Box {
            id: toast

            required property int sample
            required property int serial
            required property int place

            readonly property var message: SampleData.toasts[sample]
            // Set once it exists, so that it is wiped in.
            property bool arrived: false
            // Set when its time is up, so that it is wiped away.
            property bool leaving: false

            y: place * toasts.placeHeight
            columns: toasts.panelColumns
            rows: toasts.panelRows
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
