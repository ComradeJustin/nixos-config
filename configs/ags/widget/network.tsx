// Network pane: wifi / bluetooth / volume / output sub-modes on the fan,
// backed by Astal's NetworkManager, BlueZ and WirePlumber services. The
// wifi/bluetooth/output lists render through the shared FilterList; volume
// keeps a persistent mute button + slider that track the live speaker.
import { createRoot } from "ags"
import { Gtk } from "ags/gtk4"
import AstalBluetooth from "gi://AstalBluetooth"
import AstalNetwork from "gi://AstalNetwork"
import AstalWp from "gi://AstalWp"
import Pango from "gi://Pango"
import * as theme from "../theme"
import {
  Hint,
  Pane,
  Shell,
  SubItem,
  detailRule,
  headerLabel,
  setSelected,
  setSubtitle,
  subPill,
} from "./common"
import { FilterList, ListItem } from "./list"

interface Sub {
  key: string
  id: string
  label: string
  icon: string
}

const SUBS: Sub[] = [
  { key: "i", id: "wifi", label: "Wi-Fi", icon: "network-wireless-symbolic" },
  { key: "b", id: "bluetooth", label: "Bluetooth", icon: "bluetooth-symbolic" },
  {
    key: "a",
    id: "volume",
    label: "Volume",
    icon: "audio-volume-high-symbolic",
  },
  {
    key: "o",
    id: "output",
    label: "Output",
    icon: "audio-headphones-symbolic",
  },
]

export class NetworkPane implements Pane {
  hints: Hint[] = [
    ["h l", "section"],
    ["↵", "select"],
    ["/", "filter"],
  ]
  private shell: Shell
  private sub = "wifi"
  private subItems: SubItem[] = []
  private header!: Gtk.Label
  private list = new FilterList({ height: 244, emptyText: "Nothing found" })
  private volumeBox!: Gtk.Box
  private muteLabel!: Gtk.Label
  private volumeSlider!: Gtk.Scale
  private volumeText!: Gtk.Label
  private mixerBox!: Gtk.Box
  // Stream ids the mixer rows were last built for; null = never built.
  private mixerIds: string | null = null
  // Tears down the current mixer rows and their gnim scope (see syncMixer).
  private disposeMixer: () => void = () => {}
  private network = AstalNetwork.get_default()
  private bluetooth = AstalBluetooth.get_default()
  private audio = AstalWp.get_default()?.audio ?? null
  private watchedSpeaker: AstalWp.Endpoint | null = null
  private speakerSignals: number[] = []

  constructor(shell: Shell) {
    this.shell = shell
    // WirePlumber endpoints appear asynchronously after startup; refresh
    // when the default speaker (dis)appears so the volume page comes alive
    // without leaving and re-entering it.
    this.audio?.connect("notify::default-speaker", () => this.refresh())
    this.audio?.connect("notify::streams", () => {
      if (this.sub === "volume" && this.volumeBox.get_mapped()) this.refresh()
    })
    // The wifi device may also appear late; once it exists, follow scan
    // results live so networks show up as they are found.
    this.network.connect("notify::wifi", () => this.hookWifi())
    this.hookWifi()
  }

  private hookedWifi: AstalNetwork.Wifi | null = null

  private hookWifi() {
    const wifi = this.network.wifi
    if (!wifi || this.hookedWifi === wifi) return
    this.hookedWifi = wifi
    const refreshIfWifi = () => {
      // Only while the wifi list is actually on screen; scans keep firing
      // while the overlay is closed and rebuilding a hidden list is waste.
      if (this.sub === "wifi" && this.list.widget.get_mapped()) this.refresh()
    }
    wifi.connect("notify::access-points", refreshIfWifi)
    wifi.connect("notify::enabled", refreshIfWifi)
    wifi.connect("notify::active-access-point", refreshIfWifi)
  }

  detailsSize(): [number, number] {
    return [theme.DETAILS_WIDTH, theme.DETAILS_SETTINGS_HEIGHT]
  }

  summary(): string {
    const wifi = this.network.wifi
    if (!wifi || !wifi.enabled) return "wifi off"
    const point = wifi.activeAccessPoint
    if (!point || !point.ssid) return "not connected"
    return `${point.ssid} · ${point.strength}%`
  }

  buildSubs(): SubItem[] {
    this.subItems = SUBS.map((spec) =>
      subPill(spec.key, spec.label, spec.icon, () => this.setSub(spec.id)),
    )
    return this.subItems
  }

