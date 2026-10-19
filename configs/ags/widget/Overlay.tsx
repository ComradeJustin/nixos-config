// Ring overlay: a hub with four mode pills on a ring. h/l rotate the ring so
// the focused pill sits on the right; dive collapses that pill into the hub
// (which then names it), fans its sub-items out in a static right-side arc,
// and fades a details panel in beside it. Every frame is a pure function of
// the tweened values — see layoutFrame. Ported from the fabric (GTK3)
// version; panes live in search/wallpaper/network/power.
import app from "ags/gtk4/app"
import { Astal, Gdk, Gtk } from "ags/gtk4"
import GLib from "gi://GLib"
import Graphene from "gi://Graphene"
import Gsk from "gi://Gsk"
import Pango from "gi://Pango"
import * as colors from "../colors"
import * as theme from "../theme"
import { Tweens, easeOutCubic, spring } from "../tween"
import { Pane, Shell, SubItem, hintRow, setWidgetCss } from "./common"
import { NetworkPane } from "./network"
import { PowerPane } from "./power"
import { SearchPane } from "./search"
import { WallpaperPane } from "./wallpaper"

// Timed spring easing for the open motion (the ring spin uses a live
// spring instead, see rotateTo).
const springEase = spring()

// Diameter of the hold-to-confirm arc, sized to circle the dived hub.
const HOLD_ARC_SIZE = theme.HUB_DIVE_SIZE + 18
// Height of the docked filter field (padding + entry), for placement.
const COMMAND_BAR_HEIGHT = 48

const RING = ["search", "wallpaper", "network", "power"] as const
type SlotId = (typeof RING)[number]

const PREFIX: Record<string, SlotId> = {
  s: "search",
  w: "wallpaper",
  n: "network",
  p: "power",
}

// Symbolic theme icons (recolored via CSS): no font can be trusted to
// ship glyph codepoints, and icons center properly.
const SLOT_INFO: Record<
  SlotId,
  { key: string; title: string; subtitle: string; icon: string }
> = {
  search: {
    key: "s",
    title: "Search",
    subtitle: "apps",
    icon: "system-search-symbolic",
  },
  wallpaper: {
    key: "w",
    title: "Wallpaper",
    subtitle: "background",
    icon: "image-x-generic-symbolic",
  },
  network: {
    key: "n",
    title: "Network",
    subtitle: "wifi · audio",
    icon: "network-wireless-symbolic",
  },
  power: {
    key: "p",
    title: "Power",
    subtitle: "session",
    icon: "system-shutdown-symbolic",
  },
}

interface Slot {
  card: Gtk.Widget
  body: Gtk.Widget
  dot: Gtk.Widget
  subtitle: Gtk.Label
  title: string
  subItems: SubItem[]
  details: Gtk.Widget
}

type Mode = "normal" | "filter" | "wifi-pass"

export class Overlay implements Shell {
  window: Astal.Window
  private plane = new Gtk.Fixed()
  private hub!: Gtk.Box
  private hubTitle!: Gtk.Label
  private hubGlyph!: Gtk.Image
  private hubClock!: Gtk.Label
  private hubDate!: Gtk.Label
  private hubRest!: Gtk.Box
  private clockTimer = 0
  private holdArc!: Gtk.DrawingArea
  private holdProgress = 0
  private holdColor = colors.accentDanger
  private slots = {} as Record<SlotId, Slot>
  private panes = {} as Record<SlotId, Pane>
  private powerPane: PowerPane
  private networkPane: NetworkPane
  private tweens: Tweens
  private focused: SlotId = "search"
  private dived = false
  private mode: Mode = "normal"
  private closing = false
  private openedMs = 0
  private pendingG = false
  private wifiSsid = ""
  private entry!: Gtk.Entry
  private prompt!: Gtk.Label
  private commandBar!: Gtk.Box

