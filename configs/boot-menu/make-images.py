"""Draws what the boot menu (Limine) needs to look like the desktop shell.

Limine draws its menu as plain text over a picture. It decides where the
text goes: the list of systems in the middle of its text area, a line about
the chosen one and the countdown at the bottom. So the shell's look is put
around that text, once, when the system is built:

  font.bin       the shell's pixel font in the only form Limine reads: the
                 256 characters of code page 437, each 8 dots wide and 14
                 high, a byte for each row of dots
  wallpaper.png  the whole screen: the background, the hostname, and a
                 panel as the shell draws them (rounded frame, a title and
                 the keys set into its edges, a halftone shadow) around
                 the place where Limine puts its text

Usage: make-images.py <font file> <output folder> <hostname>
           <screen width> <screen height> <margin> name=rrggbb ...
The margin is Limine's term_margin: the space it leaves around its text.
The colours needed are: background line dim ink
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT_PIXELS = 11
# A character of the menu's own text: Limine's fonts are 8 dots wide.
MENU_CELL_WIDTH = 8
# A character drawn here, in the picture: the font's own width, as in the shell.
CELL_WIDTH = 7
CELL_HEIGHT = 14
# The hostname is drawn at this many times the size, as on the boot splash.
BIG = 4
# One dither dot is this many screen pixels square, as in the shell.
DOT = 2

# The panel is this many of the picture's characters wide, borders included:
# room for the longest line Limine writes, the note about the default
# system, which is about 95 of the menu's wider characters.
PANEL_COLUMNS = 116
TITLE = " boot "
KEYS = " ↲ boot  ↑↓ select  s firmware "
# The column the title and the keys start in.
EDGE_TEXT_COLUMN = 2
# Empty rows between the hostname and the panel.
HOSTNAME_GAP_ROWS = 2

# Code page 437 gives pictures to the codes that are control characters
# elsewhere: 1 to 31, and 127. Code 0 is empty.
CP437_LOW = "☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼"
CP437_HOUSE = "⌂"
# The codes of its lines, corners and blocks. These have to reach the right
# edge of the character to join up with the next one.
CP437_JOINING = range(0xB0, 0xE0)


def colour_tuple(hex_colour):
    return (
        int(hex_colour[0:2], 16),
        int(hex_colour[2:4], 16),
        int(hex_colour[4:6], 16),
    )


def cp437_character(code):
    if code == 0:
        return " "
    if code < 32:
        return CP437_LOW[code - 1]
    if code == 127:
        return CP437_HOUSE
    return bytes([code]).decode("cp437")


def character_dots(font, baseline, character):
    """One character as a 1-bit picture the size of the menu's cell."""
    picture = Image.new("1", (MENU_CELL_WIDTH, CELL_HEIGHT), 0)
    draw = ImageDraw.Draw(picture)
    # No smoothing: each pixel of the font is on or off.
    draw.fontmode = "1"
    draw.text((0, baseline), character, font=font, fill=1, anchor="ls")
    return picture


def menu_font(font, baseline):
    """The 256 characters of code page 437, a byte for each row of dots."""
    # What the font draws for a character it does not have.
    missing = character_dots(font, baseline, "\U0010ffff")
    rows = bytearray()
    for code in range(256):
        dots = character_dots(font, baseline, cp437_character(code))
        if dots.tobytes() == missing.tobytes():
            dots = Image.new("1", (MENU_CELL_WIDTH, CELL_HEIGHT), 0)
        if code in CP437_JOINING:
            # The font's character is 7 dots wide: repeat its last column
            # in the eighth, so that lines meet the next character.
            for y in range(CELL_HEIGHT):
                dots.putpixel((MENU_CELL_WIDTH - 1, y), dots.getpixel((CELL_WIDTH - 1, y)))
        rows += dots.tobytes()
    return bytes(rows)


def put_text(draw, font, baseline, x, y, text, colour):
    """Text on the picture, a character to each cell, from the cell at x, y."""
    for index, character in enumerate(text):
        draw.text(
            (x + index * CELL_WIDTH, y + baseline),
            character,
            font=font,
            fill=colour,
            anchor="ls",
        )


