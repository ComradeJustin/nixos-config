// Wallpaper pane: thumbnail grid from assets/wallpapers, applied via awww.
// The grid, filtering, highlight, and selection come from the shared
// FilterList (3 columns); this file only decodes thumbnails and runs awww.
// Decoding happens on GdkPixbuf's worker thread (the async API), one file
// at a time: synchronous decodes hogged the main loop for seconds after
// startup and starved every animation.
import { Gtk, Gdk } from "ags/gtk4"
import { execAsync } from "ags/process"
import GdkPixbuf from "gi://GdkPixbuf"
import Gio from "gi://Gio"
import GLib from "gi://GLib"
import * as theme from "../theme"
import Pango from "gi://Pango"
import { Hint, Pane, Shell, SubItem, detailRule, headerLabel } from "./common"
import { FilterList, ListItem } from "./list"

const EXTENSIONS = [".png", ".jpg", ".jpeg", ".webp", ".gif"]

// Mean color of a thumbnail as #rrggbb, sampling every 8th pixel.
function averageColor(pixbuf: GdkPixbuf.Pixbuf): string {
  const pixels = pixbuf.get_pixels()
  const channels = pixbuf.get_n_channels()
  const rowstride = pixbuf.get_rowstride()
  let red = 0
  let green = 0
  let blue = 0
  let count = 0
  for (let y = 0; y < pixbuf.get_height(); y += 8) {
    for (let x = 0; x < pixbuf.get_width(); x += 8) {
      const offset = y * rowstride + x * channels
      red += pixels[offset]
      green += pixels[offset + 1]
      blue += pixels[offset + 2]
      count++
    }
  }
  if (count === 0) return "#000000"
  const hex = (value: number) =>
    Math.round(value / count)
      .toString(16)
      .padStart(2, "0")
  return `#${hex(red)}${hex(green)}${hex(blue)}`
}

export class WallpaperPane implements Pane {
  hints: Hint[] = [
    ["↵", "apply"],
    ["/", "filter"],
    ["esc", "back"],
  ]
  private shell: Shell
  // Basename of the active wallpaper, as last reported by awww.
  private currentName = ""
  private list = new FilterList({
    columns: theme.WALLPAPER_COLUMNS,
    // Whole rows only, so no cell is sliced by the panel edge.
    height: theme.WALLPAPER_ROWS * (theme.WALLPAPER_CELL_HEIGHT + 4) - 4,
    emptyText: "No wallpapers in assets/wallpapers",
    onSelect: (item) => this.showSelection(item),
  })
  private items: ListItem[] = []
  private pendingFiles: string[] = []
  private header!: Gtk.Label
  private status!: Gtk.Label
  // Per-wallpaper facts for the header: "1920×1080" and the average
  // color of the thumbnail, keyed by filename.
  private facts = new Map<string, { size: string; color: string }>()

  constructor(shell: Shell) {
    this.shell = shell
  }

  detailsSize(): [number, number] {
    const width = theme.WALLPAPER_COLUMNS * theme.WALLPAPER_CELL_WIDTH + 36
    return [width, theme.DETAILS_WALLPAPER_HEIGHT]
  }

  buildSubs(): SubItem[] {
    return []
  }

  summary(): string {
    return this.currentName
  }

  buildDetails(): Gtk.Widget {
    // The header names the selected wallpaper and the panel takes on
    // its average color, so browsing previews the mood before apply.
    this.header = headerLabel("Wallpaper")
    this.header.ellipsize = Pango.EllipsizeMode.END
    const details = (
      <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
        {this.header}
        {detailRule()}
        <label
          $={(ref: Gtk.Label) => (this.status = ref)}
          class="detail-status"
          halign={Gtk.Align.START}
        />
        {this.list.widget}
      </box>
    ) as Gtk.Widget
    this.pendingFiles = this.listFiles()
    this.decodeNextThumb()
    return details
  }

  private showSelection(item: ListItem | undefined) {
    if (!item) {
      this.header.label = "Wallpaper"
      this.status.label = ""
      this.shell.tintPanel(this, null)
      return
    }
    const facts = this.facts.get(item.label)
    const notes: string[] = []
    if (facts) notes.push(facts.size)
    if (item.marked) notes.push("current")
    this.header.label = item.label.replace(/\.[^.]+$/, "")
    this.status.label = notes.join(" · ")
    this.shell.tintPanel(this, facts?.color ?? null)
  }

