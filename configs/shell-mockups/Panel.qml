import QtQuick

// One page inside the ring: a Box holding an optional line of text input
// and a list of rows. The list shows at most ten rows and scrolls to keep
// the selected one near its middle; a heavy stretch of the right border
// shows where the visible part sits in the whole list.
//
// The kinds of row are described in sample-data.js.
Box {
    id: panel

    // The page being shown: { title, field, rows }.
    property var page: null
    // Its rows, after any filtering by the text field.
    property var entries: []
    property int selectedIndex: 0
    // What has been typed into the text field.
    property string query: ""

    // Layout, in cells.
    readonly property int valueColumn: 18
    readonly property int levelCells: 20
    readonly property int maxListRows: 10

    readonly property bool hasField: page !== null && page.field !== undefined
    readonly property int fieldRows: hasField ? 1 : 0
    // An empty list still takes one row, for "nothing matches".
    readonly property int listRows: Math.max(1, Math.min(entries.length, maxListRows))
    readonly property bool scrolls: entries.length > maxListRows
    // The first entry on screen.
    readonly property int firstEntry: Math.max(0, Math.min(entries.length - listRows, selectedIndex - Math.floor(listRows / 2)))

    // The heavy stretch of the border: how many rows long, and where it starts.
    readonly property int thumbRows: scrolls ? Math.max(1, Math.round(listRows * listRows / entries.length)) : 0
    readonly property int thumbStart: scrolls ? Math.round(firstEntry / (entries.length - listRows) * (listRows - thumbRows)) : 0

    function thumbText(): string {
        const lines = [];
        for (let row = 0; row < panel.listRows; row++) {
            const inThumb = row >= panel.thumbStart && row < panel.thumbStart + panel.thumbRows;
            lines.push(inThumb ? "┃" : " ");
        }
        return lines.join("\n");
    }

    function footerText(): string {
        const keys = panel.hasField ? "↑↓ select  ↵ act  esc back" : "↑↓ jk select  ↵ act  esc back";
        if (!panel.scrolls)
            return keys;
        return keys + "  " + (panel.selectedIndex + 1) + "/" + panel.entries.length;
    }

    columns: 52
    rows: fieldRows + listRows
    title: page ? page.title : ""
    footer: footerText()

    // The newly selected row flashes bright for a moment.
    onSelectedIndexChanged: selectFlash.restart()

    Timer {
        id: selectFlash

        interval: Theme.flashMs
    }

    // --- The text field: a prompt, what was typed, a block cursor ---
    Row {
        visible: panel.hasField

        Label {
            text: "› "
            color: Theme.accent
        }

        Label {
            // A secret is shown as one dot per character.
            text: panel.hasField && panel.page.field.secret ? "•".repeat(panel.query.length) : panel.query
            color: Theme.ink
        }

        Label {
            text: "█"
            color: Theme.accent
        }

        Label {
            visible: panel.query === ""
            text: panel.hasField ? " " + panel.page.field.hint : ""
            color: Theme.line
        }
    }

    // --- The list ---
    Repeater {
        model: panel.listRows

        // One line of the list, showing whichever entry has scrolled into it.
        Item {
            id: line

            required property int index

            readonly property int entryIndex: panel.firstEntry + index
            readonly property var entry: entryIndex < panel.entries.length ? panel.entries[entryIndex] : null
            readonly property string kind: entry ? entry.kind : ""
            readonly property bool selected: entry !== null && entryIndex === panel.selectedIndex
            readonly property bool alert: entry !== null && entry.alert === true
            // A "line" entry is text across the whole width.
            readonly property bool wholeLine: kind === "line"
            // A level and a graph end with their value at the right edge.
            readonly property bool endsWithValue: kind === "level" || kind === "graph"
            // The short text at the right edge: "›" for a row that opens a
            // page, a level's or graph's value, or the row's note.
            readonly property string endText: {
                if (!entry)
                    return "";
                if (entry.opens)
                    return "›";
                if (endsWithValue)
                    return entry.value;
                return entry.note || "";
            }
            // The cells it takes, with one cell of space before it.
            readonly property int endCells: endText.length > 0 ? endText.length + 1 : 0
            // Where the value's text starts. A busy row has its spinner
            // first, a signal row its bars.
            readonly property int textColumn: panel.valueColumn + (kind === "busy" ? 2 : (kind === "signal" ? 5 : 0))

            y: (panel.fieldRows + index) * Theme.cellHeight
            width: panel.contentColumns * Theme.cellWidth
            height: Theme.cellHeight

            Label {
                x: 2 * Theme.cellWidth
                visible: line.entry === null
                text: "nothing matches"
                color: Theme.line
            }

            // Reverse video behind the name, or behind a whole "line" entry.
            Rectangle {
                width: line.wholeLine ? parent.width : (panel.valueColumn - 1) * Theme.cellWidth
                height: parent.height
                visible: line.selected
                color: selectFlash.running ? Theme.ink : Theme.accent
            }

            Label {
                text: line.selected ? "►" : " "
                color: Theme.slab
            }

            Label {
                x: 2 * Theme.cellWidth
                width: (line.wholeLine ? panel.contentColumns - 3 - line.endCells : panel.valueColumn - 3) * Theme.cellWidth
                text: line.entry ? line.entry.label : ""
                color: line.selected ? Theme.slab : Theme.ink
                elide: Text.ElideRight
            }

            Level {
                x: panel.valueColumn * Theme.cellWidth
                visible: line.kind === "level"
                level: line.kind === "level" ? line.entry.level : 0
                cells: panel.levelCells
                fillColor: line.alert ? Theme.alert : Theme.accent
            }

            Graph {
                x: panel.valueColumn * Theme.cellWidth
                visible: line.kind === "graph"
                samples: line.kind === "graph" ? line.entry.samples : []
                cells: panel.levelCells
            }

            SignalBars {
                x: panel.valueColumn * Theme.cellWidth
                visible: line.kind === "signal"
                level: line.kind === "signal" ? line.entry.level : 0
            }

            Spinner {
                x: panel.valueColumn * Theme.cellWidth
                visible: line.kind === "busy"
            }

            // The value's text. A switch has a filled or empty square first.
            Label {
                x: line.textColumn * Theme.cellWidth
                width: (panel.contentColumns - line.textColumn - line.endCells) * Theme.cellWidth
                visible: line.entry !== null && !line.wholeLine && !line.endsWithValue
                text: {
                    if (!line.entry || line.entry.value === undefined)
                        return "";
                    if (line.kind === "switch")
                        return (line.entry.on ? "■ " : "□ ") + line.entry.value;
                    return line.entry.value;
                }
                color: line.alert ? Theme.alert : Theme.inkSoft
                elide: Text.ElideRight
            }

            Label {
                anchors.right: parent.right
                text: line.endText
                color: {
                    if (line.wholeLine && line.selected)
                        return Theme.slab;
                    if (!line.endsWithValue)
                        return Theme.inkDim;
                    return line.alert ? Theme.alert : Theme.ink;
                }
            }
        }
    }

    // --- Where the visible rows sit in the whole list ---
    // Drawn over the Box's right border, which is one cell of padding and
    // one cell of border to the right of the content.
    Label {
        x: (panel.contentColumns + 1) * Theme.cellWidth
        y: panel.fieldRows * Theme.cellHeight
        visible: panel.scrolls
        text: panel.thumbText()
        color: Theme.inkDim
    }
}
