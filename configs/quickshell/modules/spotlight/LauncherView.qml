import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.." as Root

// App launcher view for the Spotlight popup.
// Caches desktop entries on load, filters by search.
Item {
    id: root
    implicitWidth: parent ? parent.width : 500
    implicitHeight: launchInner.implicitHeight

    // Theme is now a singleton - access via Root.Theme.propertyName

    property string searchText: ""
    property int selectedIndex: 0
    property var filteredIndices: []

    signal launched()

    function updateFilter() {
        let indices = [];
        let query = searchText.toLowerCase();
        for (let i = 0; i < appModel.count; i++) {
            let name = appModel.get(i).appName.toLowerCase();
            if (query.length === 0 || name.indexOf(query) !== -1)
                indices.push(i);
        }
        filteredIndices = indices;
        if (selectedIndex >= indices.length)
            selectedIndex = Math.max(0, indices.length - 1);
    }

    function resetSearch() {
        searchText = "";
        selectedIndex = 0;
        updateFilter();
    }

    function launchSelected() {
        if (filteredIndices.length === 0) return;
        let idx = filteredIndices[selectedIndex];
        let item = appModel.get(idx);

        if (item.appDbusId && item.appDbusId.length > 0) {
            dbusProc.appId = item.appDbusId;
            dbusProc.objPath = "/" + item.appDbusId.replace(/\./g, "/");
            dbusProc.running = true;
        } else {
            execProc.cmd = item.appExec;
            execProc.running = true;
        }
        launched();
    }

    function moveDown() {
        if (selectedIndex < filteredIndices.length - 1) selectedIndex++;
        appFlick.ensureVisible(selectedIndex);
    }

    function moveUp() {
        if (selectedIndex > 0) selectedIndex--;
        appFlick.ensureVisible(selectedIndex);
    }

    ListModel { id: appModel }

    // Cache on startup — resolves binary to full nix store path
    // For DBusActivatable apps, stores the app ID for D-Bus activation
    Process {
        id: cacheProc
        command: [
            "bash", "-c",
            "IFS=':'; " +
            "paths=\"$XDG_DATA_DIRS:$HOME/.local/share:/run/current-system/sw/share:/usr/share\"; " +
            "for dir in $paths; do " +
            "  [ -d \"$dir/applications\" ] && echo \"$dir/applications\"; " +
            "done | sort -u | while IFS= read -r d; do " +
            "  find \"$d\" -maxdepth 2 -name '*.desktop' 2>/dev/null; " +
            "done | sort -u | while IFS= read -r f; do " +
            "  name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "  icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-); " +
            "  exec_line=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[fFuUdDnNickvm]//g'); " +
            "  nodisplay=$(grep -m1 '^NoDisplay=' \"$f\" | cut -d= -f2-); " +
            "  type=$(grep -m1 '^Type=' \"$f\" | cut -d= -f2-); " +
            "  dbus=$(grep -m1 '^DBusActivatable=' \"$f\" | cut -d= -f2-); " +
            "  [ \"$nodisplay\" = 'true' ] && continue; " +
            "  [ \"$type\" != 'Application' ] && [ -n \"$type\" ] && continue; " +
            "  [ -z \"$name\" ] && continue; " +
            "  [ -z \"$exec_line\" ] && continue; " +
            "  bin=\"${exec_line%% *}\"; " +
            "  args=\"${exec_line#\"$bin\"}\"; " +
            "  found=$(command -v \"$bin\" 2>/dev/null || echo \"$bin\"); " +
            "  if [ -L \"$found\" ]; then " +
            "    full=$(realpath \"$found\" 2>/dev/null || echo \"$found\"); " +
            "  else " +
            "    full=\"$found\"; " +
            "  fi; " +
            "  resolved=\"${full}${args}\"; " +
            "  appid=''; " +
            "  if [ \"$dbus\" = 'true' ]; then " +
            "    appid=$(basename \"$f\" .desktop); " +
            "  fi; " +
            "  echo \"$name\t$icon\t$resolved\t$appid\"; " +
            "done | sort -t$'\\t' -k1,1f -u"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let parts = data.split("\t");
                if (parts.length < 3) return;
                appModel.append({
                    "appName":  parts[0] || "",
                    "appIcon":  parts[1] || "",
                    "appExec":  parts[2] || "",
                    "appDbusId": parts[3] || ""
                });
            }
        }
        onExited: root.updateFilter()
    }

    // For DBusActivatable apps: gdbus Activate (same as rofi)
    Process {
        id: dbusProc
        property string appId: ""
        property string objPath: ""
        command: [
            "gdbus", "call", "--session",
            "--dest", appId,
            "--object-path", objPath,
            "--method", "org.freedesktop.Application.Activate",
            "[]"
        ]
    }

    // For regular apps: run exec line directly
    // SECURITY: Use positional parameter to prevent command injection
    Process {
        id: execProc
        property string cmd: ""
        command: ["sh", "-c", "$1 &>/dev/null &", "--", cmd]
    }

    Column {
        id: launchInner
        width: parent.width
        spacing: 0

        Text {
            visible: filteredIndices.length === 0
            text: searchText.length > 0 ? "No matches" : "Loading…"
            color: Root.Theme.textDimmed
            font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.notifBodySize }
            width: parent.width; height: 60
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Flickable {
            id: appFlick
            visible: filteredIndices.length > 0
            width: parent.width
            height: Math.min(appCol.implicitHeight, Root.Theme.launchMaxHeight - 100)
            contentHeight: appCol.implicitHeight
            clip: true; boundsBehavior: Flickable.StopAtBounds

            function ensureVisible(selIdx) {
                let y = selIdx * Root.Theme.launchItemHeight;
                if (y < contentY) contentY = y;
                else if (y + Root.Theme.launchItemHeight > contentY + height)
                    contentY = y + Root.Theme.launchItemHeight - height;
            }

            Column {
                id: appCol
                width: parent.width; spacing: 0

                Repeater {
                    model: root.filteredIndices.length

                    Rectangle {
                        id: appItem
                        width: appCol.width
                        height: Root.Theme.launchItemHeight

                        property int sourceIndex: root.filteredIndices[index] ?? -1
                        property var entry: sourceIndex >= 0 ? appModel.get(sourceIndex) : null
                        property bool isSelected: index === root.selectedIndex

                        color: isSelected
                            ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.12)
                            : appMouse.containsMouse
                              ? Qt.rgba(Root.Theme.textPrimary.r, Root.Theme.textPrimary.g, Root.Theme.textPrimary.b, 0.06)
                              : "transparent"

                        RowLayout {
                            anchors {
                                left: parent.left; right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: Root.Theme.notifPadding; rightMargin: Root.Theme.notifPadding
                            }
                            spacing: 12

                            Image {
                                id: appIconImg
                                source: {
                                    if (!appItem.entry) return "";
                                    let p = appItem.entry.appIcon;
                                    if (!p || p === "") return "";
                                    if (p.indexOf("/") !== -1) return "file://" + p;
                                    return "image://icon/" + p;
                                }
                                sourceSize.width: Root.Theme.launchIconSize; sourceSize.height: Root.Theme.launchIconSize
                                Layout.preferredWidth: Root.Theme.launchIconSize; Layout.preferredHeight: Root.Theme.launchIconSize
                                visible: status === Image.Ready; smooth: true
                            }

                            Rectangle {
                                visible: appIconImg.status !== Image.Ready
                                Layout.preferredWidth: Root.Theme.launchIconSize; Layout.preferredHeight: Root.Theme.launchIconSize
                                radius: 8; color: Root.Theme.textDimmed; opacity: 0.2
                                Text {
                                    anchors.centerIn: parent
                                    text: appItem.entry ? appItem.entry.appName.charAt(0).toUpperCase() : ""
                                    color: Root.Theme.textPrimary
                                    font { family: Root.Theme.fontFamily; pixelSize: 16; bold: true }
                                }
                            }

                            Text {
                                text: appItem.entry ? appItem.entry.appName : ""
                                color: appItem.isSelected ? Root.Theme.textAccent : Root.Theme.textPrimary
                                font { family: Root.Theme.fontFamily; pixelSize: Root.Theme.notifTitleSize; bold: appItem.isSelected }
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: appMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.selectedIndex = index; root.launchSelected(); }
                            onPositionChanged: root.selectedIndex = index
                        }
                    }
                }
            }
        }
    }
}
