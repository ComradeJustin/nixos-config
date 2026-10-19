import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "." as Root
import "panes" as Panes

// Vim launcher overlay.
//
// Mod+Space opens this card and keeps it up.
//   normal  — letter keys open panes (s/w/c/p); hjkl moves the highlight
//   /       — filter the current body (map tiles, or the open pane)
//   :       — command line only (nothing runs from loose typing)
//   Esc     — command/filter → normal → pane→map → close
Scope {
    id: root

    property bool showing: false
    property string pane: ""
    property string mode: "normal"
    property string filterText: ""
    property string commandText: ""
    property string commandMessage: ""
    property int selectedIndex: 0
    property int commandMatchIndex: 0
    property bool cursorOn: true

    // One table drives :help, live matches, Tab complete, and Enter.
    readonly property var commandList: [
        { name: "help", aliases: ["h"], summary: "list commands" },
        { name: "firefox", aliases: [], summary: "launch firefox" },
        { name: "terminal", aliases: ["ghostty"], summary: "open ghostty" },
        { name: "search", aliases: ["s"], summary: "open app search" },
        { name: "wallpaper", aliases: ["w"], summary: "set wallpaper" },
        { name: "settings", aliases: ["c"], summary: "shell settings" },
        { name: "power", aliases: ["p"], summary: "session menu" },
        { name: "lock", aliases: [], summary: "lock the session" },
        { name: "suspend", aliases: [], summary: "suspend the machine" },
        { name: "logout", aliases: [], summary: "quit niri" },
        { name: "reboot", aliases: [], summary: "reboot the machine" },
        { name: "shutdown", aliases: ["poweroff"], summary: "power off" },
        { name: "quit", aliases: ["q", "close"], summary: "close this overlay" }
    ]

    readonly property var commandMatches: {
        const query = root.commandText.trim().toLowerCase();
        const scored = [];
        for (let i = 0; i < root.commandList.length; i++) {
            const cmd = root.commandList[i];
            const score = root.scoreCommand(query, cmd);
            if (score > 0)
                scored.push({ cmd: cmd, score: score });
        }
        scored.sort(function(a, b) {
            if (b.score !== a.score)
                return b.score - a.score;
            if (a.cmd.name < b.cmd.name)
                return -1;
            if (a.cmd.name > b.cmd.name)
                return 1;
            return 0;
        });
        const matches = [];
        for (let i = 0; i < scored.length; i++)
            matches.push(scored[i].cmd);
        return matches;
    }

    readonly property var panes: [
        { key: "b", id: "firefox", label: "Firefox", hint: "Mod+B", color: Root.Theme.warm, kind: "spawn", spawn: ["firefox"] },
        { key: "t", id: "terminal", label: "Terminal", hint: "Mod+Return", color: Root.Theme.accent, kind: "spawn", spawn: ["ghostty", "+new-window"] },
        { key: "s", id: "search", label: "Search", hint: "apps", color: Root.Theme.accent, kind: "pane" },
        { key: "w", id: "wallpaper", label: "Wallpaper", hint: "set background", color: Root.Theme.success, kind: "pane" },
        { key: "c", id: "settings", label: "Settings", hint: "shell", color: Root.Theme.keyword, kind: "pane" },
        { key: "p", id: "power", label: "Power", hint: "session", color: Root.Theme.danger, kind: "pane" }
    ]

    readonly property var visiblePanes: {
        const query = root.filterText.toLowerCase();
        const matches = [];
        for (let i = 0; i < root.panes.length; i++) {
            const pane = root.panes[i];
            if (query.length === 0) {
                matches.push(pane);
                continue;
            }
            const haystack = (pane.key + " " + pane.label + " " + pane.hint).toLowerCase();
            if (haystack.indexOf(query) >= 0)
                matches.push(pane);
        }
        return matches;
    }

    function toggle() {
        if (root.showing)
            root.close();
        else
            root.open();
    }

    function open() {
        root.pane = "";
        root.mode = "normal";
        root.filterText = "";
        root.commandText = "";
        root.commandMessage = "";
        root.selectedIndex = 0;
        root.showing = true;
        keyCatcher.forceActiveFocus();
    }

    function close() {
        root.showing = false;
        root.pane = "";
        root.mode = "normal";
        root.filterText = "";
        root.commandText = "";
        searchPane.reset();
        wallpaperPane.reset();
        powerPane.reset();
    }

    function enterPane(id) {
        root.pane = id;
        root.mode = "normal";
        root.filterText = "";
        root.commandMessage = "";
        root.selectedIndex = 0;
        if (id === "search")
            searchPane.activate();
        else if (id === "wallpaper")
            wallpaperPane.activate();
        else if (id === "power")
            powerPane.activate();
        keyCatcher.forceActiveFocus();
    }

    function activateItem(item) {
        if (!item)
            return;
        if (item.kind === "spawn") {
            root.spawnAndClose(item.spawn);
            return;
        }
        root.enterPane(item.id);
    }

    function spawnAndClose(args) {
        spawnProc.command = args;
        spawnProc.running = true;
        root.close();
    }

    function enterFilter() {
        root.mode = "filter";
        root.commandMessage = "";
        root.cursorOn = true;
        Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
    }

    function enterCommand() {
        root.mode = "command";
        root.commandText = "";
        root.commandMessage = "";
        root.commandMatchIndex = 0;
        root.cursorOn = true;
        Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
    }

    function backToNormal() {
        root.mode = "normal";
        root.commandText = "";
        if (root.pane === "")
            root.filterText = "";
        Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
    }

    function handleEscape() {
        if (root.mode === "command") {
            root.backToNormal();
            return;
        }
        if (root.mode === "filter") {
            root.backToNormal();
            return;
        }
        if (root.pane === "power" && powerPane.pendingAction !== "") {
            powerPane.cancelPending();
            return;
        }
        if (root.pane !== "") {
            root.pane = "";
            root.filterText = "";
            root.selectedIndex = 0;
            searchPane.reset();
            wallpaperPane.reset();
            powerPane.reset();
            Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
            return;
        }
        root.close();
    }

    function clampSelection() {
        const count = root.bodyCount();
        if (count <= 0) {
            root.selectedIndex = 0;
            return;
        }
        if (root.selectedIndex < 0)
            root.selectedIndex = 0;
        if (root.selectedIndex >= count)
            root.selectedIndex = count - 1;
    }

    function bodyCount() {
        if (root.pane === "search")
            return searchPane.resultCount;
        if (root.pane === "wallpaper")
            return wallpaperPane.resultCount;
        if (root.pane === "power")
            return powerPane.resultCount;
        if (root.pane === "settings")
            return 0;
        return root.visiblePanes.length;
    }

    function gridColumns() {
        if (root.pane === "wallpaper")
            return wallpaperPane.columns;
        if (root.pane === "power")
            return Math.max(1, powerPane.resultCount);
        if (root.pane === "search" || root.pane === "settings")
            return 1;
        return 1;
    }

    function applySelection(next) {
        root.selectedIndex = next;
        if (root.pane === "search")
            searchPane.selectedIndex = next;
        else if (root.pane === "wallpaper")
            wallpaperPane.selectedIndex = next;
        else if (root.pane === "power")
            powerPane.selectedIndex = next;
    }

    // Stay on the same row for left/right, same column for up/down.
    function moveGrid(dx, dy) {
        const count = root.bodyCount();
        if (count <= 0)
            return;
        const cols = root.gridColumns();
        const index = root.selectedIndex;
        const col = index % cols;
        const row = Math.floor(index / cols);

        if (dx !== 0) {
            const nextCol = col + dx;
            if (nextCol < 0 || nextCol >= cols)
                return;
            const next = row * cols + nextCol;
            if (next >= count)
                return;
            root.applySelection(next);
            return;
        }

        if (dy !== 0) {
            const nextRow = row + dy;
            if (nextRow < 0)
                return;
            const next = nextRow * cols + col;
            if (next >= count)
                return;
            root.applySelection(next);
        }
    }

    function accept() {
        if (root.pane === "search") {
            searchPane.launchSelected();
            return;
        }
        if (root.pane === "wallpaper") {
            wallpaperPane.applySelected();
            return;
        }
        if (root.pane === "power") {
            powerPane.requestSelected();
            return;
        }
        if (root.visiblePanes.length === 0)
            return;
        root.activateItem(root.visiblePanes[root.selectedIndex]);
    }

    function scoreCommand(query, cmd) {
        if (query.length === 0)
            return 1;
        const names = [cmd.name].concat(cmd.aliases);
        let best = 0;
        for (let i = 0; i < names.length; i++) {
            const name = names[i];
            if (name === query)
                best = Math.max(best, 100);
            else if (name.startsWith(query))
                best = Math.max(best, 80);
            else if (name.indexOf(query) >= 0)
                best = Math.max(best, 40);
        }
        return best;
    }

    function clampCommandMatch() {
        if (root.commandMatches.length === 0) {
            root.commandMatchIndex = 0;
            return;
        }
        if (root.commandMatchIndex < 0)
            root.commandMatchIndex = 0;
        if (root.commandMatchIndex >= root.commandMatches.length)
            root.commandMatchIndex = root.commandMatches.length - 1;
    }

    function moveCommandMatch(delta) {
        if (root.commandMatches.length === 0)
            return;
        let next = root.commandMatchIndex + delta;
        if (next < 0)
            next = 0;
        if (next >= root.commandMatches.length)
            next = root.commandMatches.length - 1;
        root.commandMatchIndex = next;
    }

    function completeCommand() {
        if (root.commandMatches.length === 0)
            return;
        root.clampCommandMatch();
        const selected = root.commandMatches[root.commandMatchIndex];
        if (root.commandText === selected.name && root.commandMatches.length > 1)
            root.moveCommandMatch(1);
        root.commandText = root.commandMatches[root.commandMatchIndex].name;
    }

    function resolveCommand(line) {
        for (let i = 0; i < root.commandList.length; i++) {
            const cmd = root.commandList[i];
            if (cmd.name === line)
                return cmd;
            for (let a = 0; a < cmd.aliases.length; a++) {
                if (cmd.aliases[a] === line)
                    return cmd;
            }
        }
        return null;
    }

    function letterOf(event) {
        if (event.text && event.text.length === 1) {
            const ch = event.text.toLowerCase();
            if (ch >= "a" && ch <= "z")
                return ch;
        }
        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
            return String.fromCharCode(97 + (event.key - Qt.Key_A));
        return "";
    }

    function isPrintable(event) {
        if (!event.text || event.text.length !== 1)
            return false;
        if (event.modifiers & Qt.ControlModifier)
            return false;
        const code = event.text.charCodeAt(0);
        return code >= 32 && code !== 127;
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            root.handleEscape();
            event.accepted = true;
            return;
        }

        if (root.mode === "filter") {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.accept();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Backspace) {
                root.filterText = root.filterText.slice(0, -1);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Down) {
                root.moveGrid(0, 1);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Up) {
                root.moveGrid(0, -1);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Left) {
                root.moveGrid(-1, 0);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Right) {
                root.moveGrid(1, 0);
                event.accepted = true;
                return;
            }
            if (root.isPrintable(event)) {
                root.filterText += event.text;
                event.accepted = true;
            }
            return;
        }

        if (root.mode === "command") {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.runCommand();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Tab) {
                if (event.modifiers & Qt.ShiftModifier)
                    root.moveCommandMatch(-1);
                else
                    root.completeCommand();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Backtab) {
                root.moveCommandMatch(-1);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Down) {
                root.moveCommandMatch(1);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Up) {
                root.moveCommandMatch(-1);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Backspace) {
                root.commandText = root.commandText.slice(0, -1);
                root.commandMatchIndex = 0;
                event.accepted = true;
                return;
            }
            if (root.isPrintable(event)) {
                root.commandText += event.text;
                root.commandMatchIndex = 0;
                event.accepted = true;
            }
            return;
        }

        if (event.key === Qt.Key_Slash) {
            root.enterFilter();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Colon || (event.key === Qt.Key_Semicolon && (event.modifiers & Qt.ShiftModifier))) {
            root.enterCommand();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.accept();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            root.moveGrid(0, 1);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            root.moveGrid(0, -1);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Left) {
            root.moveGrid(-1, 0);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Right) {
            root.moveGrid(1, 0);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_H && (root.pane === "" || root.pane === "wallpaper")) {
            root.moveGrid(-1, 0);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_L && (root.pane === "" || root.pane === "wallpaper")) {
            root.moveGrid(1, 0);
            event.accepted = true;
            return;
        }

        if (root.pane === "power") {
            if (powerPane.handleKey(event)) {
                event.accepted = true;
                return;
            }
        }

        if (root.pane !== "")
            return;

        const letter = root.letterOf(event);
        if (letter.length === 0)
            return;
        for (let i = 0; i < root.visiblePanes.length; i++) {
            if (root.visiblePanes[i].key === letter) {
                root.activateItem(root.visiblePanes[i]);
                event.accepted = true;
                return;
            }
        }
    }

    function runCommand() {
        const line = root.commandText.trim();
        if (line.length === 0) {
            root.backToNormal();
            return;
        }

        let cmd = root.resolveCommand(line);
        if (!cmd && root.commandMatches.length > 0) {
            root.clampCommandMatch();
            cmd = root.commandMatches[root.commandMatchIndex];
        }

        if (cmd) {
            root.dispatchCommand(cmd.name);
            return;
        }

        if (searchPane.launchByQuery(line)) {
            root.close();
            return;
        }

        root.commandMessage = "Not a command: " + line;
        root.mode = "normal";
        Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
    }

    function dispatchCommand(name) {
        if (name === "help") {
            root.commandText = "";
            root.commandMatchIndex = 0;
            return;
        }
        if (name === "firefox") {
            root.spawnAndClose(["firefox"]);
            return;
        }
        if (name === "terminal") {
            root.spawnAndClose(["ghostty", "+new-window"]);
            return;
        }
        if (name === "quit") {
            root.close();
            return;
        }
        if (name === "search") {
            root.enterPane("search");
            return;
        }
        if (name === "wallpaper") {
            root.enterPane("wallpaper");
            return;
        }
        if (name === "settings") {
            root.enterPane("settings");
            return;
        }
        if (name === "power") {
            root.enterPane("power");
            return;
        }
        if (name === "lock") {
            powerPane.run("lock");
            root.close();
            return;
        }
        if (name === "suspend") {
            powerPane.run("suspend");
            root.close();
            return;
        }
        if (name === "logout") {
            powerPane.run("logout");
            root.close();
            return;
        }
        if (name === "reboot") {
            powerPane.run("reboot");
            root.close();
            return;
        }
        if (name === "shutdown") {
            powerPane.run("shutdown");
            root.close();
            return;
        }
    }

    onFilterTextChanged: {
        if (root.pane === "search")
            searchPane.filterText = root.filterText;
        else if (root.pane === "wallpaper")
            wallpaperPane.filterText = root.filterText;
        root.selectedIndex = 0;
        root.clampSelection();
    }

    onSelectedIndexChanged: root.clampSelection()
    onVisiblePanesChanged: root.clampSelection()
    onCommandMatchesChanged: root.clampCommandMatch()

    Process {
        id: spawnProc
        command: ["true"]
    }

    PanelWindow {
        id: overlay
        visible: root.showing
        implicitWidth: Root.Theme.cardWidth
        implicitHeight: bodyColumn.implicitHeight
        anchors { top: true; left: true }
        margins {
            left: overlay.screen ? Math.max(0, Math.round((overlay.screen.width - overlay.implicitWidth) / 2)) : 0
            top: overlay.screen ? Math.max(0, Math.round((overlay.screen.height - overlay.implicitHeight) / 2)) : 0
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        WlrLayershell.namespace: "quickshell-v2"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            id: card
            anchors.fill: parent
            radius: Root.Theme.radius
            color: Root.Theme.glass
            border.width: 1
            border.color: Root.Theme.border
            clip: true

            FocusScope {
                id: keyCatcher
                anchors.fill: parent
                focus: root.showing
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) {
                    root.handleKey(event);
                }

                Timer {
                    interval: 530
                    running: root.showing && root.mode !== "normal"
                    repeat: true
                    onTriggered: root.cursorOn = !root.cursorOn
                    onRunningChanged: root.cursorOn = true
                }

            Column {
                id: bodyColumn
                width: parent.width

                RowLayout {
                    width: parent.width
                    height: 52

                    Text {
                        text: root.mode === "command" ? "COMMAND" : (root.pane === "" ? "MAP" : root.pane.toUpperCase())
                        color: Root.Theme.textMute
                        font { family: Root.Theme.fontMono; pixelSize: 11; letterSpacing: 1.4 }
                        Layout.leftMargin: Root.Theme.cardPad
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.mode === "command" ? "tab complete   ↑↓   esc" : "esc back   / filter   : command"
                        color: Root.Theme.textMute
                        font { family: Root.Theme.fontMono; pixelSize: 11 }
                        Layout.rightMargin: Root.Theme.cardPad
                    }
                }

                Item {
                    id: body
                    width: parent.width
                    implicitHeight: {
                        if (root.mode === "command") return commandMatchList.implicitHeight;
                        if (root.pane === "search") return searchPane.implicitHeight;
                        if (root.pane === "wallpaper") return wallpaperPane.implicitHeight;
                        if (root.pane === "settings") return settingsPane.implicitHeight;
                        if (root.pane === "power") return powerPane.implicitHeight;
                        if (root.visiblePanes.length === 0) return 88;
                        return mapList.implicitHeight;
                    }
                    clip: true

                    Column {
                        id: mapList
                        visible: root.mode !== "command" && root.pane === ""
                        width: parent.width
                        topPadding: 4
                        bottomPadding: 8

                        Repeater {
                            model: root.visiblePanes

                            Rectangle {
                                required property var modelData
                                required property int index
                                width: mapList.width
                                height: Root.Theme.tileMinHeight
                                color: index === root.selectedIndex ? Root.Theme.tileActive : "transparent"

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.selectedIndex = index
                                    onClicked: root.activateItem(modelData)
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Root.Theme.cardPad
                                    anchors.rightMargin: Root.Theme.cardPad
                                    spacing: 16

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 28
                                        text: modelData.key
                                        color: modelData.color
                                        font { family: Root.Theme.fontMono; pixelSize: 16; weight: Font.DemiBold }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 140
                                        text: modelData.label
                                        color: index === root.selectedIndex ? Root.Theme.text : Root.Theme.text
                                        font { family: Root.Theme.fontUi; pixelSize: 14; weight: index === root.selectedIndex ? Font.DemiBold : Font.Normal }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.hint
                                        color: Root.Theme.textMute
                                        font { family: Root.Theme.fontMono; pixelSize: 12 }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.mode !== "command" && root.pane === "" && root.visiblePanes.length === 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 24
                        bottomPadding: 32
                        text: "No maps match"
                        color: Root.Theme.textDim
                        font { family: Root.Theme.fontUi; pixelSize: 14 }
                    }

                    Column {
                        id: commandMatchList
                        visible: root.mode === "command"
                        width: parent.width
                        topPadding: 4
                        bottomPadding: 12
                        spacing: 0

                        Text {
                            visible: root.commandMatches.length === 0
                            width: parent.width
                            height: 56
                            text: "No matching commands"
                            color: Root.Theme.textDim
                            font { family: Root.Theme.fontUi; pixelSize: 14 }
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        Repeater {
                            model: root.commandMatches

                            Rectangle {
                                required property var modelData
                                required property int index
                                width: commandMatchList.width
                                height: 40
                                color: index === root.commandMatchIndex ? Root.Theme.tileActive : "transparent"

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.commandMatchIndex = index
                                    onClicked: {
                                        root.commandMatchIndex = index;
                                        root.commandText = modelData.name;
                                        root.dispatchCommand(modelData.name);
                                    }
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Root.Theme.cardPad
                                    anchors.rightMargin: Root.Theme.cardPad
                                    spacing: 16

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 120
                                        text: modelData.name
                                        color: index === root.commandMatchIndex ? Root.Theme.warning : Root.Theme.text
                                        font { family: Root.Theme.fontMono; pixelSize: 14; weight: index === root.commandMatchIndex ? Font.DemiBold : Font.Normal }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 88
                                        text: modelData.aliases.length > 0 ? modelData.aliases.join(" ") : ""
                                        color: Root.Theme.textMute
                                        font { family: Root.Theme.fontMono; pixelSize: 12 }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.summary
                                        color: Root.Theme.textDim
                                        font { family: Root.Theme.fontUi; pixelSize: 13 }
                                    }
                                }
                            }
                        }
                    }

                    Panes.Search {
                        id: searchPane
                        visible: root.mode !== "command" && root.pane === "search"
                        width: parent.width
                        selectedIndex: root.selectedIndex
                        onLaunched: root.close()
                        onSelectedIndexChanged: root.selectedIndex = selectedIndex
                    }

                    Panes.Wallpaper {
                        id: wallpaperPane
                        visible: root.mode !== "command" && root.pane === "wallpaper"
                        width: parent.width
                        selectedIndex: root.selectedIndex
                        onApplied: root.close()
                        onSelectedIndexChanged: root.selectedIndex = selectedIndex
                    }

                    Panes.Settings {
                        id: settingsPane
                        visible: root.mode !== "command" && root.pane === "settings"
                        width: parent.width
                    }

                    Panes.Power {
                        id: powerPane
                        visible: root.mode !== "command" && root.pane === "power"
                        width: parent.width
                        selectedIndex: root.selectedIndex
                        onSelectedIndexChanged: root.selectedIndex = selectedIndex
                        onRan: root.close()
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Root.Theme.border
                }

                Rectangle {
                    width: parent.width
                    height: Root.Theme.footerHeight
                    color: {
                        if (root.mode === "command")
                            return Qt.rgba(Root.Theme.warning.r, Root.Theme.warning.g, Root.Theme.warning.b, 0.18);
                        if (root.mode === "filter")
                            return Qt.rgba(Root.Theme.accent.r, Root.Theme.accent.g, Root.Theme.accent.b, 0.14);
                        return "transparent";
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Root.Theme.cardPad
                        anchors.rightMargin: Root.Theme.cardPad
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.mode === "normal"
                            text: "NORMAL"
                            color: Root.Theme.textMute
                            font { family: Root.Theme.fontMono; pixelSize: 11; letterSpacing: 1.2 }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.mode === "filter"
                            text: "/"
                            color: Root.Theme.accent
                            font { family: Root.Theme.fontMono; pixelSize: 18; weight: Font.DemiBold }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.mode === "command"
                            text: ":"
                            color: Root.Theme.warning
                            font { family: Root.Theme.fontMono; pixelSize: 18; weight: Font.DemiBold }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.mode === "filter"
                            text: root.filterText
                            color: Root.Theme.text
                            font { family: Root.Theme.fontMono; pixelSize: 16 }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.mode === "command"
                            text: root.commandText
                            color: Root.Theme.text
                            font { family: Root.Theme.fontMono; pixelSize: 16 }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.mode !== "normal" && root.cursorOn
                            width: 8
                            height: 18
                            color: root.mode === "command" ? Root.Theme.warning : Root.Theme.accent
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.mode === "normal"
                            text: root.commandMessage.length > 0 ? root.commandMessage : (root.pane === "" ? "b t s w c p" : "j k   esc")
                            color: root.commandMessage.length > 0 ? Root.Theme.danger : Root.Theme.textMute
                            font { family: Root.Theme.fontMono; pixelSize: 12 }
                        }
                    }
                }
            }
            }
        }
    }
}
