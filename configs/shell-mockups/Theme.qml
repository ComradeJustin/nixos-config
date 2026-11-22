pragma Singleton
import QtQuick
import Quickshell

// Colours, the character grid and motion shared by the whole mockup. The
// palette comes from the BASE00–BASE0F environment variables
// (modules/desktop/theme.nix).
//
// The shell is drawn like a terminal UI: one pixel font on a fixed grid of
// cells, borders made of box-drawing characters, bars made of block
// characters, and reverse video for whatever is focused or selected.
Singleton {
    readonly property color base00: Quickshell.env("BASE00") || "#241d1a"
    readonly property color base03: Quickshell.env("BASE03") || "#594740"
    readonly property color base04: Quickshell.env("BASE04") || "#a78e84"
    readonly property color base05: Quickshell.env("BASE05") || "#b8a59d"
    readonly property color base07: Quickshell.env("BASE07") || "#dcd2ce"
    readonly property color base0F: Quickshell.env("BASE0F") || "#f1ae97"

    // What each colour is for.
    readonly property color slab: base00
    readonly property color ink: base07
    readonly property color inkSoft: base05
    readonly property color inkDim: base04
    // Borders and the empty part of bars.
    readonly property color line: base03
    // Reverse-video blocks and filled bars.
    readonly property color accent: base0F

    // Departure Mono is a pixel font: it is only sharp at 11 px and whole
    // multiples of it. At 11 px every character is exactly one cell.
    // It is not installed system-wide yet, so it is loaded from the link
    // next to this file.
    readonly property string fontFamily: departureMono.status === FontLoader.Ready ? departureMono.name : "Departure Mono"
    readonly property int fontSize: 11
    readonly property int cellWidth: 7
    readonly property int cellHeight: 14

    // The bar is two cells tall, with its one row of text centred in it.
    readonly property int barHeight: 2 * cellHeight
    readonly property int barTextY: cellHeight / 2

    // Motion. There is one way for anything to appear or disappear: a
    // dithered front wipes across it from the left, and wipes back to take
    // it away. Names, the clock, hints and whole panels all do this, at the
    // same speed. Nothing fades, slides or is cut.
    readonly property int wipeMs: 140
    // Width of the dithered front, as a share of the width of what it crosses.
    readonly property real wipeFront: 0.35
    // The only movement is turning the ring: one place takes this long,
    // drawn as this many equal jumps on the character grid.
    readonly property int turnMs: 96
    readonly property int turnSteps: 6
    // A value that has just changed, or a thing that has just taken focus,
    // shows in bright reverse video for this long.
    readonly property int flashMs: 80
    // Nothing runs while idle.

    // Panels cast a halftone shadow this far to the right and below.
    readonly property int shadowOffset: cellWidth
    readonly property color shadow: Qt.darker(base00, 2)

    // Snap a distance in pixels to whole cells, so text never sits between them.
    function snapX(pixels: real): real {
        return Math.round(pixels / cellWidth) * cellWidth;
    }

    function snapY(pixels: real): real {
        return Math.round(pixels / cellHeight) * cellHeight;
    }

    FontLoader {
        id: departureMono

        source: Qt.resolvedUrl("departure-mono-font/share/fonts/otf/DepartureMono-Regular.otf")
    }
}
