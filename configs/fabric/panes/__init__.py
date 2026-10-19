# Shared bits for the four detail panes. Each pane class owns one mode's
# panel content, sub-ring items, and selection logic; the overlay owns the
# ring, animation, and key routing, and talks to panes through a uniform
# surface: details_size / build_details / build_subs / ensure / move /
# jump / accept (plus apply_filter on the filterable panes).
import theme
from fabric.widgets.box import Box
from fabric.widgets.eventbox import EventBox
from fabric.widgets.label import Label
from gi.repository import Gtk


def scroll_into_view(scroller, container, row):
    coords = row.translate_coordinates(container, 0, 0)
    if coords is None:
        return
    top = coords[1]
    bottom = top + row.get_allocation().height
    adjustment = scroller.get_vadjustment()
    if top < adjustment.get_value():
        adjustment.set_value(top)
    elif bottom > adjustment.get_value() + adjustment.get_page_size():
        adjustment.set_value(bottom - adjustment.get_page_size())


def header_label(text):
    return Label(
        label=text,
        style_classes=["detail-h", "display"],
        h_align="start",
    )


def make_sub_pill(key, title, on_press):
    # One pill on the sub-ring fan: dot, title, key hint.
    dot = Box(style_classes="dot")
    dot.set_valign(Gtk.Align.CENTER)
    inner = Box(
        orientation="h",
        spacing=10,
        style_classes="sub-inner",
        children=[
            dot,
            Label(label=title, style_classes="sub-title"),
            Label(
                label=key,
                style_classes=["sub-key", "mono"],
                h_align="end",
                h_expand=True,
            ),
        ],
    )
    inner.set_vexpand(True)
    inner.set_valign(Gtk.Align.CENTER)
    body = Box(style_classes=["pill", "sub"], orientation="v", children=[inner])
    body.set_size_request(theme.SUB_WIDTH, theme.SUB_HEIGHT)
    wrap = EventBox(child=body, events=["button-press", "button-release"])
    wrap.set_size_request(theme.SUB_WIDTH, theme.SUB_HEIGHT)
    wrap.connect("button-press-event", on_press)
    return {
        "widget": wrap,
        "body": body,
        "dot": dot,
        "key": key,
        "title": title,
    }
