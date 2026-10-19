# Stylix session colors plus layout and motion knobs.
# Change aesthetics here (and style.css vars) — overlay.py reads these constants.
import os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WALLPAPER_DIR = os.path.join(REPO, "assets", "wallpapers")


def color(name, fallback):
    return os.environ.get(name, fallback)


BASE00 = color("BASE00", "#241d1a")
BASE04 = color("BASE04", "#a78e84")
BASE05 = color("BASE05", "#b8a59d")
BASE08 = color("BASE08", "#f6998f")
BASE09 = color("BASE09", "#ffa888")
BASE0B = color("BASE0B", "#b6c68a")

# Ring: mode pills sit RING_RADIUS from the hub. On dive the focused pill
# collapses into the hub (which grows to HUB_DIVE_SIZE and shows its name)
# while the other pills fly a further RING_DIVE_PUSH outward and fade.
HUB_SIZE = 72
HUB_DIVE_SIZE = 110
RING_RADIUS = 210
RING_DIVE_PUSH = 120
SLOT_WIDTH = 200
SLOT_HEIGHT = 52

# Sub-item pills fanned out along the ring on dive. A fixed gap per item
# (instead of 360/count) keeps 4- and 5-item fans equally composed; the
# selected item always sits at 0° (right), pointing at the details panel.
SUB_WIDTH = 180
SUB_HEIGHT = 40
SUB_GAP_DEG = 55

# Details panel beside the ring
DETAILS_WIDTH = 300
DETAILS_GAP = 30
DETAILS_SEARCH_HEIGHT = 360
DETAILS_SETTINGS_HEIGHT = 320
DETAILS_POWER_HEIGHT = 160

# Wallpaper grid — thumb cache size matches the on-screen cell
WALLPAPER_COLUMNS = 3
WALLPAPER_THUMB_WIDTH = 160
WALLPAPER_THUMB_HEIGHT = 90
WALLPAPER_CELL_WIDTH = 176
WALLPAPER_CELL_HEIGHT = 118
DETAILS_WALLPAPER_HEIGHT = 340

ICON_SIZE = 24
RAIL_MAX_LINES = 40

# Motion (ms)
OPEN_MS = 380
CLOSE_MS = 200
FADE_IN_MS = 150
ROTATE_MS = 320
DIVE_MS = 300
HOLD_MS = 2000
OPEN_GUARD_MS = 200
# Each sub-item starts its fan-out this fraction of the dive later than the last.
SUB_STAGGER = 0.12
