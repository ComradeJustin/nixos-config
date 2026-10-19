// Search pane: app rows from AstalApps, rendered by the shared FilterList
// (unified fuzzy matching, highlight, and selection).
import { createRoot } from "ags"
import { Gtk } from "ags/gtk4"
import AstalApps from "gi://AstalApps"
import Gio from "gi://Gio"
import GioUnix from "gi://GioUnix"
import GLib from "gi://GLib"
import * as theme from "../theme"
import { Hint, Pane, Shell, SubItem, detailRule, headerLabel } from "./common"
import { FilterList } from "./list"

export class SearchPane implements Pane {
  hints: Hint[] = [
    ["↵", "launch"],
    ["/", "filter"],
    ["esc", "back"],
  ]
  private shell: Shell
  private apps = new AstalApps.Apps()
  private list = new FilterList({ height: 296, emptyText: "No apps match" })
  private appCount = 0
  // Most-launched apps as an icon row above the list; keys 1–6 launch
  // them directly while the filter is empty.
  private frecent: AstalApps.Application[] = []
  private frecentRow!: Gtk.Box
  // Tears down the current quick-row widgets and their gnim scope.
  private disposeFrecentRow: () => void = () => {}

  constructor(shell: Shell) {
    this.shell = shell
  }

  detailsSize(): [number, number] {
    return [theme.DETAILS_WIDTH, theme.DETAILS_SEARCH_HEIGHT]
  }

  summary(): string {
    return this.appCount > 0 ? `${this.appCount} apps` : ""
  }

  buildSubs(): SubItem[] {
    return []
  }

  private buildPanel(): Gtk.Widget {
    return (
      <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
        {headerLabel("Search")}
        {detailRule()}
        <box
          $={(ref: Gtk.Box) => (this.frecentRow = ref)}
          spacing={8}
          homogeneous
          visible={false}
        />
        {this.list.widget}
      </box>
    ) as Gtk.Widget
  }

  private rebuildFrecentRow() {
    // Widgets built outside the initial render need their own gnim scope,
    // or the signal handlers they register can never be cleaned up.
    this.disposeFrecentRow()
    this.disposeFrecentRow = createRoot((dispose) => {
      this.frecent.forEach((app, index) => {
        this.frecentRow.append(
          (
            <button
              class="frecent"
              tooltipText={app.name}
              onClicked={() => this.launch(app)}
            >
              <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
                <image
                  class="frecent-icon"
                  iconName={app.iconName || "application-x-executable"}
                />
                <label class="frecent-key mono" label={`${index + 1}`} />
              </box>
            </button>
          ) as Gtk.Widget,
        )
      })
      return () => {
        dispose()
        let child = this.frecentRow.get_first_child()
        while (child !== null) {
          const next = child.get_next_sibling()
          this.frecentRow.remove(child)
          child = next
        }
      }
    })
    this.frecentRow.visible = this.frecent.length > 0
  }

  private launch(app: AstalApps.Application) {
    // Launch into a transient systemd scope of its own. AstalApps' own
    // launch() leaves the app inside ags-shell.service's cgroup, where a
    // restart or crash of the shell kills every app opened from it.
    const desktopFile = GioUnix.DesktopAppInfo.new(app.entry)?.get_filename()
    if (!desktopFile) {
      console.error(`no desktop file for ${app.entry}`)
      return
    }
    // Unit names allow letters, digits and : - _ . only.
    const unitId = app.entry
      .replace(/\.desktop$/, "")
      .replace(/[^A-Za-z0-9:_.-]/g, "_")
    try {
      Gio.Subprocess.new(
        [
          "systemd-run",
          "--user",
          "--scope",
          "--quiet",
          "--collect",
          "--slice=app.slice",
          `--unit=app-ags-${unitId}-${GLib.get_monotonic_time()}`,
          `--description=${app.name}`,
          "--",
          "gio",
          "launch",
          desktopFile,
        ],
        Gio.SubprocessFlags.NONE,
      )
    } catch (error) {
      console.error(error)
      return
    }
    // AstalApps persists the launch count through this property's notify.
    app.frequency = app.frequency + 1
    this.shell.requestClose()
    // The launch bumps this app's frequency, so the order changes;
    // rebuild the rows once the close animation is over (the panel is
    // hidden) rather than synchronously inside the next dive.
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 700, () => {
      this.ensure()
      return GLib.SOURCE_REMOVE
    })
  }

  buildDetails(): Gtk.Widget {
    const details = this.buildPanel()
    // Build the rows once now (the overlay is closed at startup) instead of
    // on every dive: creating ~40 icon rows synchronously mid-animation
    // starved the dive to a couple of frames.
    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      this.ensure()
      return GLib.SOURCE_REMOVE
    })
    return details
  }

  private lastOrder = ""

  ensure() {
    // Most-launched first when the query is empty; AstalApps persists
    // launch frequency itself as long as we launch through it. Rebuild
    // only when the order actually changed (a launch bumped a frequency).
    const apps = this.apps.get_list()
    this.appCount = apps.length
    apps.sort(
      (a, b) => b.frequency - a.frequency || a.name.localeCompare(b.name),
    )
    const order = apps.map((app) => app.entry ?? app.name).join("|")
    if (order === this.lastOrder) {
      this.list.resetSelection()
      return
    }
    this.lastOrder = order
    this.frecent = apps
      .filter((app) => app.frequency > 0)
      .slice(0, theme.FRECENT_COUNT)
    this.rebuildFrecentRow()
    this.list.update(
      apps.map((app) => ({
        key: app.entry ?? app.name,
        label: app.name,
        sublabel: app.description ?? undefined,
        iconName: app.iconName || "application-x-executable",
        weight: app.frequency,
        activate: () => this.launch(app),
      })),
    )
  }

  applyFilter(text: string) {
    this.list.applyFilter(text)
    // The quick row only makes sense over the full list.
    this.frecentRow.visible = text === "" && this.frecent.length > 0
  }

  onLetter(letter: string, _keyval: number): boolean {
    if (!/^[1-9]$/.test(letter) || !this.frecentRow.visible) return false
    const app = this.frecent[Number(letter) - 1]
    if (!app) return false
    this.launch(app)
    return true
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
