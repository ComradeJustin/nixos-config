import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".." as Root

// App search pane. `/` filters this list; Enter launches; Esc leaves the pane.
Item {
    id: root
    implicitHeight: inner.implicitHeight + 16

    property string filterText: ""
    property int selectedIndex: 0
    readonly property int resultCount: filteredIndices.length

    property var filteredIndices: []
    signal launched()

    function activate() {
        root.filterText = "";
        root.selectedIndex = 0;
        updateFilter();
    }

    function reset() {
        root.filterText = "";
        root.selectedIndex = 0;
    }

    function launchSelected() {
        if (filteredIndices.length === 0)
            return;
        const idx = filteredIndices[root.selectedIndex];
        const item = appModel.get(idx);
        if (!item)
            return;
        launchEntry(item);
        root.launched();
    }

    function launchByQuery(query) {
        const q = query.toLowerCase();
        if (q.length === 0)
            return false;
        let bestIdx = -1;
        let bestScore = 0;
        for (let i = 0; i < appModel.count; i++) {
            const item = appModel.get(i);
            const score = scoreApp(q, item);
            if (score > bestScore) {
                bestScore = score;
                bestIdx = i;
            }
        }
        if (bestIdx < 0 || bestScore <= 0)
            return false;
        launchEntry(appModel.get(bestIdx));
        return true;
    }

    function scoreApp(query, item) {
        const name = (item.appName || "").toLowerCase();
        const bin = (item.appBin || "").toLowerCase();
        if (name === query || bin === query)
            return 100;
        if (name.startsWith(query) || bin.startsWith(query))
            return 80;
        if (name.indexOf(query) >= 0 || bin.indexOf(query) >= 0)
            return 40;
        return 0;
    }

    function launchEntry(item) {
        if (item.appDbusId && item.appDbusId.length > 0) {
            dbusProc.appId = item.appDbusId;
            dbusProc.objPath = "/" + item.appDbusId.replace(/\./g, "/");
            dbusProc.running = true;
        } else {
            execProc.cmd = item.appExec;
            execProc.running = true;
        }
    }

    function updateFilter() {
        const query = root.filterText.toLowerCase();
        const matches = [];
        for (let i = 0; i < appModel.count; i++) {
            const item = appModel.get(i);
            if (query.length === 0) {
                matches.push(i);
                continue;
            }
            const hay = ((item.appName || "") + " " + (item.appGeneric || "") + " " + (item.appBin || "")).toLowerCase();
            if (hay.indexOf(query) >= 0)
                matches.push(i);
        }
        matches.sort(function(a, b) {
            const na = appModel.get(a).appName.toLowerCase();
            const nb = appModel.get(b).appName.toLowerCase();
            if (na < nb) return -1;
            if (na > nb) return 1;
            return 0;
        });
        filteredIndices = matches;
        if (root.selectedIndex >= filteredIndices.length)
            root.selectedIndex = Math.max(0, filteredIndices.length - 1);
    }

    onFilterTextChanged: updateFilter()

    ListModel { id: appModel }

    Process {
        id: cacheProc
        running: true
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
            "  generic=$(grep -m1 '^GenericName=' \"$f\" | cut -d= -f2-); " +
            "  exec_line=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[fFuUdDnNickvm]//g'); " +
            "  nodisplay=$(grep -m1 '^NoDisplay=' \"$f\" | cut -d= -f2-); " +
            "  type=$(grep -m1 '^Type=' \"$f\" | cut -d= -f2-); " +
            "  dbus=$(grep -m1 '^DBusActivatable=' \"$f\" | cut -d= -f2-); " +
            "  [ \"$nodisplay\" = 'true' ] && continue; " +
            "  [ \"$type\" != 'Application' ] && [ -n \"$type\" ] && continue; " +
            "  [ -z \"$name\" ] && continue; " +
            "  [ -z \"$exec_line\" ] && continue; " +
            "  bin=\"${exec_line%% *}\"; " +
            "  binname=$(basename \"$bin\"); " +
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
            "  printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$name\" \"$icon\" \"$resolved\" \"$appid\" \"$generic\" \"$binname\"; " +
            "done | sort -t$'\\t' -k1,1f -u"
        ]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.split("\t");
                if (parts.length < 3)
                    return;
                appModel.append({
                    "appName": parts[0] || "",
                    "appIcon": parts[1] || "",
                    "appExec": parts[2] || "",
                    "appDbusId": parts[3] || "",
                    "appGeneric": parts[4] || "",
                    "appBin": parts[5] || ""
                });
            }
        }
        onExited: root.updateFilter()
    }

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

    Process {
        id: execProc
        property string cmd: ""
        command: ["sh", "-c", "$1 &>/dev/null &", "--", cmd]
    }

    Column {
        id: inner
        width: parent.width
        topPadding: 4
        bottomPadding: 8

        Text {
            visible: filteredIndices.length === 0
            width: parent.width
            height: 72
            text: appModel.count === 0 ? "Loading apps…" : "No apps match"
            color: Root.Theme.textDim
            font { family: Root.Theme.fontUi; pixelSize: 14 }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        ListView {
            id: appList
            visible: filteredIndices.length > 0
            width: parent.width
            height: Math.min(filteredIndices.length * Root.Theme.launchRow, 360)
            clip: true
            model: filteredIndices
            currentIndex: root.selectedIndex
            highlightMoveDuration: 80

            onCurrentIndexChanged: {
                if (root.selectedIndex !== currentIndex)
                    root.selectedIndex = currentIndex;
            }

            delegate: Rectangle {
                required property int modelData
                required property int index
                width: appList.width
                height: Root.Theme.launchRow
                color: index === root.selectedIndex ? Root.Theme.tileActive : "transparent"

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = index
                    onClicked: {
                        root.selectedIndex = index;
                        root.launchSelected();
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Root.Theme.cardPad
                    anchors.rightMargin: Root.Theme.cardPad
                    spacing: 12

                    Image {
                        id: icon
                        source: {
                            const item = appModel.get(modelData);
                            if (!item || !item.appIcon)
                                return "";
                            if (item.appIcon.indexOf("/") !== -1)
                                return "file://" + item.appIcon;
                            return Quickshell.iconPath(item.appIcon, true);
                        }
                        sourceSize.width: Root.Theme.launchIcon
                        sourceSize.height: Root.Theme.launchIcon
                        Layout.preferredWidth: Root.Theme.launchIcon
                        Layout.preferredHeight: Root.Theme.launchIcon
                        visible: status === Image.Ready
                        smooth: true
                    }

                    Rectangle {
                        visible: icon.status !== Image.Ready
                        Layout.preferredWidth: Root.Theme.launchIcon
                        Layout.preferredHeight: Root.Theme.launchIcon
                        radius: 8
                        color: Root.Theme.tileBg
                        Text {
                            anchors.centerIn: parent
                            text: {
                                const item = appModel.get(modelData);
                                return item ? item.appName.charAt(0).toUpperCase() : "";
                            }
                            color: Root.Theme.text
                            font { family: Root.Theme.fontUi; pixelSize: 14; weight: Font.DemiBold }
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            width: parent.width
                            text: {
                                const item = appModel.get(modelData);
                                return item ? item.appName : "";
                            }
                            color: index === root.selectedIndex ? Root.Theme.accent : Root.Theme.text
                            font { family: Root.Theme.fontUi; pixelSize: 13; weight: index === root.selectedIndex ? Font.DemiBold : Font.Normal }
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: {
                                const item = appModel.get(modelData);
                                return item && item.appGeneric && item.appGeneric.length > 0;
                            }
                            text: {
                                const item = appModel.get(modelData);
                                return item ? (item.appGeneric || "") : "";
                            }
                            color: Root.Theme.textDim
                            font { family: Root.Theme.fontUi; pixelSize: 11 }
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    onSelectedIndexChanged: {
        if (filteredIndices.length === 0)
            return;
        if (appList.currentIndex !== root.selectedIndex)
            appList.currentIndex = root.selectedIndex;
        appList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }
}
