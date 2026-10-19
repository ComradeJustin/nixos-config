// Power pane: session actions on the fan. Lock/suspend/logout fire on
// accept; reboot and shutdown need a 2-second hold, drawn as an arc
// closing around the hub (shell.setHoldProgress).
import { Gtk } from "ags/gtk4"
import { execAsync } from "ags/process"
import GLib from "gi://GLib"
import * as colors from "../colors"
import * as theme from "../theme"
import {
  Hint,
  Pane,
  Shell,
  SubItem,
  detailRule,
  headerLabel,
  setSelected,
  setWidgetCss,
  subPill,
} from "./common"

interface Action {
  key: string
  id: string
  label: string
  description: string
  icon: string
  // Same per-action colors as the quickshell Mod+Esc powermenu.
  color: string
  command: string[]
  hold: boolean
}

const ACTIONS: Action[] = [
  {
    key: "l",
    id: "lock",
    description: "Lock the session",
    color: colors.accentPurple,
    label: "Lock",
    icon: "system-lock-screen-symbolic",
    command: ["loginctl", "lock-session"],
    hold: false,
  },
  {
    key: "u",
    id: "suspend",
    description: "Sleep to RAM",
    color: colors.accentWarning,
    label: "Suspend",
    icon: "media-playback-pause-symbolic",
    command: ["systemctl", "suspend"],
    hold: false,
  },
  {
    key: "o",
    id: "logout",
    description: "End the niri session",
    color: colors.accent,
    label: "Logout",
    icon: "system-log-out-symbolic",
    command: ["niri", "msg", "action", "quit"],
    hold: false,
  },
  {
    key: "r",
    id: "reboot",
    description: "Hold 2 seconds to restart",
    color: colors.accentWarm,
    label: "Reboot",
    icon: "system-reboot-symbolic",
    command: ["systemctl", "reboot"],
    hold: true,
  },
  {
    key: "d",
    id: "shutdown",
    description: "Hold 2 seconds to power off",
    color: colors.accentDanger,
    label: "Shutdown",
    icon: "system-shutdown-symbolic",
    command: ["systemctl", "poweroff"],
    hold: true,
  },
]

export class PowerPane implements Pane {
  hints: Hint[] = [
    ["↵", "run"],
    ["r d", "hold 2 s"],
    ["esc", "back"],
  ]
  private shell: Shell
  private index = 0
  private subs: SubItem[] = []
  private header!: Gtk.Label
  private description!: Gtk.Label
  private batteryRow!: Gtk.Box
  private batteryLabel!: Gtk.Label
  private uptimeLabel!: Gtk.Label
  private card!: Gtk.Widget
  private holdTimer = 0
  private holdIndex = -1
  private holdStartedUs = 0
  // The keyval that started the hold; releasing it cancels. The overlay
  // reads this to swallow key repeats.
  holdKeyval = 0

  constructor(shell: Shell) {
    this.shell = shell
  }

  detailsSize(): [number, number] {
    return [theme.DETAILS_WIDTH, theme.DETAILS_POWER_HEIGHT]
  }

  summary(): string {
    const capacity = readSysFile("/sys/class/power_supply/BAT0/capacity")
    const uptime = readSysFile("/proc/uptime")
    const parts: string[] = []
    if (capacity !== null) parts.push(`${capacity}%`)
    if (uptime !== null) {
      parts.push(`up ${Math.floor(parseFloat(uptime) / 3600)}h`)
    }
    return parts.join(" · ")
  }

  buildSubs(): SubItem[] {
    this.subs = ACTIONS.map((action, index) =>
      subPill(
        action.key,
        action.label,
        action.icon,
        () => this.onPointerPress(index),
        () => this.onPointerRelease(),
        action.color,
      ),
    )
    return this.subs
  }

  buildDetails(): Gtk.Widget {
    // A status card: what the selected action does, plus the session facts
    // worth glancing at before you act on it.
    this.card = (
      <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
        {(this.header = headerLabel("Lock"))}
        {detailRule()}
        <label
          $={(ref: Gtk.Label) => (this.description = ref)}
          class="detail-status"
          halign={Gtk.Align.START}
        />
        <box
          $={(ref: Gtk.Box) => (this.batteryRow = ref)}
          class="status-row"
          spacing={10}
          visible={false}
        >
          <image class="status-icon" iconName="battery-symbolic" />
          <label
            $={(ref: Gtk.Label) => (this.batteryLabel = ref)}
            class="status-text"
          />
        </box>
        <box class="status-row" spacing={10}>
          <image class="status-icon" iconName="alarm-symbolic" />
          <label
            $={(ref: Gtk.Label) => (this.uptimeLabel = ref)}
            class="status-text"
          />
        </box>
      </box>
    ) as Gtk.Widget
    return this.card
  }