def wallpaper(font, baseline, hostname, width, height, margin, colours):
    background = colour_tuple(colours["background"])
    line = colour_tuple(colours["line"])
    picture = Image.new("RGB", (width, height), background)
    draw = ImageDraw.Draw(picture)
    draw.fontmode = "1"

    # Where Limine puts its rows of text: as many as fit between the
    # margins, centred in what is left over.
    text_rows = (height - margin * 2) // CELL_HEIGHT
    text_y = margin + ((height - margin * 2) % CELL_HEIGHT) // 2

    # The panel: its top edge is in the text's first row, which Limine
    # leaves empty, and its bottom edge in the row under the text's last.
    panel_rows = text_rows + 1
    panel_width = PANEL_COLUMNS * CELL_WIDTH
    panel_height = panel_rows * CELL_HEIGHT
    panel_x = (width - panel_width) // 2
    panel_y = text_y

    # The shadow: the panel's shape again, one character's width to the
    # right and below, every other dot, in the background at half its
    # brightness.
    shadow = (background[0] // 2, background[1] // 2, background[2] // 2)
    for y in range(panel_y + CELL_WIDTH, panel_y + CELL_WIDTH + panel_height):
        for x in range(panel_x + CELL_WIDTH, panel_x + CELL_WIDTH + panel_width):
            if (x // DOT + y // DOT) % 2 == 0:
                picture.putpixel((x, y), shadow)
    draw.rectangle(
        (panel_x, panel_y, panel_x + panel_width - 1, panel_y + panel_height - 1),
        fill=background,
    )

    # The frame, in the font's own line characters.
    bottom_y = panel_y + (panel_rows - 1) * CELL_HEIGHT
    put_text(
        draw,
        font,
        baseline,
        panel_x,
        panel_y,
        "╭" + "─" * (PANEL_COLUMNS - 2) + "╮",
        line,
    )
    put_text(
        draw,
        font,
        baseline,
        panel_x,
        bottom_y,
        "╰" + "─" * (PANEL_COLUMNS - 2) + "╯",
        line,
    )
    for row in range(1, panel_rows - 1):
        row_y = panel_y + row * CELL_HEIGHT
        put_text(draw, font, baseline, panel_x, row_y, "│", line)
        put_text(
            draw,
            font,
            baseline,
            panel_x + (PANEL_COLUMNS - 1) * CELL_WIDTH,
            row_y,
            "│",
            line,
        )

    # The title and the keys, set into the edges over the line.
    edge_text_x = panel_x + EDGE_TEXT_COLUMN * CELL_WIDTH
    for y, text, colour in [
        (panel_y, TITLE, colours["ink"]),
        (bottom_y, KEYS, colours["dim"]),
    ]:
        draw.rectangle(
            (
                edge_text_x,
                y,
                edge_text_x + len(text) * CELL_WIDTH - 1,
                y + CELL_HEIGHT - 1,
            ),
            fill=background,
        )
        put_text(draw, font, baseline, edge_text_x, y, text, colour_tuple(colour))

    # The hostname, large, centred over the panel.
    small = Image.new("1", (len(hostname) * CELL_WIDTH, CELL_HEIGHT), 0)
    small_draw = ImageDraw.Draw(small)
    small_draw.fontmode = "1"
    put_text(small_draw, font, baseline, 0, 0, hostname, 1)
    big = small.resize((small.width * BIG, small.height * BIG), Image.NEAREST)
    hostname_y = panel_y - HOSTNAME_GAP_ROWS * CELL_HEIGHT - big.height
    picture.paste(colour_tuple(colours["ink"]), ((width - big.width) // 2, hostname_y), mask=big)
    return picture


def main():
    font_file = sys.argv[1]
    output = Path(sys.argv[2])
    hostname = sys.argv[3]
    width = int(sys.argv[4])
    height = int(sys.argv[5])
    margin = int(sys.argv[6])
    colours = dict(argument.split("=") for argument in sys.argv[7:])
    output.mkdir(parents=True, exist_ok=True)

    font = ImageFont.truetype(font_file, FONT_PIXELS)
    ascent, descent = font.getmetrics()
    # The line of text sits in the middle of the cell's height.
    baseline = (CELL_HEIGHT - (ascent + descent)) // 2 + ascent

    (output / "font.bin").write_bytes(menu_font(font, baseline))
    wallpaper(font, baseline, hostname, width, height, margin, colours).save(output / "wallpaper.png")


main()
