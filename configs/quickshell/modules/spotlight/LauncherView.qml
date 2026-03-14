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

    Root.Theme { id: theme }

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
        execProc.cmd = item.appExec;
        execProc.running = true;
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

    // Cache on startup
    Process {
        id: cacheProc
        command: [
            "bash", "-c",
            "find /run/current-system/sw/share/applications " +
            "$HOME/.local/share/applications " +
            "$HOME/.nix-profile/share/applications " +
            "/usr/share/applications " +
            "-name '*.desktop' 2>/dev/null | sort -u | while IFS= read -r f; do " +
            "  name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "  icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-); " +
            "  exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[fFuUdDnNickvm]//g'); " +
            "  nodisplay=$(grep -m1 '^NoDisplay=' \"$f\" | cut -d= -f2-); " +
            "  [ \"$nodisplay\" = 'true' ] && continue; " +
            "  [ -z \"$name\" ] && continue; " +
            "  echo \"$name\t$icon\t$exec\"; " +
            "done | sort -t$'\\t' -k1,1f -u"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let parts = data.split("\t");
                if (parts.length < 3) return;
                appModel.append({
                    "appName": parts[0] || "",
                    "appIcon": parts[1] || "",
                    "appExec": parts[2] || ""
                });
            }
        }
        onExited: root.updateFilter()
    }

    Process {
        id: execProc
        property string cmd: ""
        command: ["bash", "-c", "exec " + cmd + " &"]
    }

    Column {
        id: launchInner
        width: parent.width
        spacing: 0

        Text {
            visible: filteredIndices.length === 0
            text: searchText.length > 0 ? "No matches" : "Loading…"
            color: theme.textDimmed
            font { family: theme.fontFamily; pixelSize: theme.notifBodySize }
            width: parent.width; height: 60
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Flickable {
            id: appFlick
            visible: filteredIndices.length > 0
            width: parent.width
            height: Math.min(appCol.implicitHeight, theme.launchMaxHeight - 100)
            contentHeight: appCol.implicitHeight
            clip: true; boundsBehavior: Flickable.StopAtBounds

            function ensureVisible(selIdx) {
                let y = selIdx * theme.launchItemHeight;
                if (y < contentY) contentY = y;
                else if (y + theme.launchItemHeight > contentY + height)
                    contentY = y + theme.launchItemHeight - height;
            }

            Column {
                id: appCol
                width: parent.width; spacing: 0

                Repeater {
                    model: root.filteredIndices.length

                    Rectangle {
                        id: appItem
                        width: appCol.width
                        height: theme.launchItemHeight

                        property int sourceIndex: root.filteredIndices[index] ?? -1
                        property var entry: sourceIndex >= 0 ? appModel.get(sourceIndex) : null
                        property bool isSelected: index === root.selectedIndex

                        color: isSelected
                            ? Qt.rgba(theme.textAccent.r, theme.textAccent.g, theme.textAccent.b, 0.12)
                            : appMouse.containsMouse
                              ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.06)
                              : "transparent"

                        RowLayout {
                            anchors {
                                left: parent.left; right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: theme.notifPadding; rightMargin: theme.notifPadding
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
                                sourceSize.width: theme.launchIconSize; sourceSize.height: theme.launchIconSize
                                Layout.preferredWidth: theme.launchIconSize; Layout.preferredHeight: theme.launchIconSize
                                visible: status === Image.Ready; smooth: true
                            }

                            Rectangle {
                                visible: appIconImg.status !== Image.Ready
                                Layout.preferredWidth: theme.launchIconSize; Layout.preferredHeight: theme.launchIconSize
                                radius: 8; color: theme.textDimmed; opacity: 0.2
                                Text {
                                    anchors.centerIn: parent
                                    text: appItem.entry ? appItem.entry.appName.charAt(0).toUpperCase() : ""
                                    color: theme.textPrimary
                                    font { family: theme.fontFamily; pixelSize: 16; bold: true }
                                }
                            }

                            Text {
                                text: appItem.entry ? appItem.entry.appName : ""
                                color: appItem.isSelected ? theme.textAccent : theme.textPrimary
                                font { family: theme.fontFamily; pixelSize: theme.notifTitleSize; bold: appItem.isSelected }
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