  constructor() {
    this.powerPane = new PowerPane(this)
    this.networkPane = new NetworkPane(this)
    this.panes = {
      search: new SearchPane(this),
      wallpaper: new WallpaperPane(this),
      network: this.networkPane,
      power: this.powerPane,
    }

    this.hubTitle = (
      <label
        cssName="hub-title"
        class="display"
        opacity={0}
        halign={Gtk.Align.CENTER}
        justify={Gtk.Justification.CENTER}
      />
    ) as Gtk.Label
    this.hubGlyph = (
      <image cssName="hub-glyph" opacity={0} halign={Gtk.Align.CENTER} />
    ) as Gtk.Image
    // At rest the hub shows the time (the display face's moment); on dive
    // it crossfades to the mode's icon and name.
    this.hubClock = (
      <label cssName="hub-clock" class="display" halign={Gtk.Align.CENTER} />
    ) as Gtk.Label
    this.hubDate = (
      <label cssName="hub-date" halign={Gtk.Align.CENTER} />
    ) as Gtk.Label
    this.hubRest = (
      <box
        orientation={Gtk.Orientation.VERTICAL}
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
      >
        {this.hubClock}
        {this.hubDate}
      </box>
    ) as Gtk.Box
    this.hub = (
      <box
        cssName="hub"
        halign={Gtk.Align.START}
        valign={Gtk.Align.START}
        widthRequest={theme.HUB_SIZE}
        heightRequest={theme.HUB_SIZE}
        canTarget={false}
      >
        <Gtk.Overlay hexpand vexpand>
          {this.hubRest}
          <box
            $type="overlay"
            orientation={Gtk.Orientation.VERTICAL}
            spacing={2}
            halign={Gtk.Align.CENTER}
            valign={Gtk.Align.CENTER}
          >
            {this.hubGlyph}
            {this.hubTitle}
          </box>
        </Gtk.Overlay>
      </box>
    ) as Gtk.Box
    this.plane.put(this.hub, 0, 0)

    // Hold-to-confirm arc, drawn just outside the hub's edge.
    this.holdArc = new Gtk.DrawingArea()
    this.holdArc.set_size_request(HOLD_ARC_SIZE, HOLD_ARC_SIZE)
    this.holdArc.canTarget = false
    this.holdArc.visible = false
    this.holdArc.set_draw_func((_area, cr, width, height) => {
      const radius = width / 2 - 4
      // Faint full track, then the action-colored arc from 12 o'clock.
      const [trackR, trackG, trackB] = colors.hexToRgb(colors.textPrimary)
      cr.setLineWidth(3)
      cr.setSourceRGBA(trackR, trackG, trackB, 0.25)
      cr.arc(width / 2, height / 2, radius, 0, 2 * Math.PI)
      cr.stroke()
      const [r, g, b] = colors.hexToRgb(this.holdColor)
      cr.setLineWidth(4)
      cr.setSourceRGBA(r, g, b, 0.9)
      cr.arc(
        width / 2,
        height / 2,
        radius,
        -Math.PI / 2,
        -Math.PI / 2 + this.holdProgress * 2 * Math.PI,
      )
      cr.stroke()
    })
    this.plane.put(this.holdArc, 0, 0)

    for (const slotId of RING) this.buildSlot(slotId)

    this.prompt = (
      <label cssName="prompt" class="mono" label="/" />
    ) as Gtk.Label
    this.entry = (
      <entry cssName="cmd-entry" class="mono" hexpand />
    ) as Gtk.Entry
    this.entry.connect("notify::text", () => {
      if (this.mode !== "filter") return
      this.panes[this.focused].applyFilter?.(this.entry.text)
    })
    // Docked to the top edge of the focused pane's panel (positioned in
    // layoutFrame), so the filter field sits with the list it narrows.
    this.commandBar = (
      <box cssName="command-bar" spacing={8} visible={false}>
        {this.prompt}
        {this.entry}
      </box>
    ) as Gtk.Box
    this.plane.put(this.commandBar, 0, 0)

    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
    this.window = (
      <window
        name="overlay"
        namespace="ags-overlay"
        visible={false}
        anchor={TOP | BOTTOM | LEFT | RIGHT}
        exclusivity={Astal.Exclusivity.IGNORE}
        keymode={Astal.Keymode.EXCLUSIVE}
        layer={Astal.Layer.OVERLAY}
        application={app}
      >
        {/* Capture phase: navigation keys must reach the overlay before the
            focused Entry can swallow them; unhandled keys fall through. */}
        <Gtk.EventControllerKey
          propagationPhase={Gtk.PropagationPhase.CAPTURE}
          onKeyPressed={(
            _c: Gtk.EventControllerKey,
            keyval: number,
            _code: number,
            state: number,
          ) => this.onKeyPressed(keyval, state)}
          onKeyReleased={(_c: Gtk.EventControllerKey, keyval: number) =>
            this.onKeyReleased(keyval)
          }
        />
        <Gtk.EventControllerScroll
          flags={Gtk.EventControllerScrollFlags.VERTICAL}
          onScroll={(_c: Gtk.EventControllerScroll, _dx: number, dy: number) =>
            this.onScroll(dy)
          }
        />
        <Gtk.GestureClick
          onPressed={(_g: Gtk.GestureClick, _n: number, x: number, y: number) =>
            this.onScrimClick(x, y)
          }
        />
        <Gtk.Overlay cssName="scrim">{this.plane}</Gtk.Overlay>
      </window>
    ) as Astal.Window

    this.tweens = new Tweens(
      this.window,
      ["open", "angle", "dive", "fade", ...this.subScaleNames],
      () => this.layoutFrame(),
    )
  }

