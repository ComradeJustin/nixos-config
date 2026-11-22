import QtQuick
import Quickshell
import Quickshell.Wayland

// The tray, as a panel that drops out of the bar's "apps" tab: the apps
// that keep running without a window, and, on choosing one, that app's own
// menu in the same place. It takes the keyboard while it is open: up and
// down or j and k select, enter chooses, esc goes back from a menu and then
// closes. The mouse selects and chooses too.
//
// It shows the same two pages the ring's System station has (Pages.qml:
// tray and trayMenu). Going from one to the other wipes the panel away and
// wipes the next in.
PanelWindow {
    id: drop

    // The shell root (shell.qml).
    required property var shell

    // Which of the two pages is wanted, and which row of it is selected.
    property string pageName: "tray"
    property int selected: 0
    // The page that is drawn. It follows pageName only once the panel has
    // been wiped away, so a page never changes on screen.
    property string drawnPageName: "tray"
    readonly property var page: shell.pages.named(drawnPageName)
    readonly property var rows: page !== null ? page.rows : []

    // 0 = nothing showing, 1 = the whole panel.
    property real shown: shell.trayOpen && drawnPageName === pageName ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.wipeMs
        }
    }

    onShownChanged: {
        if (shown === 0)
            drawnPageName = pageName;
    }

    // Move the selection, passing over lines that are only there to be read.
    function move(step: int): void {
        let index = drop.selected + step;
        while (index >= 0 && index < drop.rows.length) {
            if (drop.rows[index].kind !== "note") {
                drop.selected = index;
                return;
            }
            index += step;
        }
    }

    // Enter or a click on a row: do what the row does.
    function choose(index: int): void {
        if (index < 0 || index >= drop.rows.length)
            return;
        const row = drop.rows[index];
        if (row.act)
            row.act();
        if (row.opens) {
            drop.pageName = row.opens;
            drop.selected = 0;
        }
        if (row.closes)
            drop.shell.trayOpen = false;
    }

    // Esc: back from an app's menu to the list of apps, then close.
    function back(): void {
        if (drop.pageName === "tray") {
            drop.shell.trayOpen = false;
        } else {
            drop.pageName = "tray";
            drop.selected = 0;
        }
    }

    // Stay mapped until the panel has been wiped away.
    visible: shell.trayOpen || shown > 0
    anchors {
        top: true
        left: true
    }
    // Under the bar's tab.
    margins.left: shell.trayTabX
    // Directly under the bar, or against the top of the screen when a
    // fullscreen window has covered the bar.
    margins.top: shell.fullscreen ? 0 : Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"
    WlrLayershell.namespace: "shell"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shell.trayOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Each time it opens it starts at the list of apps.
    onVisibleChanged: {
        if (visible) {
            drop.pageName = "tray";
            drop.drawnPageName = "tray";
            drop.selected = 0;
            panel.forceActiveFocus();
        }
    }

    Panel {
        id: panel

        page: drop.page
        entries: drop.rows
        selectedIndex: drop.selected
        shown: drop.shown
        focus: true
        interactive: true
        onRowEntered: entryIndex => drop.selected = entryIndex
        onRowClicked: entryIndex => drop.choose(entryIndex)
        onWheelTurned: step => drop.move(step)

        Keys.onPressed: event => {
            const key = event.key;
            event.accepted = true;
            if (key === Qt.Key_Escape || key === Qt.Key_H || key === Qt.Key_Left)
                drop.back();
            else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_L || key === Qt.Key_Right)
                drop.choose(drop.selected);
            else if (key === Qt.Key_J || key === Qt.Key_Down)
                drop.move(1);
            else if (key === Qt.Key_K || key === Qt.Key_Up)
                drop.move(-1);
        }
    }
}
