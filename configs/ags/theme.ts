// Layout and motion knobs for the ring overlay, ported from the fabric
// version's theme.py. Colors live in style.scss.
import GLib from "gi://GLib"

export const WALLPAPER_DIR = GLib.build_filenamev([
  GLib.get_home_dir(),
  "nixos-config",
  "assets",
  "wallpapers",
])

// Ring: mode pills sit RING_RADIUS from the hub. On dive the focused pill
// collapses into the hub (which grows to HUB_DIVE_SIZE and shows its name)
// while the other pills fly a further RING_DIVE_PUSH outward and fade.
export const HUB_SIZE = 96
export const HUB_DIVE_SIZE = 140
export const RING_RADIUS = 240
export const RING_DIVE_PUSH = 120
export const SLOT_WIDTH = 236
export const SLOT_HEIGHT = 64

// Sub-item pills fan out on dive: a static arc on the right, symmetric
// about the horizontal axis, with a fixed gap per item. Selection moves
// the highlight along the arc (the fan itself does not spin).
export const SUB_WIDTH = 200
export const SUB_HEIGHT = 52
export const SUB_GAP_DEG = 42

// Details panel beside the ring
export const DETAILS_WIDTH = 340
export const DETAILS_GAP = 30
export const DETAILS_SEARCH_HEIGHT = 440
// Most-launched apps shown as a quick row above the search list.
export const FRECENT_COUNT = 6
export const DETAILS_SETTINGS_HEIGHT = 320
export const DETAILS_POWER_HEIGHT = 200

// Wallpaper grid
export const WALLPAPER_COLUMNS = 3
export const WALLPAPER_THUMB_WIDTH = 160
export const WALLPAPER_THUMB_HEIGHT = 90
export const WALLPAPER_CELL_WIDTH = 176
export const WALLPAPER_CELL_HEIGHT = 132
export const WALLPAPER_ROWS = 2
export const DETAILS_WALLPAPER_HEIGHT = 380

// Footer line of key hints inside every panel.
export const HINT_HEIGHT = 30

// Motion (ms)
export const OPEN_MS = 380
export const CLOSE_MS = 200
// On close the ring pulls in toward the hub by this fraction of the
// radius while it fades (a full collapse read as an implosion).
export const CLOSE_PULL = 0.2
export const FADE_IN_MS = 150
export const DIVE_MS = 300
// Ring spin is a live spring (rad/s + damping ratio): settles in ~0.4 s
// with one soft overshoot, and chained h/l presses keep their momentum.
export const RING_SPRING_OMEGA = 16
export const RING_SPRING_ZETA = 0.62
export const HOLD_MS = 2000
export const OPEN_GUARD_MS = 200
// Each sub-item starts its fan-out this fraction of the dive later.
export const SUB_STAGGER = 0.12
// The selected fan pill grows slightly (GPU transform) as selection moves.
export const SUB_SELECT_MS = 160
export const SUB_SELECT_SCALE = 1.05