  // One tween per fan pill (0 = resting, 1 = selected size).
  private subScaleNames: string[] = []

  private subScaleName(slotId: SlotId, index: number): string {
    return `sub:${slotId}:${index}`
  }

  // ── slots ──

  private buildSlot(slotId: SlotId) {
    const info = SLOT_INFO[slotId]
    let body!: Gtk.Box
    let dot!: Gtk.Image
    let subtitle!: Gtk.Label
    const card = (
      <box
        $={(ref: Gtk.Box) => (body = ref)}
        class="pill slot"
        widthRequest={theme.SLOT_WIDTH}
        heightRequest={theme.SLOT_HEIGHT}
      >
        <box class="slot-inner" spacing={12} hexpand valign={Gtk.Align.CENTER}>
          <image
            $={(ref: Gtk.Image) => (dot = ref)}
            class="slot-glyph"
            iconName={info.icon}
            valign={Gtk.Align.CENTER}
          />
          <box
            orientation={Gtk.Orientation.VERTICAL}
            spacing={1}
            hexpand
            valign={Gtk.Align.CENTER}
          >
            <label
              class="slot-title"
              label={info.title}
              halign={Gtk.Align.START}
            />
            <label
              $={(ref: Gtk.Label) => (subtitle = ref)}
              class="slot-subtitle"
              label={info.subtitle}
              halign={Gtk.Align.START}
              ellipsize={Pango.EllipsizeMode.END}
            />
          </box>
          <label
            class="slot-key mono"
            label={info.key}
            halign={Gtk.Align.END}
            valign={Gtk.Align.CENTER}
          />
        </box>
      </box>
    ) as Gtk.Widget
    const click = new Gtk.GestureClick()
    click.connect("pressed", () => {
      this.focused = slotId
      this.dive()
    })
    card.add_controller(click)

    const pane = this.panes[slotId]
    const subItems = pane.buildSubs()
    const [detailsWidth, detailsHeight] = this.panelSize(pane)
    // Pane content on top, its key hints pinned to the panel's bottom edge.
    const details = (
      <box
        class="pill panel"
        orientation={Gtk.Orientation.VERTICAL}
        widthRequest={detailsWidth}
        heightRequest={detailsHeight}
        visible={false}
      >
        <box vexpand valign={Gtk.Align.START}>
          {pane.buildDetails()}
        </box>
        {hintRow(pane.hints)}
      </box>
    ) as Gtk.Widget

    this.plane.put(card, 0, 0)
    subItems.forEach((item, index) => {
      item.widget.visible = false
      this.plane.put(item.widget, 0, 0)
      // Panes mark selection with the "selected" class; the overlay follows
      // that with a small scale-up so the pill grows as focus lands on it.
      const name = this.subScaleName(slotId, index)
      this.subScaleNames.push(name)
      item.body.connect("notify::css-classes", () => {
        const target = item.body.has_css_class("selected") ? 1 : 0
        if (this.tweens.values[name] === target) return
        this.tweens.animate(name, target, theme.SUB_SELECT_MS, easeOutCubic)
      })
    })
    this.plane.put(details, 0, 0)
    this.slots[slotId] = {
      card,
      body,
      dot,
      subtitle,
      title: info.title,
      subItems,
      details,
    }
  }

  // Panel = pane content plus the hint footer.
  private panelSize(pane: Pane): [number, number] {
    const [width, height] = pane.detailsSize()
    return [width, height + theme.HINT_HEIGHT]
  }

  // ── open / close ──

  toggle() {
    if (this.window.visible && !this.closing) this.requestClose()
    else this.open()
  }

