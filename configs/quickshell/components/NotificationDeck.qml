import QtQuick
import ".." as Root

// A "deck" of an app's most-recent OSD notifications (newest on top). Depending
// on `style` it shows them collapsed (the front card + a peek of the next), all
// expanded, or it expands on hover. This only handles LAYOUT — the host toast
// still owns dismiss / countdown / hover-pause. The front card carries the group
// count badge (NotificationCard shows it when isHeader && count > 1).
//
//   style: "hover"  — compact peek at rest, fans to full cards on hover (default)
//          "stack"  — always show the recent cards stacked
//          "peek"   — compact peek + count, never expands
//          "single" — just the front card + count (the original behaviour)
Item {
    id: deck

    property string appName: ""
    property int count: 1
    property string recentJson: "[]"
    property string style: "hover"
    property bool hovered: false

    readonly property int maxCards: 3
    readonly property int gap: 8
    // Inset the compact sub-cards so their content LEFT-ALIGNS with the front
    // card's content: the front uses notifPadding, compact cards a 10px margin.
    readonly property int subInset: Math.max(0, Root.Theme.notifPadding - 10)

    readonly property var items: {
        try { var a = JSON.parse(recentJson); return Array.isArray(a) ? a : []; }
        catch (e) { return []; }
    }
    readonly property int shownCount: Math.min(items.length, maxCards)
    readonly property bool _multi: shownCount > 1
    readonly property bool _expanded: style === "stack" || (style === "hover" && hovered)

    implicitWidth: parent ? parent.width : Root.Theme.notifWidth

    // Collapsed shows ONLY the front (latest) card — the count badge signals the
    // rest, which fan out on expand. No peek sliver (it read as a clipped card
    // sitting under the countdown bar).
    readonly property int _collapsedH: frontCard.implicitHeight
    // A small bottom lane only in the expanded state: the compact sub-cards have
    // little bottom padding, so without this the bar (at the toast bottom) crowds
    // the last sub-card. The front card's own padding already clears it collapsed.
    readonly property int barLane: 8
    implicitHeight: _expanded ? (deckCol.implicitHeight + barLane) : _collapsedH

    // Clip so the collapsed state only reveals the front card + a peek of the
    // next; the height animation then fans the rest in/out on expand.
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    Column {
        id: deckCol
        width: deck.width
        spacing: deck.gap

        NotificationCard {
            id: frontCard
            width: deckCol.width
            isHeader: true
            appName: deck.appName
            summary: deck.items.length > 0 ? deck.items[0].summary : ""
            body: deck.items.length > 0 ? deck.items[0].body : ""
            imagePath: deck.items.length > 0 ? deck.items[0].imagePath : ""
            count: deck.count
            compact: false
        }

        Repeater {
            model: Math.max(0, deck.shownCount - 1)
            Item {
                id: subSlot
                required property int index
                readonly property var it: deck.items[index + 1]
                width: deckCol.width
                implicitHeight: subCard.implicitHeight
                // Collapsed: tuck a touch smaller for a deck peek (hidden by the
                // clip). Expanded: full size, so spacing stays even (no scale gap).
                transformOrigin: Item.Top
                scale: deck._expanded ? 1 : Math.max(0.85, 0.95 - index * 0.05)
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                // Sub-items use the CC's smaller `compact` size and are inset from
                // the edges so they read as nested under the latest, with breathing
                // room rather than sitting flush to the toast border.
                NotificationCard {
                    id: subCard
                    anchors { left: parent.left; right: parent.right
                              leftMargin: deck.subInset; rightMargin: deck.subInset }
                    isHeader: false
                    compact: true
                    appName: deck.appName
                    summary: subSlot.it ? subSlot.it.summary : ""
                    body: subSlot.it ? subSlot.it.body : ""
                    imagePath: subSlot.it ? subSlot.it.imagePath : ""
                }
            }
        }
    }
}
