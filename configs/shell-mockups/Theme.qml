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

    // Motion, the way a terminal redraws. There is one way for anything to
    // appear or disappear: it is typed in from the left a character at a
    // time behind a dithered leading edge, and erased in reverse. Names, the
    // clock, hints and whole panels all do this, at the same speed. Nothing
    // fades, slides or is cut.
    readonly property int typeMs: 140
    // The leading edge: each character arrives as a light shade, darkens,
    // then becomes itself. The last one here is the very front.
    readonly property string typeEdge: "▓▒░"
    // The only movement is turning the ring: one place takes this long,
    // drawn as this many equal jumps on the character grid.
    readonly property int turnMs: 96
    readonly property int turnSteps: 6
    // Nothing runs while idle.

    // How far the typing has got through something `length` characters long,
    // in characters. It counts on past the end by the width of the edge, so
    // the edge leaves completely.
    function typedReach(length: int, fraction: real): int {
        return Math.round(Math.max(0, Math.min(1, fraction)) * (length + typeEdge.length));
    }

    // `full` as it looks when `fraction` of it has been typed in: the typed
    // characters, then the dithered edge, then spaces. Always as long as
    // `full`, so nothing beside it moves while it is typed.
    function typedText(full: string, fraction: real): string {
        const edgeLength = typeEdge.length;
        const reached = typedReach(full.length, fraction);
        let result = "";
        for (let index = 0; index < full.length; index++) {
            const behindFront = reached - 1 - index;
            if (behindFront < 0)
                result += " ";
            else if (behindFront < edgeLength)
                result += typeEdge[edgeLength - 1 - behindFront];
            else
                result += full[index];
        }
        return result;
    }

    // How many characters of a text that long are occupied, edge included.
    function typedLength(length: int, fraction: real): int {
        return Math.min(length, typedReach(length, fraction));
    }

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
