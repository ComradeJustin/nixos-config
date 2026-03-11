import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import ".." as Root

// Notification popup panel anchored to top-right.
// Uses Quickshell's built-in NotificationServer (freedesktop spec).
// This replaces mako/dunst/swaync — only one notification daemon can run.
PanelWindow {
    id: notifPanel

    Root.Theme { id: theme }

    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }
    margins.top: theme.notifMarginTop + theme.barHeight
    margins.right: theme.notifMarginRight

    implicitWidth: theme.notifWidth
    implicitHeight: notifColumn.implicitHeight
    color: "transparent"
    visible: notifModel.count > 0

    // ── Notification server ──
    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        keepOnReload: false

        onNotification: function(notification) {
            // Cap visible notifications
            if (notifModel.count >= theme.notifMaxVisible) {
                let oldest = notifModel.get(0);
                if (oldest && oldest.notifRef)
                    oldest.notifRef.expire();
                notifModel.remove(0);
            }

            // Retain so it isn't garbage collected
            notification.tracked = true;

            let timeout = theme.notifTimeout;
            // Respect urgency: critical stays longer
            if (notification.urgency === NotificationUrgency.Critical)
                timeout = timeout * 3;

            notifModel.append({
                "notifId":    notification.id,
                "appName":    notification.appName || "",
                "summary":    notification.summary || "",
                "body":       notification.body || "",
                "imagePath":  notification.image || notification.appIcon || "",
                "urgent":     notification.urgency === NotificationUrgency.Critical,
                "notifRef":   notification,
                "timeout":    timeout
            });
        }
    }

    ListModel {
        id: notifModel
    }

    Column {
        id: notifColumn
        width: theme.notifWidth
        spacing: theme.notifSpacing

        Repeater {
            model: notifModel

            Rectangle {
                id: card
                width: theme.notifWidth
                height: cardContent.implicitHeight + theme.notifPadding * 2
                radius: theme.notifRadius
                color: theme.notifBackground
                border.color: model.urgent ? theme.notifUrgentBorder : "transparent"
                border.width: model.urgent ? 2 : 0
                opacity: 1

                // ── Slide-in animation ──
                x: theme.notifWidth
                Component.onCompleted: {
                    x = 0;
                    dismissTimer.interval = model.timeout;
                    dismissTimer.start();
                }

                Behavior on x {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                // ── Auto-dismiss ──
                Timer {
                    id: dismissTimer
                    onTriggered: card.dismiss()
                }

                function dismiss() {
                    card.opacity = 0;
                    removeTimer.start();
                }

                Timer {
                    id: removeTimer
                    interval: 160
                    onTriggered: {
                        if (model.notifRef)
                            model.notifRef.expire();
                        notifModel.remove(index);
                    }
                }

                // ── Click to dismiss ──
                MouseArea {
                    anchors.fill: parent
                    onClicked: card.dismiss()
                }

                RowLayout {
                    id: cardContent
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: theme.notifPadding
                    }
                    spacing: 10

                    // ── App icon / image ──
                    // Handles file:// URIs, absolute paths, and icon names
                    Image {
                        id: notifImage
                        source: {
                            let p = model.imagePath;
                            if (!p || p === "") return "";
                            // Already a URI (file://, image://, http://, etc.)
                            if (p.indexOf("://") !== -1) return p;
                            // Absolute path
                            if (p.startsWith("/")) return "file://" + p;
                            // Icon name — try freedesktop icon lookup
                            return "image://icon/" + p;
                        }
                        sourceSize.width: theme.notifIconSize
                        sourceSize.height: theme.notifIconSize
                        Layout.preferredWidth: theme.notifIconSize
                        Layout.preferredHeight: theme.notifIconSize
                        Layout.alignment: Qt.AlignTop
                        visible: status === Image.Ready
                        smooth: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        // ── App name ──
                        Text {
                            text: model.appName
                            color: theme.notifAppName
                            font {
                                family: theme.fontFamily
                                pixelSize: theme.notifBodySize
                            }
                            visible: model.appName !== ""
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        // ── Summary (title) ──
                        Text {
                            text: model.summary
                            color: theme.notifTitle
                            font {
                                family: theme.fontFamily
                                pixelSize: theme.notifTitleSize
                                bold: true
                            }
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        // ── Body ──
                        Text {
                            text: model.body
                            color: theme.notifBody
                            font {
                                family: theme.fontFamily
                                pixelSize: theme.notifBodySize
                            }
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            visible: model.body !== ""
                            textFormat: Text.PlainText
                        }
                    }
                }
            }
        }
    }
}
