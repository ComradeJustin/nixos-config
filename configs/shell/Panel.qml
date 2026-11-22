import QtQuick

// One page: a Box holding an optional line of text input and a list of
// rows. The list shows at most ten rows and scrolls to keep
// the selected one near its middle; a heavy stretch of the right border
// shows where the visible part sits in the whole list.
//
// The kinds of row are described in Pages.qml.
Box {
    id: panel

    // The page being shown: { title, field, rows }.
    property var page: null
    // Its rows, after any filtering by the text field.
    property var entries: []
    property int selectedIndex: 0
    // Whether the mouse can be used on the rows. A panel that is only
    // looked at, such as a tile, leaves this off.
    property bool interactive: false
    // The mouse moved over a row, clicked one, or the wheel turned.
    signal rowEntered(int entryIndex)
    signal rowClicked(int entryIndex)
    signal wheelTurned(int step)

    // Whether "/" brings up a search field here, and whether one is
    // showing now on a page that has no text field of its own. Typing into
    // it narrows the rows.
    property bool searchable: false
    property bool searching: false
    // What has been typed into the text field, and where the cursor is in
    // it, counted in characters from the start.
    property string query: ""
    property int cursor: 0

    // Layout, in cells: where values start, how long a level or graph is,
    // and how many rows show before the list scrolls. Set `columns` to match.
    property int valueColumn: 18
    property int levelCells: 20
    property int maxListRows: 10
    // What the footer says esc does: "back", or "close" where there is
    // nothing to go back to.
    property string backWord: "back"

    readonly property bool ownField: page !== null && page.field !== undefined
    readonly property bool hasField: ownField || searching
    readonly property bool secret: ownField && page.field.secret
    readonly property string hint: ownField ? page.field.hint : "search"
    readonly property int fieldRows: hasField ? 1 : 0
    // Whether the page is only its text field, which enter hands over.
    readonly property bool submits: ownField && page.field.submit !== undefined
    // An empty list still takes one row, to say that it is empty. A page
    // that is only a text field has no list at all.
    readonly property int listRows: submits ? 0 : Math.max(1, Math.min(entries.length, maxListRows))
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

    // Several levels side by side, such as the processor's cores: one
    // block for each, taller the fuller it is. They stand a cell apart
    // while there is room for that.
    function barsText(levels: var): string {
        const blocks = "▁▂▃▄▅▆▇█";
        const blocksShown = [];
        for (const level of levels)
            blocksShown.push(blocks.charAt(Math.round(Math.max(0, Math.min(1, level)) * 7)));
        return blocksShown.join(levels.length * 2 <= panel.levelCells ? " " : "");
    }

    // The selected entry, or null when nothing is selected.
    readonly property var selectedEntry: selectedIndex >= 0 && selectedIndex < entries.length ? entries[selectedIndex] : null

    // What enter or left and right would do to the selected row, or "".
    function actionHint(): string {
        const entry = panel.selectedEntry;
        if (entry === null)
            return "";
        if (entry.opens)
            return "↵ open";
        if (entry.kind === "switch")
            return "↵ switch";
        if (entry.adjust)
            return "←→ adjust";
        if (entry.act)
            return "↵ go";
        return "";
    }

    // The keys that do something here, and no others.
    function footerText(): string {
        if (panel.submits)
            return "↵ " + panel.page.field.submitHint + "  esc " + panel.backWord;
        if (panel.entries.length === 0)
            return "esc " + panel.backWord;
        let keys = "↑↓ select";
        if (panel.searchable && !panel.hasField)
            keys += "  / search";
        const action = panel.actionHint();
        if (action !== "")
            keys += "  " + action;
        keys += "  esc " + panel.backWord;
        // Where the selection is in a long list, if there is room left.
        // The border needs five cells beside the footer (Box.qml).
        const place = "  " + (panel.selectedIndex + 1) + "/" + panel.entries.length;
        if (panel.scrolls && keys.length + place.length <= panel.columns - 5)
            keys += place;
        return keys;
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

    // --- The text field: a prompt and what was typed, with a block cursor ---
    Row {
        id: field

        // What is shown for the typed text: a secret is one dot per character.
        readonly property string typed: panel.secret ? "•".repeat(panel.query.length) : panel.query

        visible: panel.hasField

        Label {
            text: "› "
            color: Theme.accent
        }

        Label {
            text: field.typed.slice(0, panel.cursor)
            color: Theme.ink
        }

        // The cursor: the character it is on in reverse video, or a blank
        // block at the end of the text.
        Rectangle {
            width: Theme.cellWidth
            height: Theme.cellHeight
            color: Theme.accent

            Label {
                text: field.typed.charAt(panel.cursor)
                color: Theme.slab
            }
        }

        Label {
            text: field.typed.slice(panel.cursor + 1)
            color: Theme.ink
        }

        Label {
            visible: panel.query === ""
            text: " " + panel.hint
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
            // A "line" entry is text across the whole width, and so is a
            // "note", which is only there to be read.
            readonly property bool wholeLine: kind === "line" || kind === "note"
            // A level and a graph end with their value at the right edge.
            readonly property bool endsWithValue: kind === "level" || kind === "graph" || kind === "bars"
            // The short text at the right edge: "›" for a row that opens a
            // page (after its note, if it has one), a level's or graph's
            // value, or the row's note.
            readonly property string endText: {
                if (!entry)
                    return "";
                if (entry.opens)
                    return entry.note ? entry.note + " ›" : "›";
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
                text: panel.page && panel.page.empty ? panel.page.empty : "nothing here"
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
                color: {
                    if (line.selected)
                        return Theme.slab;
                    if (line.kind !== "note")
                        return Theme.ink;
                    return line.alert ? Theme.alert : Theme.inkSoft;
                }
                elide: Text.ElideRight
            }

            // The mouse: moving over a row selects it, a click acts on it.
            // Only movement counts, so a pointer that happens to be resting
            // where the page opens does not take the selection.
            MouseArea {
                anchors.fill: parent
                enabled: panel.interactive && line.entry !== null && line.kind !== "note"
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: panel.rowEntered(line.entryIndex)
                onClicked: panel.rowClicked(line.entryIndex)
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
                // One row of a taller graph draws only its band of the scale.
                low: line.kind === "graph" && line.entry.low !== undefined ? line.entry.low : 0
                high: line.kind === "graph" && line.entry.high !== undefined ? line.entry.high : 1
            }

            Label {
                x: panel.valueColumn * Theme.cellWidth
                visible: line.kind === "bars"
                text: line.kind === "bars" ? panel.barsText(line.entry.levels) : ""
                color: Theme.accent
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

            // The value's text. A switch is a filled square and "on", or
            // an empty one and "off".
            Label {
                x: line.textColumn * Theme.cellWidth
                width: (panel.contentColumns - line.textColumn - line.endCells) * Theme.cellWidth
                visible: line.entry !== null && !line.wholeLine && !line.endsWithValue
                text: {
                    if (!line.entry)
                        return "";
                    if (line.kind === "switch")
                        return line.entry.on ? "■ on" : "□ off";
                    return line.entry.value !== undefined ? line.entry.value : "";
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

    // The wheel anywhere on the panel.
    WheelHandler {
        enabled: panel.interactive
        onWheel: event => panel.wheelTurned(event.angleDelta.y > 0 ? -1 : 1)
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
