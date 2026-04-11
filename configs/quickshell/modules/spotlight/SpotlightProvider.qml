import QtQuick

// Base type for Spotlight providers. Each provider backs one "tab" in the
// Spotlight popup (launcher, clipboard, wallpaper, etc.) and exposes a
// uniform API so Spotlight.qml can dispatch search text, keyboard
// navigation, and accept/cancel without per-view if/else chains.
//
// Concrete providers inherit this and override the functions below.
// The visual content is the provider's child items — Spotlight loads
// the provider component directly into the view area.
Item {
    id: provider

    // ── Identity ──
    property string providerKey: ""      // e.g. "launcher", "clipboard"
    property string providerLabel: ""    // e.g. "Apps", "Clipboard"
    property string providerIcon: ""     // Nerd Font glyph for the tab

    // ── Capabilities ──
    // Whether this provider's content is filterable via the search bar.
    property bool hasSearch: true

    // Whether this provider uses a grid layout (for Left/Right nav).
    property bool hasGrid: false

    // Preferred popup dimensions. Spotlight reads these from the
    // active provider to set the box size — no more per-view if/else.
    property int preferredWidth: 420
    property int preferredMaxHeight: 500

    // Max height budget for view content (set by Spotlight). Views
    // should bind their flickable heights to this minus any internal
    // chrome (headers, toggles, etc.) rather than hardcoding values.
    property int maxContentHeight: 400

    // How many results are currently visible (for footer / tab badge).
    property int resultCount: 0

    // Total items before filtering (for "N of M" display).
    property int totalCount: 0

    // ── Lifecycle ──
    // Called when the provider becomes the active tab.
    function activate() {}

    // Called when leaving this provider (switching tabs or closing).
    function deactivate() {}

    // ── Search ──
    // Called on every keystroke when this provider is active.
    function handleSearchText(text) {}

    // ── Keyboard navigation ──
    function moveUp() {}
    function moveDown() {}
    function moveLeft() {}
    function moveRight() {}

    // ── Accept (Enter key / primary action) ──
    function accept() {}

    // ── Delete (Shift+Delete — remove selected item) ──
    function deleteSelected() {}
}
