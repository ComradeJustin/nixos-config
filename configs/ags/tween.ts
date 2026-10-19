// Frame-synced tween engine for the ring overlay. One tick callback on the
// window drives every named value and calls the layout function exactly once
// per display frame — refresh-rate agnostic (60Hz today, 240Hz later).
// Neither gnim nor Astal ships a tween utility; Adw.TimedAnimation exists but
// coordinating five of them plus a settled callback was messier than this.
import Gtk from "gi://Gtk?version=4.0"

export function easeOutCubic(t: number): number {
  return 1 - Math.pow(1 - t, 3)
}

// Underdamped spring normalized to settle at 1 by t=1, like niri's spring
// animations. zeta = damping ratio (<1 oscillates), omega = stiffness-ish;
// the defaults overshoot ~7% once and settle.
export function spring(zeta = 0.65, omega = 13): (t: number) => number {
  const omegaDamped = omega * Math.sqrt(1 - zeta * zeta)
  return (t) =>
    1 -
    Math.exp(-zeta * omega * t) *
      (Math.cos(omegaDamped * t) +
        ((zeta * omega) / omegaDamped) * Math.sin(omegaDamped * t))
}

type Easing = (t: number) => number

interface Running {
  from: number
  to: number
  startUs: number
  durationUs: number
  ease: Easing
}

// A live spring: unlike a timed tween it carries velocity, so retargeting
// mid-flight (h h h on the ring) flows instead of restarting from rest.
interface Spring {
  target: number
  velocity: number
  stiffness: number
  damping: number
}

export class Tweens {
  values: Record<string, number>
  private running = new Map<string, Running>()
  private springs = new Map<string, Spring>()
  private tickId = 0
  private widget: Gtk.Widget
  private layout: () => void
  onSettled: (() => void) | null = null

  constructor(widget: Gtk.Widget, names: string[], layout: () => void) {
    this.widget = widget
    this.layout = layout
    this.values = Object.fromEntries(names.map((name) => [name, 0]))
  }

  animate(name: string, to: number, durationMs: number, ease: Easing) {
    this.running.set(name, {
      from: this.values[name],
      to,
      startUs: 0,
      durationUs: durationMs * 1000,
      ease,
    })
    this.springs.delete(name)
    this.startTicking()
  }

  // zeta = damping ratio (<1 overshoots), omega = angular frequency in
  // rad/s; settle time is roughly 4 / (zeta * omega) seconds.
  springTo(name: string, target: number, zeta: number, omega: number) {
    this.running.delete(name)
    const previous = this.springs.get(name)
    this.springs.set(name, {
      target,
      velocity: previous?.velocity ?? 0,
      stiffness: omega * omega,
      damping: 2 * zeta * omega,
    })
    this.startTicking()
  }

  private startTicking() {
    if (this.tickId !== 0) return
    this.tickId = this.widget.add_tick_callback((_w, clock) =>
      this.tick(clock.get_frame_time()),
    )
  }

  snap(name: string, value: number) {
    this.running.delete(name)
    this.springs.delete(name)
    this.values[name] = value
  }

  reset() {
    this.running.clear()
    this.springs.clear()
    this.onSettled = null
    for (const name of Object.keys(this.values)) this.values[name] = 0
  }

  // Frame-clock intervals of the last animation run, for `ags request
  // frames`: the ground truth for whether motion is actually smooth.
  frameGapsMs: number[] = []
  private lastTickUs = 0

  private tick(nowUs: number): boolean {
    // Elapsed seconds since the last frame, capped so a stalled frame
    // cannot fling a spring past its target.
    let dt = 0
    if (this.lastTickUs !== 0) {
      this.frameGapsMs.push((nowUs - this.lastTickUs) / 1000)
      if (this.frameGapsMs.length > 240) this.frameGapsMs.shift()
      dt = Math.min(0.05, (nowUs - this.lastTickUs) / 1_000_000)
    }
    this.lastTickUs = nowUs
    for (const [name, spring] of this.springs) {
      const offset = this.values[name] - spring.target
      const acceleration =
        -spring.stiffness * offset - spring.damping * spring.velocity
      spring.velocity += acceleration * dt
      this.values[name] += spring.velocity * dt
      const atRest =
        Math.abs(this.values[name] - spring.target) < 0.02 &&
        Math.abs(spring.velocity) < 0.5
      if (atRest) {
        this.values[name] = spring.target
        this.springs.delete(name)
      }
    }
    const finished: string[] = []
    for (const [name, tween] of this.running) {
      if (tween.startUs === 0) tween.startUs = nowUs
      const progress = Math.min(1, (nowUs - tween.startUs) / tween.durationUs)
      this.values[name] =
        tween.from + (tween.to - tween.from) * tween.ease(progress)
      if (progress >= 1) finished.push(name)
    }
    for (const name of finished) this.running.delete(name)
    this.layout()
    if (this.running.size > 0 || this.springs.size > 0) return true
    this.tickId = 0
    this.lastTickUs = 0
    const settled = this.onSettled
    this.onSettled = null
    settled?.()
    return false
  }
}
