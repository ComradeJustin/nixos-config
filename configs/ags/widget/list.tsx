// Unified filterable list used by every pane: gnim's <For> renders and
// diffs the rows (keyed, so unchanged rows persist), grids are chunked rows
// of plain boxes, and the only custom parts are the shared fuzzy matcher,
// the vim-style match highlight, and selection movement.
import { Accessor, For, createComputed, createState } from "ags"
import { Gtk } from "ags/gtk4"
import GLib from "gi://GLib"
import Pango from "gi://Pango"
import * as colors from "../colors"
import { scrollIntoView } from "./common"

export interface ListItem {
  // Stable identity for row reuse. Include volatile text (e.g. signal %)
  // so a changed row is rebuilt rather than shown stale.
  key: string
  label: string
  sublabel?: string
  iconName?: string
  // Factory for custom cell content above the label (wallpaper thumbs).
  // A factory, not a widget: <For> re-creates rows when filtered items
  // return, and a shared widget would be re-parented (GTK forbids it).
  makeChild?: () => Gtk.Widget
  // Tiebreak between equal fuzzy scores (e.g. app launch frequency).
  weight?: number
  // Accent styling for the "current" item (active wallpaper).
  marked?: boolean
  activate: () => void
}

interface Options {
  columns?: number
  height: number
  emptyText: string
  // Called whenever the selected item changes (or becomes none).
  onSelect?: (item: ListItem | undefined) => void
}

// Subsequence fuzzy match: every query char must appear in order.
// Score favors prefix and consecutive matches; -1 means no match.
export function fuzzyScore(text: string, query: string): number {
  if (query === "") return 0
  const lowerText = text.toLowerCase()
  const lowerQuery = query.toLowerCase()
  let score = 0
  let position = 0
  let previousHit = -2
  for (const char of lowerQuery) {
    const hit = lowerText.indexOf(char, position)
    if (hit < 0) return -1
    score += hit === previousHit + 1 ? 3 : 1
    if (hit === 0) score += 2
    previousHit = hit
    position = hit + 1
  }
  return score
}

// Pango cannot read CSS variables, so the chip background is a precomputed
// blend of the accent onto the surface color.
const HIGHLIGHT_BG = colors.mixOnto(colors.accent, colors.surface, 0.22)

// vim-style highlight: background chip behind each matched character.
// Iterates code points, not UTF-16 units, so emoji in names stay intact.
export function highlightMarkup(text: string, query: string): string {
  if (query === "") return GLib.markup_escape_text(text, -1)
  const queryChars = [...query.toLowerCase()]
  let queryPos = 0
  let markup = ""
  for (const char of text) {
    const escaped = GLib.markup_escape_text(char, -1)
    if (
      queryPos < queryChars.length &&
      char.toLowerCase() === queryChars[queryPos]
    ) {
      markup += `<span background="${HIGHLIGHT_BG}" foreground="${colors.accent}" weight="bold">${escaped}</span>`
      queryPos++
    } else {
      markup += escaped
    }
  }
  return markup
}

export class FilterList {
  widget: Gtk.Widget
  private columns: number
  private items: Accessor<ListItem[]>
  private setItems: (items: ListItem[]) => void
  private query: Accessor<string>
  private setQuery: (query: string) => void
  private visible: Accessor<ListItem[]>
  private selected: Accessor<number>
  private setSelected: (index: number) => void
  private rowWidgets = new Map<string, Gtk.Widget>()
  private scroller!: Gtk.ScrolledWindow
  private onSelect: ((item: ListItem | undefined) => void) | undefined

