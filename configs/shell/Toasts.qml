import QtQuick
import Quickshell
import Quickshell.Wayland

// Notifications on screen: each is a panel titled with its app, stacked
// under the left end of the bar where the bar counts them. A notification
// is wiped in when it arrives and wiped away when its time is up, when it
// is dismissed, or when its app takes it back. An urgent one has its
// border in the alert colour and no time limit: it stays until dismissed.
//
// A click does the notification's first action, if it has one, and
// dismisses it; a right click only dismisses it.
//
// Each one keeps the place in the stack it was given until it leaves, and a
// new one takes the highest free place. So nothing ever jumps: when one
// leaves, the ones under it stay where they are. The one exception is an
// urgent notification, which outlasts the rest: when a place above it comes
// free it moves up, wiped away where it was and wiped in again higher.
PanelWindow {
    id: toasts

    // The shell root (shell.qml). shell.toastList holds one entry per
    // notification on screen: its id, its place in the stack, and its
    // words as they were when it arrived.
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
    WlrLayershell.namespace: "shell"
    WlrLayershell.layer: WlrLayer.Overlay

    Repeater {
        model: toasts.shell.toastList

        Box {
            id: toast

            required property int notificationId
            required property int place
            required property string app
            required property string summary
            required property string body
            required property string actions
            required property bool urgent
            // How long it shows, in milliseconds.
            required property int lifetime

            // Set once it exists, so that it is wiped in.
            property bool arrived: false
            // Set when its time is up, so that it is wiped away.
            property bool timedOut: false
            // The notification is no longer waiting: it was dismissed, or
            // its app took it back.
            readonly property bool closed: toasts.shell.notificationWithId(notificationId) === null
            readonly property bool leaving: timedOut || closed
            // Set while it is wiped away to move to a higher place.
            property bool moving: false

            y: place * toasts.placeHeight
            columns: toasts.panelColumns
            rows: toasts.panelRows
            // The font's bell icon, as in the bar.
            title: " " + app
            titleColor: urgent ? Theme.alert : Theme.ink
            lineColor: urgent ? Theme.alert : Theme.line
            footer: urgent ? "stays until dismissed" : ""
            shown: arrived && !leaving && !moving ? 1 : 0

            Behavior on shown {
                NumberAnimation {
                    duration: Theme.wipeMs
                }
            }

            // Once it has been wiped away it either leaves the screen or,
            // if it was only moving, takes its new place and is wiped back
            // in. Leaving is put off until this handler has returned,
            // because the handler belongs to the panel being removed. Each
            // notification queues its own function: Qt runs a function
            // queued twice in one frame only once, which would leave one
            // of two that finish together behind.
            onShownChanged: {
                // Before it has arrived there is nothing to wipe away yet:
                // a panel starts out not shown, and for its first moment
                // the notification is not in the waiting list either.
                if (shown !== 0 || !arrived)
                    return;
                if (leaving) {
                    const finishedId = toast.notificationId;
                    const ranOutOfTime = toast.timedOut;
                    Qt.callLater(() => toasts.shell.removeToast(finishedId, ranOutOfTime));
                } else if (moving) {
                    const freePlace = toasts.shell.freePlaceAbove(toast.place);
                    if (freePlace >= 0)
                        toasts.shell.moveToast(toast.notificationId, freePlace);
                    moving = false;
                }
            }

            Component.onCompleted: arrived = true

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

            Timer {
                interval: toast.lifetime
                running: !toast.urgent
                onTriggered: toast.timedOut = true
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: (point, button) => {
                    if (button === Qt.LeftButton)
                        toasts.shell.actOnNotification(toast.notificationId);
                    else
                        toasts.shell.dismissNotification(toast.notificationId);
                }
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            Label {
                width: parent.width
                text: toast.summary
                color: Theme.ink
                elide: Text.ElideRight
            }

            Label {
                y: Theme.cellHeight
                width: parent.width
                text: toast.body
                elide: Text.ElideRight
            }

            // What a click does.
            Label {
                y: 2 * Theme.cellHeight
                width: parent.width
                text: toast.actions
                color: Theme.inkDim
                elide: Text.ElideRight
            }
        }
    }
}
