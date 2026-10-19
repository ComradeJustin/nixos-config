# Wallpaper pane: thumbnail grid with substring filter.
import theme
import wallpapers
from fabric.widgets.box import Box
from fabric.widgets.button import Button
from fabric.widgets.image import Image
from fabric.widgets.label import Label
from fabric.widgets.scrolledwindow import ScrolledWindow
from gi.repository import GdkPixbuf, GLib
from panes import header_label, scroll_into_view


class WallpaperPane:
    def __init__(self, shell):
        self.shell = shell
        self.cells = []
        self.index = 0
        self.loaded = False

    def details_size(self):
        width = theme.WALLPAPER_COLUMNS * theme.WALLPAPER_CELL_WIDTH + 36
        return width, theme.DETAILS_WALLPAPER_HEIGHT

    def build_subs(self):
        return []

    def build_details(self):
        self.empty = Label(
            style_classes="empty",
            label="No wallpapers in assets/wallpapers",
            h_align="center",
        )
        self.empty.set_no_show_all(True)
        self.empty.set_visible(False)
        self.grid = Box(orientation="v")
        self.container = Box(orientation="v", children=[self.empty, self.grid])
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
                header_label("Wallpaper"),
                Box(style_classes="detail-rule"),
                self.scroller,
            ],
        )

    def ensure(self):
        if not self.loaded:
            self.loaded = True
            for item in wallpapers.list_wallpapers():
                try:
                    pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_size(
                        item["thumb"],
                        theme.WALLPAPER_THUMB_WIDTH,
                        theme.WALLPAPER_THUMB_HEIGHT,
                    )
                except GLib.Error:
                    pixbuf = None
                thumb = Image(pixbuf=pixbuf) if pixbuf else Box()
                cell = Button(
                    style_classes="wp-cell",
                    child=Box(
                        orientation="v",
                        spacing=4,
                        children=[
                            Box(style_classes="wp-frame", children=[thumb]),
                            Label(
                                label=item["name"],
                                style_classes="wp-name",
                                ellipsization="end",
                                h_align="center",
                            ),
                        ],
                    ),
                    on_clicked=lambda *_a, path=item["path"]: self.apply(path),
                )
                cell.set_can_focus(False)
                cell.set_size_request(
                    theme.WALLPAPER_CELL_WIDTH, theme.WALLPAPER_CELL_HEIGHT
                )
                self.cells.append(
                    {
                        "widget": cell,
                        "item": item,
                        "hay": item["name"].lower(),
                    }
                )
        self.apply_filter()

    def visible_cells(self):
        needle = self.shell.filter_text.lower()
        matches = []
        for cell in self.cells:
            if needle == "" or needle in cell["hay"]:
                matches.append(cell)
        return matches

    def apply_filter(self):
        # Cells are reused across relayouts (filtering), so pull them out of
        # last time's row boxes before the rows are dropped; GTK refuses to
        # add a widget that still has a parent.
        for cell in self.cells:
            row = cell["widget"].get_parent()
            if row is not None:
                row.remove(cell["widget"])
        for child in list(self.grid.get_children()):
            self.grid.remove(child)
        matches = self.visible_cells()
        self.empty.set_visible(len(matches) == 0)
        if not matches and not self.cells:
            self.empty.set_label("No wallpapers in assets/wallpapers")
        elif not matches:
            self.empty.set_label("No matches")
        columns = theme.WALLPAPER_COLUMNS
        row_cells = []
        for index, cell in enumerate(matches):
            row_cells.append(cell["widget"])
            if len(row_cells) == columns or index == len(matches) - 1:
                while len(row_cells) < columns:
                    filler = Box()
                    filler.set_size_request(
                        theme.WALLPAPER_CELL_WIDTH, theme.WALLPAPER_CELL_HEIGHT
                    )
                    row_cells.append(filler)
                row = Box(orientation="h", children=row_cells)
                row.set_homogeneous(True)
                self.grid.add(row)
                row_cells = []
        self.grid.show_all()
        self.index = 0
        self.highlight()

    def highlight(self):
        matches = self.visible_cells()
        if self.index >= len(matches):
            self.index = max(0, len(matches) - 1)
        for index, cell in enumerate(matches):
            ctx = cell["widget"].get_style_context()
            if index == self.index:
                ctx.add_class("selected")
                scroll_into_view(self.scroller, self.container, cell["widget"])
            else:
                ctx.remove_class("selected")

    def apply(self, path):
        wallpapers.apply_wallpaper(path)
        self.shell.request_close()

    def move(self, dx, dy):
        matches = self.visible_cells()
        if not matches:
            return
        columns = theme.WALLPAPER_COLUMNS
        column = self.index % columns
        row = self.index // columns
        if dx != 0:
            column += dx
            if column < 0 or column >= columns:
                return
        else:
            row += dy
            if row < 0:
                return
        next_index = row * columns + column
        if next_index >= len(matches):
            return
        self.index = next_index
        self.highlight()

    def jump(self, to_end):
        matches = self.visible_cells()
        if matches:
            self.index = len(matches) - 1 if to_end else 0
            self.highlight()

    def accept(self, _keyval):
        matches = self.visible_cells()
        if not matches:
            return
        self.apply(matches[self.index]["item"]["path"])
