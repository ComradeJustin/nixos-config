import QtQuick
import Quickshell
import Quickshell.Wayland
import "sample-data.js" as SampleData

// Notifications: each is a panel titled with its app, stacked under the
// left end of the bar where the bar counts them. A notification is wiped in
// when it arrives and wiped away when its time is up or it is dismissed by
// hand. An urgent one has its border in the alert colour and no time
// limit: it stays until it is dismissed.
//
// A click on a notification opens it in the Inbox; a right click dismisses
// it.
//
// Each one keeps the place in the stack it was given until it leaves, and a
// new one takes the highest free place. So nothing ever jumps: when one
// leaves, the ones under it stay where they are. The one exception is an
// urgent notification, which outlasts the rest: when a place above it comes
// free it moves up, wiped away where it was and wiped in again higher.
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
            readonly property bool urgent: message.alert === true
            // Set when its time is up, or when it is dismissed by hand, so
            // that it is wiped away.
            property bool timedOut: false
            property bool dismissed: false
            readonly property bool leaving: timedOut || dismissed
            // Set while it is wiped away to move to a higher place.
            property bool moving: false

            Connections {
                target: toasts.shell

                function onDismissedSerialChanged(): void {
                    if (toasts.shell.dismissedSerial === toast.serial)
                        toast.dismissed = true;
                }
            }

            // Another notification came or went: an urgent one checks
            // whether a place above it is free now.
            Connections {
                target: toasts.shell.toastList
                enabled: toast.urgent

                function onCountChanged(): void {
                    if (toasts.shell.freePlaceAbove(toast.place) >= 0)
                        toast.moving = true;
                }
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: (point, button) => {
                    if (button === Qt.LeftButton)
                        toasts.shell.openPage("notification");
                    toasts.shell.dismissToast(toast.serial);
                }
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            y: place * toasts.placeHeight
            columns: toasts.panelColumns
            rows: toasts.panelRows
            // The same bell the bar counts notifications with.
            title: "\uf0f3 " + message.app
            titleColor: urgent ? Theme.alert : Theme.ink
            lineColor: urgent ? Theme.alert : Theme.line
            footer: urgent ? "stays until dismissed" : "now"
            shown: arrived && !leaving && !moving ? 1 : 0

            Behavior on shown {
                NumberAnimation {
                    duration: Theme.wipeMs
                }
            }

            // Once it has been wiped away it either leaves the list or, if
            // it was only moving, takes its new place and is wiped back in.
            // Leaving is put off until this handler has returned, because
            // the handler belongs to the panel being removed. Each
            // notification queues its own function: Qt runs a function
            // queued twice in one frame only once, which would leave one
            // of two that finish together behind.
            onShownChanged: {
                if (shown !== 0)
                    return;
                if (leaving) {
                    const finishedSerial = toast.serial;
                    Qt.callLater(() => toasts.shell.removeToast(finishedSerial));
                } else if (moving) {
                    const freePlace = toasts.shell.freePlaceAbove(toast.place);
                    if (freePlace >= 0)
                        toasts.shell.moveToast(toast.serial, freePlace);
                    moving = false;
                }
            }

            Component.onCompleted: arrived = true

            Timer {
                interval: 4500
                running: !toast.urgent
                onTriggered: toast.timedOut = true
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