  ensure() {
    this.index = 0
    this.highlight()
    this.refreshStatus()
    // Keep the facts fresh while the card is on screen.
    GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 5, () => {
      if (!this.card.get_mapped()) return GLib.SOURCE_REMOVE
      this.refreshStatus()
      return GLib.SOURCE_CONTINUE
    })
  }

  // Battery from sysfs (works without a battery service; hidden on
  // machines without one) and uptime from /proc.
  private refreshStatus() {
    const capacity = readSysFile("/sys/class/power_supply/BAT0/capacity")
    const state = readSysFile("/sys/class/power_supply/BAT0/status")
    if (capacity === null) {
      this.batteryRow.visible = false
    } else {
      this.batteryRow.visible = true
      this.batteryLabel.label = `${capacity}% · ${state?.toLowerCase() ?? "battery"}`
    }
    const uptime = readSysFile("/proc/uptime")
    if (uptime !== null) {
      const totalMinutes = Math.floor(parseFloat(uptime) / 60)
      const hours = Math.floor(totalMinutes / 60)
      const minutes = totalMinutes % 60
      this.uptimeLabel.label =
        hours > 0 ? `up ${hours}h ${minutes}m` : `up ${minutes}m`
    }
  }

  private highlight() {
    ACTIONS.forEach((action, position) => {
      const item = this.subs[position]
      const selected = position === this.index
      setSelected(item.body, selected)
      if (selected) item.dot.add_css_class("on")
      else item.dot.remove_css_class("on")
    })
    const action = ACTIONS[this.index]
    this.header.label = action.label
    this.description.label = action.description
  }

  // Pointer path: press selects and activates (starting a hold for
  // reboot/shutdown, keyval 0 marks it pointer-started); release cancels
  // a pointer-started hold, mirroring key release for keyboard holds.
  private onPointerPress(index: number) {
    this.index = index
    this.highlight()
    this.activate(index, 0)
  }

  private onPointerRelease() {
    if (this.holdActive() && this.holdKeyval === 0) this.cancelHold()
  }

  holdActive(): boolean {
    return this.holdTimer !== 0
  }

  cancelHold() {
    if (this.holdTimer !== 0) {
      GLib.source_remove(this.holdTimer)
      this.holdTimer = 0
    }
    this.shell.setHoldProgress(0)
    if (this.holdIndex >= 0) this.fillHeldPill(0)
    this.holdIndex = -1
    this.holdKeyval = 0
  }

  // The held pill fills left-to-right with its action color as the hold
  // progresses, alongside the arc around the hub.
  private fillHeldPill(progress: number) {
    const item = this.subs[this.holdIndex]
    const percent = Math.round(progress * 100)
    const fillColor = colors.rgba(ACTIONS[this.holdIndex].color, 0.35)
    const css =
      progress > 0
        ? `.sub { background-image: linear-gradient(to right, ${fillColor} ${percent}%, transparent ${percent}%); }`
        : `.sub { background-image: none; }`
    setWidgetCss(item.body, css)
  }

  private beginHold(index: number, keyval: number) {
    this.cancelHold()
    this.holdIndex = index
    this.holdKeyval = keyval
    this.holdStartedUs = GLib.get_monotonic_time()
    this.holdTimer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 16, () => {
      const elapsedMs = (GLib.get_monotonic_time() - this.holdStartedUs) / 1000
      const progress = Math.min(1, elapsedMs / theme.HOLD_MS)
      this.shell.setHoldProgress(progress, ACTIONS[this.holdIndex].color)
      this.fillHeldPill(progress)
      if (progress < 1) return true
      const action = ACTIONS[this.holdIndex]
      this.holdTimer = 0
      this.cancelHold()
      this.run(action)
      return false
    })
  }

  private run(action: Action) {
    execAsync(action.command).catch(console.error)
    this.shell.requestClose()
  }

  private activate(index: number, keyval: number) {
    const action = ACTIONS[index]
    if (action.hold) {
      this.beginHold(index, keyval)
      return
    }
    this.run(action)
  }

  move(dx: number, dy: number) {
    const step = dx !== 0 ? dx : dy
    this.index = (this.index + step + ACTIONS.length) % ACTIONS.length
    this.highlight()
  }

  jump(toEnd: boolean) {
    this.index = toEnd ? ACTIONS.length - 1 : 0
    this.highlight()
  }

  accept(keyval: number) {
    this.activate(this.index, keyval)
  }

  onLetter(letter: string, keyval: number): boolean {
    const index = ACTIONS.findIndex((action) => action.key === letter)
    if (index < 0) return false
    this.index = index
    this.highlight()
    this.activate(index, keyval)
    return true
  }
}

function readSysFile(path: string): string | null {
  try {
    const [ok, bytes] = GLib.file_get_contents(path)
    if (!ok) return null
    return new TextDecoder().decode(bytes).trim()
  } catch {
    return null
  }
}