  ensure() {
    // Ask awww which wallpaper is active and mark its cell.
    execAsync(["awww", "query"])
      .then((output) => {
        const match = output.match(/image: (.*)$/m)
        const current = match ? GLib.path_get_basename(match[1].trim()) : ""
        this.currentName = current
        let changed = false
        for (const item of this.items) {
          const marked = item.label === current
          if ((item.marked ?? false) !== marked) {
            item.marked = marked
            item.key = marked ? `${item.label}:current` : item.label
            changed = true
          }
        }
        if (changed) this.list.update(this.items)
      })
      .catch(() => {})
  }

  private listFiles(): string[] {
    const files: string[] = []
    // The folder may not exist yet on a fresh machine; an empty grid (with
    // its "No wallpapers" hint) beats crashing the whole overlay at startup.
    let dir: GLib.Dir
    try {
      dir = GLib.Dir.open(theme.WALLPAPER_DIR, 0)
    } catch {
      return files
    }
    let name = dir.read_name()
    while (name !== null) {
      const lower = name.toLowerCase()
      if (EXTENSIONS.some((ext) => lower.endsWith(ext))) {
        files.push(name)
      }
      name = dir.read_name()
    }
    dir.close()
    files.sort()
    return files
  }

  private decodeNextThumb() {
    const name = this.pendingFiles.shift()
    if (name === undefined) {
      this.list.update(this.items)
      this.ensure()
      return
    }
    const path = GLib.build_filenamev([theme.WALLPAPER_DIR, name])
    // Scale to cover the thumb box; Gtk.Picture center-crops the rest.
    const file = Gio.File.new_for_path(path)
    file.read_async(GLib.PRIORITY_LOW, null, (_file, readResult) => {
      let stream: Gio.FileInputStream
      try {
        stream = file.read_finish(readResult)
      } catch {
        this.addItem(name, path, null)
        return
      }
      GdkPixbuf.Pixbuf.new_from_stream_at_scale_async(
        stream,
        theme.WALLPAPER_THUMB_WIDTH * 2,
        -1,
        true,
        null,
        (_stream, decodeResult) => {
          let texture: Gdk.Texture | null = null
          try {
            const pixbuf = GdkPixbuf.Pixbuf.new_from_stream_finish(decodeResult)
            texture = Gdk.Texture.new_for_pixbuf(pixbuf)
            const [, width, height] = GdkPixbuf.Pixbuf.get_file_info(path)
            this.facts.set(name, {
              size: `${width}×${height}`,
              color: averageColor(pixbuf),
            })
          } catch {
            texture = null
          }
          this.addItem(name, path, texture)
        },
      )
    })
  }

  private addItem(name: string, path: string, texture: Gdk.Texture | null) {
    // Each row builds its own Picture from the shared texture, since
    // widgets cannot be re-parented across rows.
    this.items.push({
      key: name, // updated to include the marked state in ensure()
      label: name,
      makeChild: () =>
        texture !== null
          ? ((
              <Gtk.Picture
                paintable={texture}
                contentFit={Gtk.ContentFit.COVER}
                widthRequest={theme.WALLPAPER_THUMB_WIDTH}
                heightRequest={theme.WALLPAPER_THUMB_HEIGHT}
              />
            ) as Gtk.Widget)
          : ((
              <box
                widthRequest={theme.WALLPAPER_THUMB_WIDTH}
                heightRequest={theme.WALLPAPER_THUMB_HEIGHT}
              />
            ) as Gtk.Widget),
      activate: () => this.apply(path),
    })
    this.decodeNextThumb()
  }

  private apply(path: string) {
    this.currentName = GLib.path_get_basename(path)
    execAsync([
      "awww",
      "img",
      path,
      "--transition-type",
      "wipe",
      "--transition-duration",
      "1",
    ]).catch(console.error)
    this.shell.requestClose()
  }

  applyFilter(text: string) {
    this.list.applyFilter(text)
  }

  move(dx: number, dy: number) {
    this.list.move(dx, dy)
  }

  jump(toEnd: boolean) {
    this.list.jump(toEnd)
  }

  accept(_keyval: number) {
    this.list.accept()
  }
}