  buildDetails(): Gtk.Widget {
    this.volumeBox = (
      <box orientation={Gtk.Orientation.VERTICAL} spacing={8} visible={false}>
        <button
          class="action"
          onClicked={() => {
            const speaker = this.audio?.defaultSpeaker
            if (speaker) speaker.mute = !speaker.mute
          }}
        >
          <label
            $={(ref: Gtk.Label) => (this.muteLabel = ref)}
            class="action-label"
            label="Mute"
            halign={Gtk.Align.START}
            hexpand
          />
        </button>
        <label
          $={(ref: Gtk.Label) => (this.volumeText = ref)}
          class="mute"
          label=""
          halign={Gtk.Align.START}
        />
        <Gtk.Scale
          $={(ref: Gtk.Scale) => (this.volumeSlider = ref)}
          hexpand
          drawValue={false}
          adjustment={
            new Gtk.Adjustment({
              lower: 0,
              upper: 100,
              value: 0,
              stepIncrement: 5,
            })
          }
          onValueChanged={(scale: Gtk.Scale) => {
            const speaker = this.audio?.defaultSpeaker
            if (!speaker) return
            const next = scale.get_value() / 100
            if (Math.abs(next - speaker.volume) > 0.005) speaker.volume = next
          }}
        />
        <label class="mixer-h" label="Apps" halign={Gtk.Align.START} />
        <box
          $={(ref: Gtk.Box) => (this.mixerBox = ref)}
          orientation={Gtk.Orientation.VERTICAL}
          spacing={6}
        />
      </box>
    ) as Gtk.Box
    return (
      <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
        {(this.header = headerLabel("Wi-Fi"))}
        {detailRule()}
        {this.list.widget}
        {this.volumeBox}
      </box>
    ) as Gtk.Widget
  }

  ensure() {
    this.setSub(this.sub)
  }

  private setSub(subId: string) {
    this.sub = subId
    this.header.label =
      SUBS.find((spec) => spec.id === subId)?.label ?? "Network"
    SUBS.forEach((spec, position) => {
      const item = this.subItems[position]
      setSelected(item.body, spec.id === subId)
      if (spec.id === subId) item.dot.add_css_class("on")
      else item.dot.remove_css_class("on")
    })
    if (subId === "wifi") this.network.wifi?.scan()
    this.refresh()
  }

  // Live status under each fan pill, so nothing needs a dive just to
  // be looked at.
  private refreshFanSubtitles() {
    const connectedDevices = this.bluetooth.devices.filter(
      (device) => device.connected,
    ).length
    let bluetoothText = "off"
    if (this.bluetooth.isPowered) {
      bluetoothText =
        connectedDevices > 0 ? `${connectedDevices} connected` : "on"
    }
    const speaker = this.audio?.defaultSpeaker ?? null
    let volumeText = ""
    let outputText = ""
    if (speaker && this.audio?.speakers) {
      volumeText = speaker.mute
        ? "muted"
        : `${Math.round(speaker.volume * 100)}%`
      const { names } = this.speakerNames(this.audio.speakers)
      const index = this.audio.speakers.findIndex(
        (candidate) => candidate.id === speaker.id,
      )
      outputText = names[index] ?? ""
    }
    setSubtitle(this.subItems[0], this.summary())
    setSubtitle(this.subItems[1], bluetoothText)
    setSubtitle(this.subItems[2], volumeText)
    setSubtitle(this.subItems[3], outputText)
  }

  private refresh() {
    if (!this.header) return // details not built yet
    this.refreshFanSubtitles()
    const inVolume = this.sub === "volume"
    this.list.widget.visible = !inVolume
    this.volumeBox.visible = inVolume
    if (inVolume) {
      this.syncVolume()
      return
    }
    if (this.sub === "wifi") this.list.update(this.wifiItems())
    else if (this.sub === "bluetooth") this.list.update(this.bluetoothItems())
    else this.list.update(this.outputItems())
  }

  private refreshSoon(delayMs: number) {
    setTimeout(() => this.refresh(), delayMs)
  }

  private wifiItems(): ListItem[] {
    const wifi = this.network.wifi
    if (!wifi) return []
    const items: ListItem[] = [
      {
        key: "wifi-toggle",
        label: wifi.enabled ? "Disable Wi-Fi" : "Enable Wi-Fi",
        activate: () => {
          wifi.enabled = !wifi.enabled
          this.refreshSoon(600)
        },
      },
    ]
    if (!wifi.enabled) return items
    // SSIDs NetworkManager already has a profile for (saved credentials).
    // Read from the connection list rather than per-AP filtering, which
    // trips a libnm assertion on every refresh.
    const savedSsids = new Set<string>()
    for (const connection of this.network.client.get_connections()) {
      const ssidBytes = connection.get_setting_wireless()?.get_ssid()
      if (ssidBytes) {
        savedSsids.add(
          new TextDecoder().decode(ssidBytes.get_data() ?? new Uint8Array()),
        )
      }
    }
    const seen = new Set<string>()
    const points = wifi.accessPoints
      .filter((ap) => {
        if (!ap.ssid || seen.has(ap.ssid)) return false
        seen.add(ap.ssid)
        return true
      })
      .sort((a, b) => b.strength - a.strength)
    for (const ap of points) {
      const active = wifi.activeAccessPoint?.ssid === ap.ssid
      const saved = ap.ssid !== null && savedSsids.has(ap.ssid)
      const notes = [
        `${ap.strength}%`,
        ap.requiresPassword ? (saved ? "saved" : "secured") : "open",
        active ? "connected" : "",
      ].filter((note) => note !== "")
      items.push({
        // Strength is bucketed in the key so rows are rebuilt only on real
        // signal changes, not every scan tick (which was resetting the
        // selection while browsing).
        key: `${ap.ssid}:${Math.round(ap.strength / 25)}:${active}`,
        label: ap.ssid ?? "",
        sublabel: notes.join(" · "),
        iconName: ap.iconName,
        activate: () => {
          if (ap.requiresPassword && !active && !saved) {
            this.shell.beginWifiPassword(ap.ssid ?? "")
          } else {
            ap.activate(null, null)
          }
        },
      })
    }
    return items
  }