  private resetSession() {
    this.closing = false
    this.dived = false
    this.focused = "search"
    this.mode = "normal"
    this.wifiSsid = ""
    this.entry.text = ""
    this.powerPane.cancelHold()
    this.pendingG = false
    this.tweens.reset()
  }

  private updateClock() {
    const now = GLib.DateTime.new_now_local()
    this.hubClock.label = now.format("%H:%M") ?? ""
    this.hubDate.label = now.format("%a %e %b") ?? ""
  }

  private open() {
    this.resetSession()
    this.openedMs = GLib.get_monotonic_time() / 1000
    this.updateClock()
    if (this.clockTimer === 0) {
      this.clockTimer = GLib.timeout_add_seconds(
        GLib.PRIORITY_DEFAULT,
        1,
        () => {
          this.updateClock()
          return GLib.SOURCE_CONTINUE
        },
      )
    }
    this.window.opacity = 0
    this.window.visible = true
    for (const slotId of RING) {
      const slot = this.slots[slotId]
      slot.card.visible = true
      slot.card.sensitive = true
      slot.details.visible = false
      for (const item of slot.subItems) item.widget.visible = false
      // Live status on the pill ("Give Cures · 84%") beats a static label.
      slot.subtitle.label =
        this.panes[slotId].summary() || SLOT_INFO[slotId].subtitle
    }
    this.commandBar.visible = false
    this.applyFocus()
    // Wait for the first allocation on the frame clock. (A plain idle at
    // default priority outranks GTK's layout idles and starves the very
    // allocation it waits for — the window then never becomes visible.)
    this.window.add_tick_callback(() => {
      if (this.window.get_width() <= 1) return GLib.SOURCE_CONTINUE
      this.startOpen()
      return GLib.SOURCE_REMOVE
    })
  }

  private startOpen() {
    this.layoutFrame()
    this.tweens.animate("fade", 1, theme.FADE_IN_MS, easeOutCubic)
    this.tweens.animate("open", 1, theme.OPEN_MS, springEase)
  }

  requestClose() {
    if (!this.window.visible || this.closing) return
    this.closing = true
    this.powerPane.cancelHold()
    this.dived = false
    this.mode = "normal"
    this.renderChrome()
    this.tweens.animate("dive", 0, theme.CLOSE_MS, easeOutCubic)
    this.tweens.animate(
      "open",
      1 - theme.CLOSE_PULL,
      theme.CLOSE_MS,
      easeOutCubic,
    )
    this.tweens.animate("fade", 0, theme.CLOSE_MS, easeOutCubic)
    this.tweens.onSettled = () => {
      this.closing = false
      this.window.visible = false
      this.resetFilter()
      if (this.clockTimer !== 0) {
        GLib.source_remove(this.clockTimer)
        this.clockTimer = 0
      }
    }
  }

  // Filters live per-pane; leaving a pane (close, undive, pane jump) must
  // clear both the entry and the pane's narrowed list, or a stale filter
  // survives with an empty prompt.
  private resetFilter() {
    this.entry.text = ""
    this.panes[this.focused].applyFilter?.("")
  }

  // ── dive / focus ──

  private syncDiveWidgets() {
    for (const slotId of RING) {
      const slot = this.slots[slotId]
      const here = this.dived && slotId === this.focused
      slot.card.sensitive = !this.dived
      for (const item of slot.subItems) item.widget.visible = here
      slot.details.visible = here
    }
  }

  dive() {
    // No ring spin here: the focused pill collapses into the hub from
    // wherever it sits (the fan and panel are angle-independent), so
    // direct jumps (w/n/p/s, clicks) dive in place. Only h/l spins.
    this.dived = true
    this.panes[this.focused].ensure()
    this.hubTitle.label = this.slots[this.focused].title
    this.hubGlyph.iconName = SLOT_INFO[this.focused].icon
    this.applyFocus()
    // Row cascade: the panel maps in its "cascade" state (rows shifted down
    // and transparent, no transition), then the class comes off one frame
    // later and the stylesheet's staggered transitions bring the rows in.
    const details = this.slots[this.focused].details
    details.add_css_class("cascade")
    this.syncDiveWidgets()
    this.window.add_tick_callback(() => {
      details.remove_css_class("cascade")
      return GLib.SOURCE_REMOVE
    })
    this.tweens.animate("dive", 1, theme.DIVE_MS, easeOutCubic)
  }

