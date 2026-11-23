"""Draws the pictures the boot splash is made of (splash.script puts them on screen).

Plymouth cannot render the shell's pixel font crisply or tint a picture, so
everything is drawn here, once, when the system is built:

  glyphs-<colour>.png  every character the splash uses, side by side, each in
                       one 7 x 14 cell, once for each colour it is shown in
  glyphs-big.png       the same at four times the size, for the hostname
  field-NN.png         a 16 x 16 tile of the dither pattern, from empty (00)
                       to half full (32); tiled over the screen, it is the
                       progress
  curtain.png          a strip that goes from clear to solid through the
                       dither pattern: the front of the wipe that ends the
                       splash
  solid.png            the background colour, for the panel and the curtain
  shadow.png           the panel's halftone shadow, as a tile
  glyphs.script        where each character is in the glyph pictures, for
                       the script

Usage: make-images.py <font file> <output folder> name=rrggbb ...
The colours needed are: background field line dim soft ink accent alert
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CELL_WIDTH = 7
CELL_HEIGHT = 14
FONT_PIXELS = 11
BIG = 4

# One dither dot is this many screen pixels square, as in the shell.
DOT = 2
# The curtain's dithered front is this many pixels wide.
FRONT_WIDTH = 672

# The characters of the font the script asks for by name: box-drawing pieces
# for the frame, a block for the cursor, the prompt, and the six frames of the
# font's spinner.
NAMED_GLYPHS = {
    "HORIZONTAL": "─",
    "VERTICAL": "│",
    "TOP_LEFT": "╭",
    "TOP_RIGHT": "╮",
    "BOTTOM_LEFT": "╰",
    "BOTTOM_RIGHT": "╯",
    "BLOCK": "█",
    "PROMPT": "›",
    "DOT": "·",
    "SPIN_0": "",
    "SPIN_1": "",
    "SPIN_2": "",
    "SPIN_3": "",
    "SPIN_4": "",
    "SPIN_5": "",
}

# Printable ASCII, then the named ones. A character's place in this list is
# its place in every glyph picture.
ASCII = [chr(code) for code in range(32, 127)]
CHARACTERS = ASCII + list(NAMED_GLYPHS.values())

# The glyph pictures, by the colour each is drawn in.
GLYPH_COLOURS = ["line", "dim", "soft", "ink", "accent", "alert"]


def bayer8(x, y):
    """The 8 x 8 ordered-dither threshold of a dot, from 0 to 63."""
    value = 0
    # The lowest bits of the position count for most, which is what spreads
    # the dots out evenly at every level.
    for bit in range(3):
        x_bit = (x >> bit) & 1
        y_bit = (y >> bit) & 1
        # The 2 x 2 pattern is 0 2 / 3 1.
        value = value * 4 + [[0, 2], [3, 1]][y_bit][x_bit]
    return value


def colour_tuple(hex_colour, alpha=255):
    return (int(hex_colour[0:2], 16), int(hex_colour[2:4], 16), int(hex_colour[4:6], 16), alpha)


def glyph_mask(font, baseline):
    """Every character side by side, as a 1-bit picture: set where there is ink."""
    mask = Image.new("1", (CELL_WIDTH * len(CHARACTERS), CELL_HEIGHT), 0)
    draw = ImageDraw.Draw(mask)
    # No smoothing: each pixel of the font is on or off.
    draw.fontmode = "1"
    for index, character in enumerate(CHARACTERS):
        draw.text((index * CELL_WIDTH, baseline), character, font=font, fill=1, anchor="ls")
    return mask


def coloured(mask, hex_colour):
    picture = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    picture.paste(colour_tuple(hex_colour), mask=mask)
    return picture


def main():
    font_file = sys.argv[1]
    output = Path(sys.argv[2])
    colours = dict(argument.split("=") for argument in sys.argv[3:])
    output.mkdir(parents=True, exist_ok=True)

    font = ImageFont.truetype(font_file, FONT_PIXELS)
    ascent, descent = font.getmetrics()
    # The line of text sits in the middle of the cell's height.
    baseline = (CELL_HEIGHT - (ascent + descent)) // 2 + ascent

    mask = glyph_mask(font, baseline)
    for name in GLYPH_COLOURS:
        coloured(mask, colours[name]).save(output / f"glyphs-{name}.png")
    big = coloured(mask, colours["ink"])
    big.resize((big.width * BIG, big.height * BIG), Image.NEAREST).save(output / "glyphs-big.png")

    # The dither field: level n has n of the pattern's 64 dots.
    tile = 8 * DOT
    for level in range(33):
        field = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
        for y in range(tile):
            for x in range(tile):
                if bayer8(x // DOT, y // DOT) < level:
                    field.putpixel((x, y), colour_tuple(colours["field"]))
        field.save(output / f"field-{level:02d}.png")

    # The curtain's front: clear at its left edge, solid at its right.
    curtain = Image.new("RGBA", (FRONT_WIDTH, tile), (0, 0, 0, 0))
    for y in range(tile):
        for x in range(FRONT_WIDTH):
            if bayer8(x // DOT, y // DOT) < 64 * x / FRONT_WIDTH:
                curtain.putpixel((x, y), colour_tuple(colours["background"]))
    curtain.save(output / "curtain.png")

    Image.new("RGBA", (tile, tile), colour_tuple(colours["background"])).save(output / "solid.png")

    # The shadow: every other dot, in the background colour at half its
    # brightness, as the shell's panels cast.
    red, green, blue, opaque = colour_tuple(colours["background"])
    shadow_colour = (red // 2, green // 2, blue // 2, opaque)
    shadow = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
    for y in range(tile):
        for x in range(tile):
            if (x // DOT + y // DOT) % 2 == 0:
                shadow.putpixel((x, y), shadow_colour)
    shadow.save(output / "shadow.png")

    # Where each character is, for the script. A quote and a backslash
    # cannot be written simply in its strings, and it does not need them.
    lines = ["# Written by make-images.py: where each character is in the glyph pictures.\n"]
    for index, character in enumerate(ASCII):
        if character in '"\\':
            continue
        lines.append(f'glyph_index["{character}"] = {index};\n')
        lines.append(f'glyph_known["{character}"] = 1;\n')
    for offset, name in enumerate(NAMED_GLYPHS):
        lines.append(f"GLYPH_{name} = {len(ASCII) + offset};\n")
    (output / "glyphs.script").write_text("".join(lines))


main()