  connectWifi(ssid: string, password: string) {
    const wifi = this.network.wifi
    const point = wifi?.accessPoints.find((ap) => ap.ssid === ssid)
    point?.activate(password, null)
  }

  private bluetoothItems(): ListItem[] {
    const bt = this.bluetooth
    const adapter = bt.adapter
    if (!adapter) return []
    const items: ListItem[] = [
      {
        key: "bt-toggle",
        label: bt.isPowered ? "Disable Bluetooth" : "Enable Bluetooth",
        activate: () => {
          bt.toggle()
          this.refreshSoon(400)
        },
      },
      {
        key: `bt-scan:${adapter.discovering}`,
        label: adapter.discovering ? "Stop scan" : "Scan",
        activate: () => {
          if (adapter.discovering) adapter.stop_discovery()
          else adapter.start_discovery()
          this.refreshSoon(400)
        },
      },
    ]
    for (const device of bt.devices) {
      const status = device.connected
        ? "connected"
        : device.paired
          ? "paired"
          : "available"
      const notes = [status]
      // -1 when the device reports no battery; BlueZ hands it over as a
      // 0–100 percentage, which Astal may pass through as a 0–1 fraction.
      const battery = device.batteryPercentage
      if (battery >= 0) {
        const percent = battery <= 1 ? battery * 100 : battery
        notes.push(`${Math.round(percent)}% battery`)
      }
      items.push({
        key: `${device.address}:${notes.join(":")}`,
        label: device.name ?? device.address,
        sublabel: notes.join(" · "),
        iconName: "bluetooth-symbolic",
        activate: () => {
          if (device.connected) device.disconnect_device(() => this.refresh())
          else device.connect_device(() => this.refresh())
        },
      })
    }
    return items
  }

  // Sinks on one card share a long prefix ("400 Series Chipset Family
  // On-Package HD Audio ...") that ellipsizes away the part that differs.
  // Returns each speaker's short name (the part after the shared prefix)
  // and the prefix itself, so callers can show it separately.
  private speakerNames(speakers: AstalWp.Endpoint[]): {
    names: string[]
    prefix: string
  } {
    const descriptions = speakers.map(
      (speaker) => speaker.description ?? "Unknown output",
    )
    let prefix = descriptions.length > 1 ? descriptions[0] : ""
    for (const description of descriptions) {
      // Shrink word by word until it matches; no words left means no
      // shared prefix.
      while (prefix !== "" && !description.startsWith(prefix)) {
        const lastSpace = prefix.lastIndexOf(" ")
        prefix = lastSpace < 0 ? "" : prefix.slice(0, lastSpace)
      }
    }
    const names = descriptions.map((description) =>
      prefix !== "" && description.length > prefix.length
        ? description.slice(prefix.length).trim()
        : description,
    )
    return { names, prefix: prefix.trim() }
  }

  private outputItems(): ListItem[] {
    const audio = this.audio
    if (!audio || !audio.speakers) return []
    const { names, prefix } = this.speakerNames(audio.speakers)
    const items: ListItem[] = []
    audio.speakers.forEach((speaker, index) => {
      const description = speaker.description ?? "Unknown output"
      const notes: string[] = []
      if (names[index] !== description) notes.push(prefix)
      if (speaker.isDefault) notes.push("default")
      items.push({
        key: `${description}:${speaker.isDefault}`,
        label: names[index],
        sublabel: notes.length > 0 ? notes.join(" · ") : undefined,
        iconName: "audio-headphones-symbolic",
        activate: () => {
          speaker.isDefault = true
          this.refreshSoon(300)
        },
      })
    })
    return items
  }

  // ── volume ──