  private undive() {
    this.powerPane.cancelHold()
    // The ring is invisible while dived, so re-orient it now: the focused
    // pill fades back in at the front, keeping the "focused = front"
    // invariant that h/l stepping depends on — without a visible spin.
    this.tweens.snap("angle", -90 * RING.indexOf(this.focused))
    this.dived = false
    this.applyFocus()
    this.tweens.animate("dive", 0, theme.DIVE_MS, easeOutCubic)
    // Clear the filter after the fade so the full list never flashes.
    this.tweens.onSettled = () => {
      this.syncDiveWidgets()
      this.resetFilter()
    }
  }

  private applyFocus() {
    for (const slotId of RING) {
      const slot = this.slots[slotId]
      if (slotId === this.focused) {
        slot.body.add_css_class("focused")
        slot.dot.add_css_class("on")
      } else {
        slot.body.remove_css_class("focused")
        slot.dot.remove_css_class("on")
      }
    }
  }

  private rotateTo(slotId: SlotId) {
    // Spin the ring the short way round so slotId ends up on the right.
    const target = -90 * RING.indexOf(slotId)
    const current = this.tweens.values["angle"]
    const turns = Math.round((current - target) / 360)
    const destination = target + turns * 360
    if (Math.abs(destination - current) < 0.001) return
    this.tweens.springTo(
      "angle",
      destination,
      theme.RING_SPRING_ZETA,
      theme.RING_SPRING_OMEGA,
    )
  }

  private rotateRing(step: number) {
    const index =
      (RING.indexOf(this.focused) + step + RING.length) % RING.length
    this.focused = RING[index]
    this.applyFocus()
    this.rotateTo(this.focused)
  }

  // ── layout ──

  private layoutFrame() {
    const openT = this.tweens.values["open"]
    const diveT = this.tweens.values["dive"]
    const angle = this.tweens.values["angle"]
    this.window.opacity = this.tweens.values["fade"]

    const width = this.window.get_width()
    const height = this.window.get_height()
    const focused = this.slots[this.focused]
    const [panelWidth, panelHeight] = this.panelSize(this.panes[this.focused])
    const ringReach =
      focused.subItems.length > 0
        ? theme.RING_RADIUS + theme.SUB_WIDTH / 2
        : theme.HUB_DIVE_SIZE / 2
    // The ring drifts left while the panel fades in beside it so the pair
    // stays centered on screen.
    const fullPan = (theme.DETAILS_GAP + panelWidth) / 2
    const centerX = width / 2 - diveT * fullPan
    const centerY = height / 2

    const hubSize =
      theme.HUB_SIZE + diveT * (theme.HUB_DIVE_SIZE - theme.HUB_SIZE)
    this.hub.set_size_request(Math.round(hubSize), Math.round(hubSize))
    this.plane.move(
      this.hub,
      Math.round(centerX - hubSize / 2),
      Math.round(centerY - hubSize / 2),
    )
    this.hubTitle.opacity = diveT
    this.hubGlyph.opacity = diveT
    this.hubRest.opacity = 1 - diveT
    this.plane.move(
      this.holdArc,
      Math.round(centerX - HOLD_ARC_SIZE / 2),
      Math.round(centerY - HOLD_ARC_SIZE / 2),
    )

    RING.forEach((slotId, index) => {
      const slot = this.slots[slotId]
      let radius = theme.RING_RADIUS * openT
      if (slotId === this.focused) radius *= 1 - diveT
      else radius += diveT * theme.RING_DIVE_PUSH
      slot.card.opacity = 1 - diveT
      // 0° is the right of the ring; pills go clockwise from there.
      const thetaRad = ((90 * index + angle) * Math.PI) / 180
      const x = centerX + radius * Math.cos(thetaRad) - theme.SLOT_WIDTH / 2
      const y = centerY + radius * Math.sin(thetaRad) - theme.SLOT_HEIGHT / 2
      // No scale on ring pills: the front pill drawn through a scale
      // transform rendered with its top edge cut off; focus is shown by
      // the border and glow instead.
      this.plane.move(slot.card, Math.round(x), Math.round(y))
    })

    const count = focused.subItems.length
    focused.subItems.forEach((item, index) => {
      // Static centered fan on the right: symmetric about the horizontal
      // axis, fixed gap per item; later items lag the fan-out slightly.
      const offset = index - (count - 1) / 2
      const thetaRad = (offset * theme.SUB_GAP_DEG * Math.PI) / 180
      const lag = index * theme.SUB_STAGGER
      const progress = Math.max(0, Math.min(1, (diveT - lag) / (1 - lag)))
      const radius = theme.RING_RADIUS * progress
      const x = centerX + radius * Math.cos(thetaRad) - theme.SUB_WIDTH / 2
      const y = centerY + radius * Math.sin(thetaRad) - theme.SUB_HEIGHT / 2
      // Selected pill grows about its center (same GPU transform as the
      // ring swell), following its scale tween.
      const grow = this.tweens.values[this.subScaleName(this.focused, index)]
      const scale = 1 + (theme.SUB_SELECT_SCALE - 1) * grow
      const transform = new Gsk.Transform()
        .translate(
          new Graphene.Point({
            x: x + (theme.SUB_WIDTH * (1 - scale)) / 2,
            y: y + (theme.SUB_HEIGHT * (1 - scale)) / 2,
          }),
        )
        ?.scale(scale, scale)
      if (transform) this.plane.set_child_transform(item.widget, transform)
      item.widget.opacity = progress
    })

    // Short slide-in with the dive; GTK4 renders this on the GPU, so the
    // per-frame move the GTK3 version had to avoid is free here.
    const panelX =
      width / 2 - fullPan + ringReach + theme.DETAILS_GAP + (1 - diveT) * 24
    const panelY = centerY - panelHeight / 2
    this.plane.move(focused.details, Math.round(panelX), Math.round(panelY))
    focused.details.opacity = diveT
    // The filter/password field caps the panel, same width, just above it.
    this.commandBar.set_size_request(panelWidth, -1)
    this.plane.move(
      this.commandBar,
      Math.round(panelX),
      Math.round(panelY - COMMAND_BAR_HEIGHT - 10),
    )
    this.commandBar.opacity = diveT
  }

