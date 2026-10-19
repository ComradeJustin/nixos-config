// Shared pane surface and small widget builders for the ring overlay.
// Each pane owns one mode's panel content, fan items, and selection; the
// overlay owns the ring, animation, and key routing.
import { Gtk } from "ags/gtk4"
import Pango from "gi://Pango"
import { mixOnto, rgba, surface } from "../colors"
import * as theme from "../theme"

export interface SubItem {
  widget: Gtk.Widget
  body: Gtk.Widget
  dot: Gtk.Widget
  // Optional live-status line under the title (hidden until set).
  subtitle: Gtk.Label
  key: string
}

// What panes are allowed to ask of the overlay.
export interface Shell {
  requestClose(): void
  beginWifiPassword(ssid: string): void
  // Hold-to-confirm progress, drawn as an arc closing around the hub
  // in the action's color.
  setHoldProgress(progress: number, colorHex?: string): void
  // Wash the pane's panel with a color (null restores the surface).
  tintPanel(pane: Pane, colorHex: string | null): void
}

// Per-widget CSS that can change at runtime (gnim's `css` prop is fixed at
// build time). One provider per widget, replaced on each call.
const widgetProviders = new WeakMap<Gtk.Widget, Gtk.CssProvider>()

export function setWidgetCss(widget: Gtk.Widget, css: string) {
  let provider = widgetProviders.get(widget)
  if (provider === undefined) {
    provider = new Gtk.CssProvider()
    // Above the app stylesheet (installed at USER priority by ags), or
    // its rules for the same properties win.
    widget
      .get_style_context()
      .add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER + 1)
    widgetProviders.set(widget, provider)
  }
  provider.load_from_string(css)
}

// [key, meaning] pairs shown as a footer line under the panel content.
export type Hint = [string, string]

export interface Pane {
  hints: Hint[]
  detailsSize(): [number, number]
  buildSubs(): SubItem[]
  buildDetails(): Gtk.Widget
  // One short live-status line for the pane's ring pill ("Give Cures ·
  // 84%", "12 apps"); empty string falls back to the static subtitle.
  summary(): string
  ensure(): void
  move(dx: number, dy: number): void
  jump(toEnd: boolean): void
  accept(keyval: number): void
  applyFilter?(text: string): void
  onLetter?(letter: string, keyval: number): boolean
}

export function headerLabel(text: string): Gtk.Label {
  return (
    <label class="detail-h display" halign={Gtk.Align.START} label={text} />
  ) as Gtk.Label
}

export function detailRule(): Gtk.Widget {
  return (<box class="detail-rule" />) as Gtk.Widget
}

export function hintRow(hints: Hint[]): Gtk.Widget {
  return (
    <box class="hint-row" spacing={14} valign={Gtk.Align.END}>
      {hints.map(([key, meaning]) => (
        <box spacing={6}>
          <label class="hint-key mono" label={key} />
          <label class="hint-text" label={meaning} />
        </box>
      ))}
    </box>
  ) as Gtk.Widget
}

export function subPill(
  key: string,
  title: string,
  icon: string,
  onPress: () => void,
  onRelease?: () => void,
  accentHex?: string,
): SubItem {
  let dot!: Gtk.Image
  let body!: Gtk.Box
  let subtitle!: Gtk.Label
  // Per-action accent (power): the pill and icon adopt the action's color
  // when selected, via widget-scoped CSS variables the stylesheet reads.
  // Fill is an opaque blend (not a translucent wash) so selected pills
  // read as solid surfaces; glow stays soft.
  const accentCss = accentHex
    ? `--pill: ${accentHex}; --pill-fill: ${mixOnto(accentHex, surface, 0.15)}; --pill-glow: ${rgba(accentHex, 0.25)};`
    : ""
  const widget = (
    <box
      $={(ref: Gtk.Box) => (body = ref)}
      class="pill sub"
      css={accentCss}
      widthRequest={theme.SUB_WIDTH}
      heightRequest={theme.SUB_HEIGHT}
    >
      <box class="sub-inner" spacing={10} hexpand valign={Gtk.Align.CENTER}>
        <image
          $={(ref: Gtk.Image) => (dot = ref)}
          class="sub-glyph"
          iconName={icon}
          valign={Gtk.Align.CENTER}
        />
        <box orientation={Gtk.Orientation.VERTICAL} valign={Gtk.Align.CENTER}>
          <label class="sub-title" label={title} halign={Gtk.Align.START} />
          <label
            $={(ref: Gtk.Label) => (subtitle = ref)}
            class="sub-subtitle"
            halign={Gtk.Align.START}
            ellipsize={Pango.EllipsizeMode.END}
            maxWidthChars={16}
            visible={false}
          />
        </box>
        <label
          class="sub-key mono"
          label={key}
          hexpand
          halign={Gtk.Align.END}
          valign={Gtk.Align.CENTER}
        />
      </box>
    </box>
  ) as Gtk.Widget
  // Mouse selection: press activates (and starts a hold for power's
  // hold-to-confirm actions), release ends a pointer-started hold.
  const click = new Gtk.GestureClick()
  click.connect("pressed", () => onPress())
  click.connect("released", () => onRelease?.())
  widget.add_controller(click)
  return { widget, body, dot, subtitle, key }
}

export function setSubtitle(item: SubItem, text: string) {
  item.subtitle.label = text
  item.subtitle.visible = text !== ""
}

export function setSelected(widget: Gtk.Widget, selected: boolean) {
  if (selected) widget.add_css_class("selected")
  else widget.remove_css_class("selected")
}

export function scrollIntoView(scroller: Gtk.ScrolledWindow, row: Gtk.Widget) {
  const content = scroller.child // Gtk.Viewport
  if (!(content instanceof Gtk.Viewport)) return
  const inner = content.child
  if (inner === null) return
  const [ok, bounds] = row.compute_bounds(inner)
  if (!ok) return
  const top = bounds.get_y()
  const bottom = top + bounds.get_height()
  const adjustment = scroller.vadjustment
  if (top < adjustment.value) {
    adjustment.value = top
  } else if (bottom > adjustment.value + adjustment.pageSize) {
    adjustment.value = bottom - adjustment.pageSize
  }
}