  private syncVolume() {
    const speaker = this.audio?.defaultSpeaker
    if (!speaker) {
      this.volumeText.set_label("Audio starting…")
      return
    }
    this.watchSpeaker(speaker)
    const volume = Math.round(speaker.volume * 100)
    if (Math.abs(this.volumeSlider.get_value() - volume) > 0.5) {
      this.volumeSlider.set_value(volume)
    }
    this.muteLabel.set_label(speaker.mute ? "Unmute" : "Mute")
    this.volumeText.set_label(`${volume}%${speaker.mute ? "  muted" : ""}`)
    this.syncMixer()
  }

  // Per-app rows (playing streams) with their own sliders. Rows are only
  // rebuilt when the set of streams changes; each row follows its stream's
  // volume live so wheel/media-key changes show without a rebuild.
  private syncMixer() {
    const streams: AstalWp.Stream[] = []
    for (const stream of this.audio?.streams ?? []) {
      if (stream.mediaClass === AstalWp.MediaClass.STREAM_OUTPUT_AUDIO) {
        streams.push(stream)
      }
    }
    const ids = streams.map((stream) => stream.id).join(",")
    if (ids === this.mixerIds) return
    this.mixerIds = ids
    this.disposeMixer()
    this.disposeMixer = createRoot((dispose) => {
      this.buildMixerRows(streams)
      return () => {
        dispose()
        let child = this.mixerBox.get_first_child()
        while (child !== null) {
          const next = child.get_next_sibling()
          this.mixerBox.remove(child)
          child = next
        }
      }
    })
  }

  private buildMixerRows(streams: AstalWp.Stream[]) {
    if (streams.length === 0) {
      this.mixerBox.append(
        (
          <label
            class="mute"
            label="Nothing playing"
            halign={Gtk.Align.START}
          />
        ) as Gtk.Widget,
      )
      return
    }
    for (const stream of streams) {
      const slider = (
        <Gtk.Scale
          widthRequest={120}
          drawValue={false}
          adjustment={
            new Gtk.Adjustment({
              lower: 0,
              upper: 100,
              value: Math.round(stream.volume * 100),
              stepIncrement: 5,
            })
          }
          onValueChanged={(scale: Gtk.Scale) => {
            const next = scale.get_value() / 100
            if (Math.abs(next - stream.volume) > 0.005) stream.volume = next
          }}
        />
      ) as Gtk.Scale
      stream.connect("notify::volume", () => {
        const volume = Math.round(stream.volume * 100)
        if (Math.abs(slider.get_value() - volume) > 0.5)
          slider.set_value(volume)
      })
      this.mixerBox.append(
        (
          <box class="mixer-row" spacing={10}>
            <image class="status-icon" iconName={stream.icon} />
            <label
              class="status-text"
              label={stream.description ?? stream.name ?? "Stream"}
              halign={Gtk.Align.START}
              hexpand
              ellipsize={Pango.EllipsizeMode.END}
            />
            {slider}
          </box>
        ) as Gtk.Widget,
      )
    }
  }

  // Follow the live speaker so the slider and label track volume/mute
  // changes (wheel, media keys, drags) without rebuilding mid-drag.
  private watchSpeaker(speaker: AstalWp.Endpoint) {
    if (this.watchedSpeaker === speaker) return
    if (this.watchedSpeaker) {
      for (const id of this.speakerSignals) this.watchedSpeaker.disconnect(id)
    }
    this.watchedSpeaker = speaker
    this.speakerSignals = [
      speaker.connect("notify::volume", () => this.syncVolume()),
      speaker.connect("notify::mute", () => this.syncVolume()),
    ]
  }

  private nudgeVolume(delta: number) {
    const speaker = this.audio?.defaultSpeaker
    if (!speaker) return
    speaker.volume = Math.max(0, Math.min(1, speaker.volume + delta / 100))
  }

  // ── pane surface ──

  applyFilter(text: string) {
    this.list.applyFilter(text)
  }

  move(dx: number, dy: number) {
    if (dx !== 0) {
      const ids = SUBS.map((spec) => spec.id)
      const next = (ids.indexOf(this.sub) + dx + ids.length) % ids.length
      this.setSub(ids[next])
      return
    }
    if (this.sub === "volume") {
      this.nudgeVolume(dy > 0 ? -5 : 5)
      return
    }
    this.list.move(dx, dy)
  }

  jump(toEnd: boolean) {
    if (this.sub !== "volume") this.list.jump(toEnd)
  }

  accept(_keyval: number) {
    if (this.sub === "volume") {
      const speaker = this.audio?.defaultSpeaker
      if (speaker) speaker.mute = !speaker.mute
      return
    }
    this.list.accept()
  }

  onLetter(letter: string, _keyval: number): boolean {
    const spec = SUBS.find((entry) => entry.key === letter)
    if (!spec) return false
    this.setSub(spec.id)
    return true
  }
}