  // ── chrome / modes ──

  private renderChrome() {
    const inTextMode = this.mode === "filter" || this.mode === "wifi-pass"
    this.commandBar.visible = inTextMode
    this.prompt.label = this.mode === "wifi-pass" ? "pw" : "/"
    if (inTextMode) {
      this.entry.visibility = this.mode !== "wifi-pass"
      this.entry.grab_focus()
      this.entry.set_position(-1)
    } else {
      this.window.set_focus(null)
    }
  }

  private enterFilter() {
    if (!this.dived || !this.panes[this.focused].applyFilter) return
    this.mode = "filter"
    this.renderChrome()
  }

  beginWifiPassword(ssid: string) {
    this.wifiSsid = ssid
    this.mode = "wifi-pass"
    this.entry.text = ""
    this.renderChrome()
  }

  private backToNormal() {
    const wasFilter = this.mode === "filter"
    this.mode = "normal"
    this.wifiSsid = ""
    const hadText = this.entry.text !== ""
    this.entry.text = ""
    if (wasFilter && hadText) this.panes[this.focused].applyFilter?.("")
    this.renderChrome()
  }

  private handleEscape() {
    if (this.powerPane.holdActive()) {
      this.powerPane.cancelHold()
      return
    }
    if (this.mode !== "normal") {
      this.backToNormal()
      return
    }
    if (this.dived) {
      // A confirmed filter clears first (vim's :noh), then Escape undives.
      if (this.entry.text !== "") {
        this.resetFilter()
        return
      }
      this.undive()
      return
    }
    this.requestClose()
  }

  private accept(keyval: number) {
    if (!this.dived) {
      this.dive()
      return
    }
    this.panes[this.focused].accept(keyval)
  }

  // ── input ──

  isDived(): boolean {
    return this.dived
  }

  // IPC surface (ags request): jump into a pane / drive the filter, so the
  // overlay is scriptable and debuggable without key injection.
  ipcDive(pane: string): boolean {
    if (!RING.includes(pane as SlotId)) return false
    if (!this.window.visible) this.open()
    this.focused = pane as SlotId
    this.dive()
    return true
  }

  ipcMove(direction: string): boolean {
    if (!this.dived) return false
    const dx = direction === "h" ? -1 : direction === "l" ? 1 : 0
    const dy = direction === "k" ? -1 : direction === "j" ? 1 : 0
    this.panes[this.focused].move(dx, dy)
    return true
  }