  constructor(options: Options) {
    this.columns = options.columns ?? 1
    this.onSelect = options.onSelect
    ;[this.items, this.setItems] = createState(new Array<ListItem>())
    ;[this.query, this.setQuery] = createState("")
    ;[this.selected, this.setSelected] = createState(0)
    this.visible = createComputed(() => {
      const query = this.query()
      const scored = []
      for (const item of this.items()) {
        const score = fuzzyScore(item.label, query)
        if (score >= 0) scored.push({ item, score })
      }
      if (query !== "") {
        scored.sort(
          (a, b) =>
            b.score - a.score || (b.item.weight ?? 0) - (a.item.weight ?? 0),
        )
      }
      return scored.map((entry) => entry.item)
    })

    // Grids render as chunked rows of plain boxes. (Gtk.FlowBox looked like
    // the ready-made answer, but its FlowBoxChild wrappers fight <For>'s
    // remove-and-reappend ordering and leak empty cells.)
    const chunks = createComputed(() => {
      const rows: { key: string; items: ListItem[] }[] = []
      const visible = this.visible()
      for (let i = 0; i < visible.length; i += this.columns) {
        const slice = visible.slice(i, i + this.columns)
        rows.push({
          key: slice.map((item) => item.key).join("|"),
          items: slice,
        })
      }
      return rows
    })
    const container =
      this.columns > 1 ? (
        <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
          <For each={chunks} id={(chunk: { key: string }) => chunk.key}>
            {(chunk: { key: string; items: ListItem[] }) => (
              <box homogeneous spacing={4}>
                {chunk.items.map((item) => this.buildRow(item))}
              </box>
            )}
          </For>
        </box>
      ) : (
        <box orientation={Gtk.Orientation.VERTICAL} spacing={6}>
          <For each={this.visible} id={(item: ListItem) => item.key}>
            {(item: ListItem) => this.buildRow(item)}
          </For>
        </box>
      )

    // The scroller cuts the last visible row wherever its height lands; a
    // gradient over the bottom edge turns that hard slice into a fade
    // that also reads as "more below".
    this.widget = (
      <Gtk.Overlay>
        <Gtk.ScrolledWindow
          $={(ref: Gtk.ScrolledWindow) => (this.scroller = ref)}
          heightRequest={options.height}
          hscrollbarPolicy={Gtk.PolicyType.NEVER}
          vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
        >
          <box orientation={Gtk.Orientation.VERTICAL}>
            <label
              class="empty"
              label={options.emptyText}
              visible={this.visible((items) => items.length === 0)}
            />
            {container}
          </box>
        </Gtk.ScrolledWindow>
        <box
          $={(ref: Gtk.Box) => this.followScrollEdges(ref, "top")}
          $type="overlay"
          class="list-fade top"
          valign={Gtk.Align.START}
          canTarget={false}
        />
        <box
          $={(ref: Gtk.Box) => this.followScrollEdges(ref, "bottom")}
          $type="overlay"
          class="list-fade"
          valign={Gtk.Align.END}
          canTarget={false}
        />
      </Gtk.Overlay>
    ) as Gtk.Widget
  }

  // Each edge fade shows only while there is content hidden past it.
  private followScrollEdges(fade: Gtk.Widget, edge: "top" | "bottom") {
    const adjustment = this.scroller.vadjustment
    const update = () => {
      const hiddenAbove = adjustment.value
      const hiddenBelow =
        adjustment.upper - adjustment.pageSize - adjustment.value
      fade.visible = (edge === "top" ? hiddenAbove : hiddenBelow) > 1
    }
    adjustment.connect("changed", update)
    adjustment.connect("value-changed", update)
    update()
  }

