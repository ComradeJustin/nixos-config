# Search pane: app rows, substring filter, score-based ordering.
import apps
import theme
from fabric.widgets.box import Box
from fabric.widgets.button import Button
from fabric.widgets.image import Image
from fabric.widgets.label import Label
from fabric.widgets.scrolledwindow import ScrolledWindow
from gi.repository import GLib, Gtk
from panes import header_label, scroll_into_view


class SearchPane:
    def __init__(self, shell):
        self.shell = shell
        self.rows = []
        self.visible_rows = []
        self.pending_apps = []
        self.index = 0
        self.loaded = False

    def details_size(self):
        return theme.DETAILS_WIDTH, theme.DETAILS_SEARCH_HEIGHT

    def build_subs(self):
        return []

    def build_details(self):
        self.empty = Label(
            style_classes="empty", label="No apps match", h_align="center"
        )
        self.empty.set_no_show_all(True)
        self.empty.set_visible(False)
        self.list_box = Box(orientation="v", spacing=4)
        self.container = Box(orientation="v", children=[self.empty, self.list_box])
        self.scroller = ScrolledWindow(
            child=self.container,
            min_content_size=(-1, 280),
            max_content_size=(-1, 280),
            h_scrollbar_policy="never",
            v_scrollbar_policy="automatic",
        )
        return Box(
            orientation="v",
            spacing=8,
            children=[
                header_label("Search"),
                Box(style_classes="detail-rule"),
                self.scroller,
            ],
        )

    def ensure(self):
        if self.loaded:
            self.apply_filter()
            return
        self.loaded = True
        self.pending_apps = apps.list_apps()
        # Build rows a few per idle tick so animation frames interleave
        # instead of freezing behind one long build.
        GLib.idle_add(self._build_next_rows)

    def _build_next_rows(self):
        for _ in range(8):
            if not self.pending_apps:
                self.list_box.show_all()
                self.apply_filter()
                return False
            self._build_row(self.pending_apps.pop(0))
        return True

    def _build_row(self, app):
        # Icon by name, not pixbuf: GTK rasterizes lazily at draw time and
        # caches, so row building stays cheap (~1ms instead of ~50ms each).
        icon = None
        icon_theme = Gtk.IconTheme.get_default()
        if app.icon_name and icon_theme.lookup_icon(app.icon_name, theme.ICON_SIZE, 0):
            icon = Image(icon_name=app.icon_name, icon_size=theme.ICON_SIZE)
        if icon is None:
            icon = Label(
                label=apps.shown_name(app)[:1].upper(),
                style_classes="icon-fallback",
                h_align="center",
                v_align="center",
            )
        name = Label(
            label=apps.shown_name(app),
            style_classes="action-label",
            h_align="start",
            h_expand=True,
            ellipsization="end",
        )
        text_lines = [name]
        if app.generic_name:
            text_lines.append(
                Label(
                    label=app.generic_name,
                    style_classes="action-sub",
                    h_align="start",
                    h_expand=True,
                    ellipsization="end",
                )
            )
        text = Box(orientation="v", children=text_lines)
        text.set_valign(Gtk.Align.CENTER)
        # A Button gives hover styling (CSS :hover) and clicks for free.
        # Keyboard selection stays index-based, so buttons must not steal
        # focus from the window or the filter entry.
        row = Button(
            style_classes="action",
            child=Box(orientation="h", spacing=10, children=[icon, text]),
            on_clicked=lambda *_a, item=app: self.launch(item),
        )
        row.set_can_focus(False)
        self.rows.append(
            {
                "widget": row,
                "app": app,
                "hay": apps.haystack(app),
            }
        )
        self.list_box.add(row)

    def apply_filter(self):
        # Visibility filters by substring; ordering puts the best score_app
        # match first ("fire" lists Firefox before alphabetical neighbours).
        needle = self.shell.filter_text.lower()
        visible = []
        for row in self.rows:
            match = needle == "" or needle in row["hay"]
            row["widget"].set_visible(match)
            if match:
                visible.append(row)
        if needle:
            visible.sort(
                key=lambda row: (
                    -apps.score_app(needle, row["app"]),
                    apps.shown_name(row["app"]).lower(),
                )
            )
        for position, row in enumerate(visible):
            self.list_box.reorder_child(row["widget"], position)
        self.visible_rows = visible
        self.empty.set_visible(len(visible) == 0)
        self.index = 0
        self.highlight()

    def highlight(self):
        if self.index >= len(self.visible_rows):
            self.index = max(0, len(self.visible_rows) - 1)
        for index, row in enumerate(self.visible_rows):
            ctx = row["widget"].get_style_context()
            if index == self.index:
                ctx.add_class("selected")
                scroll_into_view(self.scroller, self.container, row["widget"])
            else:
                ctx.remove_class("selected")

    def launch(self, app):
        app.launch()
        self.shell.request_close()

    def move(self, dx, dy):
        if not self.visible_rows:
            return
        step = dx if dx != 0 else dy
        next_index = self.index + step
        if next_index < 0 or next_index >= len(self.visible_rows):
            return
        self.index = next_index
        self.highlight()

    def jump(self, to_end):
        if self.visible_rows:
            self.index = len(self.visible_rows) - 1 if to_end else 0
            self.highlight()

    def accept(self, _keyval):
        if not self.visible_rows:
            return
        self.launch(self.visible_rows[self.index]["app"])
