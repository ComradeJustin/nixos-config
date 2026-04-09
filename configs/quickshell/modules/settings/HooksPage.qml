import QtQuick
import Quickshell.Io
import "../.." as Root
import "../../components" as Components
import "../../core" as Core

// Hooks page — discovery + debug surface for HooksService. Lists every
// known event, its current binding (or "—"), and a live tail of the ten
// most recent fires so users can troubleshoot "why isn't my hook firing?".
Column {
    id: hooksCol
    width: parent ? parent.width : 0
    spacing: 16

    // Service handle — picked up reactively from ServiceManager.
    property var hooksSvc: Core.ServiceManager.hooks

    // ── Header / actions ────────────────────────────────────────
    Components.SettingSection {
        title: "HOOKS"
        width: parent.width

        Text {
            text: "Hooks bind shell events to shell commands.\nEdit ~/.config/quickshell/hooks.json — changes are picked up automatically."
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
            wrapMode: Text.WordWrap
            width: parent.width
            bottomPadding: 8
        }

        Row {
            width: parent.width
            spacing: 8

            // Edit button
            Rectangle {
                width: 140; height: 32
                radius: Root.Theme.radiusSmall
                color: editMouse.containsMouse
                    ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.18)
                    : Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.10)
                border.width: Root.Theme.borderWidth
                border.color: Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.3)
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: Root.Icons.edit + "  Edit hooks.json"
                    color: Root.Theme.accentPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
                }
                MouseArea {
                    id: editMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: openHooksProc.running = true
                }
            }

            // Reload button
            Rectangle {
                width: 110; height: 32
                radius: Root.Theme.radiusSmall
                color: reloadMouse.containsMouse
                    ? Qt.rgba(Root.Theme.base01.r, Root.Theme.base01.g, Root.Theme.base01.b, 0.95)
                    : Qt.rgba(Root.Theme.base01.r, Root.Theme.base01.g, Root.Theme.base01.b, 0.6)
                border.width: Root.Theme.borderWidth
                border.color: Root.Theme.borderColor
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: Root.Icons.reset + "  Reload"
                    color: Root.Theme.textPrimary
                    font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
                }
                MouseArea {
                    id: reloadMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (hooksCol.hooksSvc) hooksCol.hooksSvc.reload(); }
                }
            }
        }
    }

    // ── Known events list ────────────────────────────────────────
    Components.SettingSection {
        title: "AVAILABLE EVENTS"
        width: parent.width

        Repeater {
            model: hooksCol.hooksSvc ? hooksCol.hooksSvc.knownEvents : []

            Rectangle {
                required property var modelData
                width: parent.width
                height: eventCol.implicitHeight + 14
                radius: Root.Theme.radiusSmall
                color: Qt.rgba(Root.Theme.base01.r, Root.Theme.base01.g, Root.Theme.base01.b, 0.5)

                // Reactive bound state — re-checks whenever the
                // hook table reloads from disk.
                readonly property bool isBound: hooksCol.hooksSvc
                    && hooksCol.hooksSvc._table[modelData.name] !== undefined

                Column {
                    id: eventCol
                    anchors {
                        left: parent.left; leftMargin: 12
                        right: boundBadge.left; rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Row {
                        spacing: 8
                        Text {
                            text: modelData.name
                            color: Root.Theme.textPrimary
                            font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeSmall; bold: true }
                        }
                        Text {
                            text: "(" + modelData.args + ")"
                            color: Root.Theme.textDimmed
                            font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeSmall }
                        }
                    }
                    Text {
                        text: modelData.desc
                        color: Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
                        wrapMode: Text.WordWrap
                        width: eventCol.width
                    }
                }

                // Bound / unbound pill
                Rectangle {
                    id: boundBadge
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    width: boundBadgeText.implicitWidth + 14
                    height: 20
                    radius: 10
                    color: parent.isBound
                        ? Qt.rgba(Root.Theme.accentPrimary.r, Root.Theme.accentPrimary.g, Root.Theme.accentPrimary.b, 0.20)
                        : Qt.rgba(Root.Theme.textDimmed.r, Root.Theme.textDimmed.g, Root.Theme.textDimmed.b, 0.15)

                    Text {
                        id: boundBadgeText
                        anchors.centerIn: parent
                        text: parent.parent.isBound ? "bound" : "—"
                        color: parent.parent.isBound ? Root.Theme.accentPrimary : Root.Theme.textDimmed
                        font { family: Root.Theme.fontFamily; pixelSize: 10; bold: true }
                    }
                }
            }
        }
    }

    // ── Recent fires ─────────────────────────────────────────────
    Components.SettingSection {
        title: "RECENT FIRES"
        width: parent.width

        Text {
            visible: !hooksCol.hooksSvc || hooksCol.hooksSvc.recentFires.length === 0
            text: "No events fired yet."
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.fontSizeSmall }
        }

        Repeater {
            // Reverse so newest is on top.
            model: hooksCol.hooksSvc
                ? hooksCol.hooksSvc.recentFires.slice().reverse().slice(0, 10)
                : []

            Row {
                required property var modelData
                width: parent.width
                height: 22
                spacing: 8

                Text {
                    text: Qt.formatTime(new Date(modelData.ts), "hh:mm:ss")
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeSmall }
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                }
                Text {
                    text: modelData.event
                    color: modelData.bound ? Root.Theme.accentPrimary : Root.Theme.textPrimary
                    font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeSmall }
                    anchors.verticalCenter: parent.verticalCenter
                    width: 200
                    elide: Text.ElideRight
                }
                Text {
                    text: modelData.args && modelData.args.length > 0
                        ? "[" + modelData.args.join(", ") + "]"
                        : ""
                    color: Root.Theme.textDimmed
                    font { family: Root.Theme.fontMono; pixelSize: Root.Theme.fontSizeSmall }
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                }
            }
        }
    }

    Item { width: 1; height: 8 }

    // Process: open hooks.json in $EDITOR (or fall back to xdg-open).
    // Lives inside the page Column so the Loader owns its lifetime —
    // destroyed when the user navigates away.
    Process {
        id: openHooksProc
        command: [
            "sh", "-c",
            "f=\"$HOME/.config/quickshell/hooks.json\"; " +
            "mkdir -p \"$HOME/.config/quickshell\"; " +
            "[ -f \"$f\" ] || echo '{}' > \"$f\"; " +
            "xdg-open \"$f\""
        ]
    }
}