  private buildRow(item: ListItem): Gtk.Widget {
    // Selection and highlight are reactive: cssClasses follows the selected
    // key, the label markup follows the query.
    const selectedKey = createComputed(
      () => this.visible()[this.selected()]?.key,
    )
    const child = item.makeChild?.()
    const classes = createComputed(() => {
      const list = [child ? "wp-cell" : "action"]
      if (selectedKey() === item.key) list.push("selected")
      if (item.marked) list.push("marked")
      return list
    })
    const nameLabel = (
      <label
        class={child ? "wp-name" : "action-label"}
        useMarkup
        label={this.query((query) => highlightMarkup(item.label, query))}
        halign={child ? Gtk.Align.CENTER : Gtk.Align.START}
        hexpand={!child}
        ellipsize={Pango.EllipsizeMode.END}
        maxWidthChars={child ? 20 : -1}
      />
    ) as Gtk.Widget

    let content: Gtk.Widget
    if (child) {
      content = (
        <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
          <box class="wp-frame" halign={Gtk.Align.CENTER}>
            {child}
          </box>
          {nameLabel}
        </box>
      ) as Gtk.Widget
    } else {
      const textLines = [nameLabel]
      if (item.sublabel) {
        textLines.push(
          (
            <label
              class="action-sub"
              label={item.sublabel}
              halign={Gtk.Align.START}
              hexpand
              ellipsize={Pango.EllipsizeMode.END}
            />
          ) as Gtk.Widget,
        )
      }
      const children: Gtk.Widget[] = []
      if (item.iconName) {
        children.push(
          (<image class="app-icon" iconName={item.iconName} />) as Gtk.Widget,
        )
      }
      children.push(
        (
          <box
            orientation={Gtk.Orientation.VERTICAL}
            valign={Gtk.Align.CENTER}
            hexpand
          >
            {textLines}
          </box>
        ) as Gtk.Widget,
      )
      content = (<box spacing={10}>{children}</box>) as Gtk.Widget
    }

    const row = (
      <button
        $={(ref: Gtk.Button) => this.rowWidgets.set(item.key, ref)}
        cssClasses={classes}
        hexpand={!child}
        onClicked={() => item.activate()}
      >
        {content}
      </button>
    ) as Gtk.Button
    row.canFocus = false
    return row
  }

  update(items: ListItem[]) {
    // Keep the selection on the same item across live refreshes. Prune
    // (never clear) the widget map: <For> keeps rows whose keys survive,
    // and their $ refs do not run again.
    const previousKey = this.visible.peek()[this.selected.peek()]?.key
    const keys = new Set(items.map((item) => item.key))
    for (const key of [...this.rowWidgets.keys()]) {
      if (!keys.has(key)) this.rowWidgets.delete(key)
    }
    // Always pass a fresh array so same-reference updates still notify.
    const previousIndex = this.selected.peek()
    this.setItems([...items])
    const visible = this.visible.peek()
    const index = visible.findIndex((item) => item.key === previousKey)
    if (index >= 0) {
      this.setSelected(index)
    } else {
      // The selected row was replaced (its key changed): stay in place
      // instead of jumping to the top.
      this.setSelected(Math.max(0, Math.min(previousIndex, visible.length - 1)))
    }
    this.notifySelect()
  }

  private notifySelect() {
    this.onSelect?.(this.visible.peek()[this.selected.peek()])
  }

  applyFilter(text: string) {
    this.setQuery(text)
    this.setSelected(0)
    this.notifySelect()
  }

  resetSelection() {
    this.setSelected(0)
    this.scroller.vadjustment.value = 0
    this.notifySelect()
  }

  private select(index: number) {
    this.setSelected(index)
    this.notifySelect()
    const item = this.visible.peek()[index]
    if (!item) return
    const widget = this.rowWidgets.get(item.key)
    if (widget) scrollIntoView(this.scroller, widget)
  }

  move(dx: number, dy: number) {
    const count = this.visible.peek().length
    if (count === 0) return
    const current = this.selected.peek()
    let next: number
    if (this.columns > 1) {
      let column = current % this.columns
      let row = Math.floor(current / this.columns)
      if (dx !== 0) {
        column += dx
        if (column < 0 || column >= this.columns) return
      } else {
        row += dy
        if (row < 0) return
      }
      next = row * this.columns + column
    } else {
      next = current + (dx !== 0 ? dx : dy)
    }
    if (next < 0 || next >= count) return
    this.select(next)
  }

  jump(toEnd: boolean) {
    const count = this.visible.peek().length
    if (count === 0) return
    this.select(toEnd ? count - 1 : 0)
  }

  accept() {
    this.visible.peek()[this.selected.peek()]?.activate()
  }
}
