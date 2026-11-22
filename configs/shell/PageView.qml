import QtQuick

// The shell's open page, drawn as a Panel: the innermost of the open pages
// with its rows, selection, text field and search (shell.qml holds all of
// those). The ring shows one (Ring.qml), and so does the panel that drops
// out of the bar (Drop.qml). The mouse selects the row it is over, a click
// acts on it, and the wheel moves the selection.
Panel {
    id: view

    // The shell root (shell.qml).
    required property var shell

    page: shell.page
    entries: shell.pageRows
    selectedIndex: shell.selectedIndex
    query: shell.query
    cursor: shell.cursor
    searchable: true
    searching: shell.searching
    // A page can ask for a wider panel, and for more room for its labels.
    columns: shell.page !== null && shell.page.columns !== undefined ? shell.page.columns : 52
    valueColumn: shell.page !== null && shell.page.valueColumn !== undefined ? shell.page.valueColumn : 18
    interactive: true
    onRowEntered: entryIndex => {
        if (!view.shell.stackPending)
            view.shell.select(entryIndex);
    }
    onRowClicked: entryIndex => {
        if (view.shell.stackPending)
            return;
        view.shell.select(entryIndex);
        view.shell.act();
    }
    onWheelTurned: step => view.shell.moveSelection(step)
}
