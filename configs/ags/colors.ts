// Stylix base16 palette + semantic tokens, mirroring quickshell's Theme.qml:
// colors come from BASE00–BASE0F session env vars (same mechanism the bar
// uses), with gruvbox fallbacks. Emitted as CSS variables on :root; alpha
// variants are precomputed here because GTK CSS cannot rgba() a variable.
import GLib from "gi://GLib"

const FALLBACKS: Record<string, string> = {
  BASE00: "#1d2021",
  BASE01: "#3c3836",
  BASE02: "#504945",
  BASE03: "#665c54",
  BASE04: "#bdae93",
  BASE05: "#d5c4a1",
  BASE06: "#ebdbb2",
  BASE07: "#fbf1c7",
  BASE08: "#fb4934",
  BASE09: "#fe8019",
  BASE0A: "#fabd2f",
  BASE0B: "#b8bb26",
  BASE0C: "#8ec07c",
  BASE0D: "#83a598",
  BASE0E: "#d3869b",
  BASE0F: "#d65d0e",
}

function baseColor(name: string): string {
  const value = GLib.getenv(name)
  return value && value !== "" ? value : FALLBACKS[name]
}

export const palette = Object.fromEntries(
  Object.keys(FALLBACKS).map((name) => [name, baseColor(name)]),
) as Record<keyof typeof FALLBACKS, string>

// ── semantic tokens (names follow quickshell's Theme.qml) ──
export const surface = palette.BASE00
export const surface1 = palette.BASE01
export const surface2 = palette.BASE02
export const textPrimary = palette.BASE05
export const textDimmed = palette.BASE04
export const textSubtle = palette.BASE03
export const accent = palette.BASE0D
export const accentWarm = palette.BASE09
export const accentWarning = palette.BASE0A
export const accentDanger = palette.BASE08
export const accentSuccess = palette.BASE0B
export const accentPurple = palette.BASE0E

export function hexToRgb(hex: string): [number, number, number] {
  const clean = hex.replace("#", "")
  return [
    parseInt(clean.slice(0, 2), 16) / 255,
    parseInt(clean.slice(2, 4), 16) / 255,
    parseInt(clean.slice(4, 6), 16) / 255,
  ]
}

export function rgba(hex: string, alpha: number): string {
  const [r, g, b] = hexToRgb(hex)
  return `rgba(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)}, ${alpha})`
}

// Blend a color onto a background at the given opacity (for Pango markup,
// which cannot use CSS variables or alpha).
export function mixOnto(hex: string, onto: string, alpha: number): string {
  const [r1, g1, b1] = hexToRgb(hex)
  const [r2, g2, b2] = hexToRgb(onto)
  const channel = (a: number, b: number) =>
    Math.round((a * alpha + b * (1 - alpha)) * 255)
      .toString(16)
      .padStart(2, "0")
  return `#${channel(r1, r2)}${channel(g1, g2)}${channel(b1, b2)}`
}

// CSS variables consumed by style.scss. Alpha steps are precomputed.
export function cssVariables(): string {
  const alphaSteps = (name: string, hex: string, steps: number[]) =>
    steps
      .map((step) => `--${name}-${step}: ${rgba(hex, step / 100)};`)
      .join("\n  ")
  return `:root {
  --surface: ${surface};
  --surface1: ${surface1};
  --surface2: ${surface2};
  --text: ${textPrimary};
  --text-dim: ${textDimmed};
  --text-subtle: ${textSubtle};
  --accent: ${accent};
  --warm: ${accentWarm};
  --warning: ${accentWarning};
  --danger: ${accentDanger};
  --success: ${accentSuccess};
  --purple: ${accentPurple};
  ${alphaSteps("text", textPrimary, [4, 6, 8, 10, 15, 22, 25, 30, 40, 50, 60])}
  ${alphaSteps("accent", accent, [12, 20, 40, 55])}
  --accent-fill: ${mixOnto(accent, surface, 0.15)};
  ${alphaSteps("surface", surface, [60, 92])}
}`
}