  // Feed a key through the real handler (drives this app only; useful for
  // scripted repros without compositor-level input injection).
  ipcKey(name: string): boolean {
    const keyvals: Record<string, number> = {
      escape: Gdk.KEY_Escape,
      enter: Gdk.KEY_Return,
      slash: Gdk.KEY_slash,
    }
    let keyval = keyvals[name.toLowerCase()]
    // Any single letter or digit maps straight to its keyval.
    if (keyval === undefined && /^[a-zA-Z0-9]$/.test(name)) {
      keyval = name.charCodeAt(0)
    }
    if (keyval === undefined) return false
    // Scripted keys never reach the power pane: a single IPC key there
    // is lock/suspend/logout, and a press without a release started a
    // hold that shut the machine down once (2026-09-08).
    if (this.dived && this.focused === "power") return false
    this.onKeyPressed(keyval, 0)
    this.onKeyReleased(keyval)
    return true
  }

  ipcFrames(): string {
    const gaps = [...this.tweens.frameGapsMs].sort((a, b) => a - b)
    this.tweens.frameGapsMs = []
    if (gaps.length === 0) return "no frames recorded"
    const median = gaps[Math.floor(gaps.length / 2)]
    const over25 = gaps.filter((gap) => gap > 25).length
    return `frames=${gaps.length} min=${gaps[0].toFixed(1)} median=${median.toFixed(1)} max=${gaps[gaps.length - 1].toFixed(1)} over25ms=${over25}`
  }

  ipcState(): string {
    return JSON.stringify({
      focused: this.focused,
      dived: this.dived,
      mode: this.mode,
      tweens: this.tweens.values,
    })
  }

  ipcFilter(text: string): string {
    if (!this.dived) return "not dived"
    this.enterFilter()
    if (this.mode !== "filter") return "pane has no filter"
    this.entry.text = text
    return "ok"
  }

  tintPanel(pane: Pane, colorHex: string | null) {
    for (const slotId of RING) {
      if (this.panes[slotId] !== pane) continue
      const fill = colorHex
        ? colors.mixOnto(colorHex, colors.surface, 0.3)
        : colors.surface
      setWidgetCss(
        this.slots[slotId].details,
        `.panel { background-color: ${fill}; }`,
      )
    }
  }

  setHoldProgress(progress: number, colorHex?: string) {
    this.holdProgress = progress
    if (colorHex) this.holdColor = colorHex
    this.holdArc.visible = progress > 0
    this.holdArc.queue_draw()
  }

  private onScrimClick(x: number, y: number) {
    if (!this.window.visible) return
    // Only clicks on the bare scrim count; clicks on pills, rows, or the
    // command bar were meant for those widgets.
    let picked = this.window.pick(x, y, Gtk.PickFlags.DEFAULT)
    while (picked !== null) {
      if (
        picked.has_css_class("pill") ||
        picked.get_css_name() === "command-bar"
      ) {
        return
      }
      picked = picked.get_parent()
    }
    if (this.powerPane.holdActive()) {
      this.powerPane.cancelHold()
      return
    }
    if (this.mode !== "normal") this.backToNormal()
    else if (this.dived) this.undive()
    else this.requestClose()
  }

  private onScroll(dy: number): boolean {
    if (this.dived || this.mode !== "normal") return false
    if (dy < 0) this.rotateRing(-1)
    else if (dy > 0) this.rotateRing(1)
    return true
  }

  // Lowercase letter or digit for a keyval; "" for anything else.
  private letterOf(keyval: number): string {
    if (keyval >= Gdk.KEY_a && keyval <= Gdk.KEY_z) {
      return String.fromCharCode(keyval)
    }
    if (keyval >= Gdk.KEY_A && keyval <= Gdk.KEY_Z) {
      return String.fromCharCode(keyval + 32)
    }
    if (keyval >= Gdk.KEY_0 && keyval <= Gdk.KEY_9) {
      return String.fromCharCode(keyval)
    }
    return ""
  }

  private onKeyPressed(keyval: number, state: number): boolean {
    if (!this.window.visible) return false
    const nowMs = GLib.get_monotonic_time() / 1000
    if (nowMs < this.openedMs + theme.OPEN_GUARD_MS) return true
    if (this.powerPane.holdActive()) {
      if (keyval === this.powerPane.holdKeyval) return true
      if (keyval !== Gdk.KEY_Escape) this.powerPane.cancelHold()
    }

    const ctrl = (state & Gdk.ModifierType.CONTROL_MASK) !== 0
    if (keyval === Gdk.KEY_Escape || (ctrl && keyval === Gdk.KEY_bracketleft)) {
      this.handleEscape()
      return true
    }
    // Ctrl-n / Ctrl-p walk the list in every mode, vim-completion style.
    if (ctrl && (keyval === Gdk.KEY_n || keyval === Gdk.KEY_p)) {
      if (this.dived) {
        this.panes[this.focused].move(0, keyval === Gdk.KEY_n ? 1 : -1)
      }
      return true
    }

    // Text modes: intercept a small allowlist and let everything else fall
    // through to the focused Entry — typed letters can never be eaten as
    // navigation.
    if (this.mode === "filter" || this.mode === "wifi-pass") {
      if (keyval === Gdk.KEY_Return || keyval === Gdk.KEY_KP_Enter) {
        if (this.mode === "wifi-pass") {
          this.networkPane.connectWifi(this.wifiSsid, this.entry.text)
          this.backToNormal()
        } else {
          // vim's `/`: Enter confirms the filter and returns to list
          // navigation; the narrowed list stays until Escape clears it.
          this.mode = "normal"
          this.renderChrome()
        }
        return true
      }
      if (this.mode === "filter" && keyval === Gdk.KEY_Down) {
        this.panes[this.focused].move(0, 1)
        return true
      }
      if (this.mode === "filter" && keyval === Gdk.KEY_Up) {
        this.panes[this.focused].move(0, -1)
        return true
      }
      if (ctrl && keyval === Gdk.KEY_u) {
        this.entry.text = ""
        return true
      }
      if (ctrl && keyval === Gdk.KEY_w) {
        const text = this.entry.text.trimEnd()
        this.entry.text = text.includes(" ")
          ? text.slice(0, text.lastIndexOf(" "))
          : ""
        this.entry.set_position(-1)
        return true
      }
      return false
    }

    if (keyval === Gdk.KEY_slash) {
      this.enterFilter()
      return true
    }
    if (keyval === Gdk.KEY_Return || keyval === Gdk.KEY_KP_Enter) {
      this.accept(keyval)
      return true
    }

    // Inside a pane, its own letters outrank hjkl movement: in power,
    // `l` means Lock, not "move right". Arrows always mean movement.
    if (this.dived) {
      const paneLetter = this.letterOf(keyval)
      if (
        paneLetter !== "" &&
        this.panes[this.focused].onLetter?.(paneLetter, keyval)
      ) {
        return true
      }
    }

    const directions: Record<number, [number, number]> = {
      [Gdk.KEY_h]: [-1, 0],
      [Gdk.KEY_H]: [-1, 0],
      [Gdk.KEY_Left]: [-1, 0],
      [Gdk.KEY_l]: [1, 0],
      [Gdk.KEY_L]: [1, 0],
      [Gdk.KEY_Right]: [1, 0],
      [Gdk.KEY_j]: [0, 1],
      [Gdk.KEY_J]: [0, 1],
      [Gdk.KEY_Down]: [0, 1],
      [Gdk.KEY_k]: [0, -1],
      [Gdk.KEY_K]: [0, -1],
      [Gdk.KEY_Up]: [0, -1],
    }
    const direction = directions[keyval]
    if (direction !== undefined) {
      const [dx, dy] = direction
      if (this.dived) this.panes[this.focused].move(dx, dy)
      else if (dx < 0) this.rotateRing(-1)
      else if (dx > 0) this.rotateRing(1)
      else if (dy > 0) this.dive()
      return true
    }

    if (keyval === Gdk.KEY_G) {
      if (this.dived) this.panes[this.focused].jump(true)
      return true
    }
    if (keyval === Gdk.KEY_g) {
      // vim "gg": two bare g presses in a row jump to the first entry.
      if (this.pendingG) {
        this.pendingG = false
        if (this.dived) this.panes[this.focused].jump(false)
      } else {
        this.pendingG = true
      }
      return true
    }
    this.pendingG = false

    const letter = this.letterOf(keyval)
    if (letter === "") return true

    if (letter === "q" && !this.dived) {
      this.requestClose()
      return true
    }
    // Layered keys: s/w/n/p dive only from the ring; inside a pane the
    // letters belong to that pane (already dispatched above).
    if (!this.dived && letter in PREFIX) {
      this.resetFilter()
      this.focused = PREFIX[letter]
      this.dive()
    }
    return true
  }

  private onKeyReleased(keyval: number) {
    if (this.powerPane.holdActive() && keyval === this.powerPane.holdKeyval) {
      this.powerPane.cancelHold()
    }
  }
}
