# Ring overlay: a hub with four mode pills on a ring. h/l rotate the ring so
# the focused pill sits on the right; dive collapses that pill into the hub
# (which then names it), fans its sub-items out beside it, and slides a
# details panel in. Pane content and selection live in panes/*; this file
# owns the ring, the animators, the command bar, and key routing.
# Every frame is a pure function of the tweened values — see _layout_frame.
# Process child of main.py.
import math

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
import power
import settings as net
import theme
from animator import Animator
from fabric.widgets.box import Box
from fabric.widgets.entry import Entry
from fabric.widgets.eventbox import EventBox
from fabric.widgets.label import Label
from fabric.widgets.wayland import WaylandWindow
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell
from panes.network import NetworkPane
from panes.power_pane import PowerPane
from panes.search import SearchPane
from panes.wallpaper import WallpaperPane
from runlog import RunLog

# Clockwise order on the ring, starting at the right.
RING = ["search", "wallpaper", "network", "power"]
PREFIX = {"s": "search", "w": "wallpaper", "n": "network", "p": "power"}
SLOT_INFO = [
    ("search", "s", "Search", "apps"),
    ("wallpaper", "w", "Wallpaper", "background"),
    ("network", "n", "Network", "wifi · audio"),
    ("power", "p", "Power", "session"),
]
FILTERABLE = ("search", "wallpaper")

# Cubic bezier curves for the vendored Animator (CSS-style control points).
EASE_OUT_CUBIC = (0.33, 1.0, 0.68, 1.0)
# Overshoots the target by ~10% before settling.
EASE_OUT_BACK = (0.34, 1.56, 0.64, 1.0)
TWEEN_NAMES = ("open", "angle", "sub_angle", "dive", "fade")


class Plane(Gtk.Fixed):
    # Children at any offset must not grow the layer surface.
    def do_get_preferred_width(self):
        return (0, 0)

    def do_get_preferred_height(self):
        return (0, 0)


class Overlay(WaylandWindow):
    def __init__(self):
        self.showing = False
        self.dived = False
        self.focused = "search"
        self.mode = "normal"
        self.filter_text = ""
        self.wifi_ssid = ""
        self._opened_ms = 0
        self._closing = False
        # Current value of each animated quantity; one Animator drives each.
        # The animators are built at the end of __init__ (they tick on this
        # window's frame clock, so the window must exist first).
        self.tweens = {name: 0.0 for name in TWEEN_NAMES}
        self.animators = {}
        self._on_settled = None
        self._last_size = None
        self._open_pending = False
        self._layout_queued = False
        self.hold_source = ""
        self.hold_keyval = 0
        self.pending_g = False

        self.hold = power.Hold(self._on_hold_progress, self._on_hold_complete)
        self.runlog = RunLog(self._add_rail_entry)
        self.panes = {
            "search": SearchPane(self),
            "wallpaper": WallpaperPane(self),
            "network": NetworkPane(self),
            "power": PowerPane(self),
        }

        self.slots = {}
        self.plane = Plane()
        self.hub = self._build_hub()
        self.plane.put(self.hub, 0, 0)
        for slot_id, key, title, subtitle in SLOT_INFO:
            self._build_slot(slot_id, key, title, subtitle)

        self.rail = Box(name="rail", orientation="v", spacing=2)
        self.rail.set_no_show_all(True)
        self.rail.set_visible(False)

        self.prompt_label = Label(name="prompt", style_classes="mono", label=":")
        # A real GtkEntry: cursor, editing, and IME come from GTK, and typed
        # letters can never be mistaken for navigation keys.
        self.entry = Entry(name="cmd-entry", style_classes="mono", h_expand=True)
        self.entry.connect("notify::text", self._on_entry_text)
        self.command_bar = Box(
            name="command-bar",
            orientation="h",
            spacing=6,
            children=[self.prompt_label, self.entry],
        )
        self.command_bar.set_no_show_all(True)
        self.command_bar.set_visible(False)

        self.scrim = EventBox(
            name="scrim",
            events=["button-press"],
            h_expand=True,
            v_expand=True,
        )
        self.scrim.connect("button-press-event", self._on_scrim)

        root = Gtk.Overlay()
        root.add(self.scrim)
        root.add_overlay(self.plane)
        self.rail.set_halign(Gtk.Align.END)
        self.rail.set_valign(Gtk.Align.START)
        self.rail.set_margin_end(24)
        self.rail.set_margin_top(24)
        root.add_overlay(self.rail)
        self.command_bar.set_halign(Gtk.Align.CENTER)
        self.command_bar.set_valign(Gtk.Align.END)
        self.command_bar.set_margin_bottom(48)
        root.add_overlay(self.command_bar)

        super().__init__(
            name="overlay",
            title="fabric-shell",
            layer="overlay",
            anchor="left top right bottom",
            exclusivity="none",
            keyboard_mode="none",
            visible=False,
            child=root,
        )
        # -1 ignores the bar's exclusive zone so the scrim covers the whole
        # screen and the ring is centered on it, not on the area below the bar.
        GtkLayerShell.set_exclusive_zone(self, -1)
        self.set_can_focus(True)
        self.add_events(["key-press", "key-release", "scroll", "smooth-scroll"])
        self.connect("key-press-event", self.on_key_press)
        self.connect("key-release-event", self.on_key_release)
        self.connect("scroll-event", self.on_scroll)
        self.connect("size-allocate", self._on_size_allocate)
        for name in TWEEN_NAMES:
            animator = Animator(
                bezier_curve=EASE_OUT_CUBIC, duration=0.3, tick_widget=self
            )
            animator.connect("notify::value", self._on_animator_value, name)
            animator.connect("finished", self._on_animator_finished)
            self.animators[name] = animator
        # Building app rows (icon lookups) and wallpaper thumbs takes long
        # enough to stall the dive animation; do it once while idle at startup.
        GLib.idle_add(self._preload_panes)

    def _preload_panes(self):
        self.panes["search"].ensure()
        self.panes["wallpaper"].ensure()
        return False

    # ── open / close ──

    def toggle(self, *_args):
        if self.showing and not self._closing:
            self.request_close()
        else:
            self.open_overlay()

    def _reset_session(self):
        self._on_settled = None
        self._closing = False
        self.dived = False
        self.focused = "search"
        self.mode = "normal"
        self.filter_text = ""
        self.wifi_ssid = ""
        self.entry.set_text("")
        self.hold.cancel()
        self.hold_source = ""
        self.hold_keyval = 0
        self.pending_g = False
        for animator in self.animators.values():
            animator.pause()
        self.tweens = {name: 0.0 for name in TWEEN_NAMES}

    def open_overlay(self):
        self.showing = True
        self._opened_ms = GLib.get_monotonic_time() // 1000
        self._reset_session()
        self.keyboard_mode = "exclusive"
        self.set_opacity(0.0)
        self.show_all()
        # Keep the plane hidden until the first frame is laid out; otherwise
        # it flashes last session's positions before the pills jump.
        self.plane.hide()
        for slot in self.slots.values():
            slot["card"].show()
            slot["card"].set_sensitive(True)
            slot["details"].hide()
            for item in slot["sub_items"]:
                item["widget"].hide()
        self.command_bar.hide()
        if len(self.rail.get_children()) == 0:
            self.rail.hide()
        self._apply_focus()
        self._render_chrome()
        self.grab_focus()
        GLib.idle_add(self._start_open)

    def _start_open(self):
        if self.get_allocation().width <= 1:
            # First open: no allocation yet. size-allocate re-runs this.
            self._open_pending = True
            return False
        self._layout_frame()
        self.plane.show()
        self._animate("fade", 1.0, theme.FADE_IN_MS, EASE_OUT_CUBIC)
        self._animate("open", 1.0, theme.OPEN_MS, EASE_OUT_BACK)
        return False

    def request_close(self):
        if not self.showing or self._closing:
            return
        self._closing = True
        self.hold.cancel()
        self.hold_source = ""
        self.dived = False
        self.mode = "normal"
        self._render_chrome()
        self._animate("dive", 0.0, theme.CLOSE_MS, EASE_OUT_CUBIC)
        self._animate("open", 0.0, theme.CLOSE_MS, EASE_OUT_CUBIC)
        self._animate("fade", 0.0, theme.CLOSE_MS, EASE_OUT_CUBIC)
        self._on_settled = self._finish_close

    def _finish_close(self):
        self.showing = False
        self._closing = False
        self.keyboard_mode = "none"
        self.hide()

    # ── slots ──

    def _pill(self, child, width, height):
        # Rounded card; the radius is set in CSS per class.
        body = Box(style_classes="pill", orientation="v", children=[child])
        body.set_size_request(width, height)
        return body

    def _build_slot(self, slot_id, key, title, subtitle):
        key_label = Label(label=key, style_classes=["slot-key", "mono"])
        key_label.set_halign(Gtk.Align.END)
        title_label = Label(label=title, style_classes="slot-title", h_align="start")
        sub_label = Label(
            label=subtitle, style_classes="slot-subtitle", h_align="start"
        )
        dot = Box(style_classes="dot")
        dot.set_valign(Gtk.Align.CENTER)
        text = Box(
            orientation="v", spacing=1, h_expand=True, children=[title_label, sub_label]
        )
        text.set_valign(Gtk.Align.CENTER)
        inner_row = Box(
            orientation="h",
            spacing=12,
            style_classes="slot-inner",
            children=[dot, text, key_label],
        )
        # Take the pill's full height so the row centers instead of hugging the top.
        inner_row.set_vexpand(True)
        inner_row.set_valign(Gtk.Align.CENTER)
        body = self._pill(inner_row, theme.SLOT_WIDTH, theme.SLOT_HEIGHT)
        body.get_style_context().add_class("slot")
        wrap = EventBox(child=body, events=["button-press"])
        wrap.connect(
            "button-press-event",
            lambda *_args, sid=slot_id: self._on_slot_click(sid),
        )

        pane = self.panes[slot_id]
        sub_items = pane.build_subs()
        details_w, details_h = pane.details_size()
        details = self._pill(pane.build_details(), details_w, details_h)
        details.get_style_context().add_class("panel")

        self.plane.put(wrap, 0, 0)
        for item in sub_items:
            self.plane.put(item["widget"], 0, 0)
        self.plane.put(details, 0, 0)
        # show_all is a no-op on a no-show-all widget, so realise the children
        # first and only then take the containers out of show_all's reach.
        for hidden in [details] + [item["widget"] for item in sub_items]:
            hidden.show_all()
            hidden.set_no_show_all(True)
            hidden.hide()
        self.slots[slot_id] = {
            "id": slot_id,
            "key": key,
            "title": title,
            "card": wrap,
            "body": body,
            "dot": dot,
            "sub_items": sub_items,
            "details": details,
        }

    def _build_hub(self):
        # Circle at the ring's center. Empty at rest; on dive it grows and
        # names the mode whose sub-items now fill the fan.
        self.hub_title = Label(name="hub-title", style_classes="display")
        self.hub_title.set_opacity(0.0)
        hub = Box(name="hub")
        hub.set_center_widget(self.hub_title)
        hub.set_size_request(theme.HUB_SIZE, theme.HUB_SIZE)
        hub.set_sensitive(False)
        return hub

    def _on_slot_click(self, slot_id):
        if not self.showing:
            return True
        self.focused = slot_id
        self.dive()
        return True

    def _on_scrim(self, *_args):
        if not self.showing:
            return False
        if self.hold.active():
            self.hold.cancel()
            self.hold_source = ""
            return True
        if self.mode != "normal":
            self.back_to_normal()
            return True
        if self.dived:
            self.undive()
            return True
        self.request_close()
        return True

    # ── pane plumbing ──

    def _on_hold_progress(self, action_id, progress):
        self.panes["power"].set_hold_progress(action_id, progress)

    def _on_hold_complete(self, action_id):
        self.hold_source = ""
        power.run_action(action_id)
        self.request_close()

    def begin_wifi_password(self, ssid):
        self.wifi_ssid = ssid
        self.mode = "wifi-pass"
        self.entry.set_text("")
        self._render_chrome()

    def connect_wifi(self, ssid, password=""):
        self._add_rail_entry(
            {
                "offset": 0.0,
                "status": "pending",
                "step": "wifi",
                "text": f"connect {ssid}",
            }
        )

        def on_line(line):
            lowered = line.lower()
            if "error" in lowered:
                self._add_rail_entry(
                    {
                        "offset": 0.0,
                        "status": "err",
                        "step": "wifi",
                        "text": line.strip(),
                    }
                )
            elif "successfully" in lowered:
                self._add_rail_entry(
                    {
                        "offset": 0.0,
                        "status": "ok",
                        "step": "wifi",
                        "text": f"connected to {ssid}",
                    }
                )

        net.connect_wifi(ssid, password, on_line)

    def _refilter_focused(self):
        if self.focused in FILTERABLE:
            self.panes[self.focused].apply_filter()

    # ── dive / focus / layout ──

    def _sync_dive_widgets(self):
        # Show/hide is decided here; positions and opacity come from the
        # tweens in _layout_frame. A hidden pill costs nothing per frame.
        # The mode pills all leave the ring on dive (the focused one collapses
        # into the hub), so none of them should take clicks while dived.
        for slot_id, slot in self.slots.items():
            here = self.dived and slot_id == self.focused
            slot["card"].set_sensitive(not self.dived)
            for item in slot["sub_items"]:
                item["widget"].set_visible(here)
            slot["details"].set_visible(here)

    def dive(self):
        self.dived = True
        self.panes[self.focused].ensure()
        self.hub_title.set_label(self.slots[self.focused]["title"])
        self._apply_focus()
        self._sync_dive_widgets()
        self._rotate_to(self.focused)
        self._animate("dive", 1.0, theme.DIVE_MS, EASE_OUT_CUBIC)

    def undive(self):
        self.hold.cancel()
        self.hold_source = ""
        if self.filter_text:
            self.filter_text = ""
            self.entry.set_text("")
            self._refilter_focused()
        self.dived = False
        self._apply_focus()
        self._animate("dive", 0.0, theme.DIVE_MS, EASE_OUT_CUBIC)
        # Sub-items and the panel fade out over the tween; hide them after.
        self._on_settled = self._sync_dive_widgets

    def _apply_focus(self):
        for slot_id, slot in self.slots.items():
            focused = slot_id == self.focused
            body_ctx = slot["body"].get_style_context()
            dot_ctx = slot["dot"].get_style_context()
            if focused:
                body_ctx.add_class("focused")
                dot_ctx.add_class("on")
            else:
                body_ctx.remove_class("focused")
                dot_ctx.remove_class("on")

    def _rotate_to(self, slot_id):
        # Spin the ring the short way round so slot_id ends up on the right,
        # next to where the details panel opens.
        target = -90.0 * RING.index(slot_id)
        current = self.tweens["angle"]
        turns = round((current - target) / 360.0)
        self._animate("angle", target + turns * 360.0, theme.ROTATE_MS, EASE_OUT_BACK)

    def _rotate_sub_to(self, index):
        # Swing the fan so the selected item sits at 0° (right). Items keep
        # their order along the fan, so the tween is a plain linear swing.
        # Before the items have fanned out there is nothing to animate, so
        # the angle snaps and the fan-out starts from the right place.
        target = -theme.SUB_GAP_DEG * index
        if self.tweens["dive"] == 0.0:
            self.animators["sub_angle"].pause()
            self.tweens["sub_angle"] = target
            return
        self._animate("sub_angle", target, theme.ROTATE_MS, EASE_OUT_BACK)

    # ── animators ──

    def _animate(self, name, target, duration_ms, curve):
        # Retarget from wherever the value is now; the animators only carry
        # the motion — self.tweens stays the single source read by layout.
        animator = self.animators[name]
        animator.pause()
        animator.bezier_curve = curve
        animator.duration = duration_ms / 1000.0
        animator.min_value = self.tweens[name]
        animator.max_value = target
        animator.play()

    def _on_animator_value(self, animator, _pspec, name):
        # Several animators tick in the same frame; lay out once per frame,
        # not once per animator. HIGH_IDLE runs before GTK's redraw.
        self.tweens[name] = animator.value
        if not self._layout_queued:
            self._layout_queued = True
            GLib.idle_add(self._layout_once, priority=GLib.PRIORITY_HIGH_IDLE)

    def _layout_once(self):
        self._layout_queued = False
        self._layout_frame()
        return False

    def _on_animator_finished(self, finished_animator):
        for animator in self.animators.values():
            if animator is not finished_animator and animator.playing:
                return
        settled = self._on_settled
        self._on_settled = None
        if settled is not None:
            settled()

    def _layout_frame(self):
        open_t = self.tweens["open"]
        dive_t = self.tweens["dive"]
        angle = self.tweens["angle"]
        sub_angle = self.tweens["sub_angle"]
        self.set_opacity(self.tweens["fade"])

        allocation = self.get_allocation()
        focused = self.slots[self.focused]
        panel_w, panel_h = self.panes[self.focused].details_size()
        # On dive the mode pills leave the ring: the focused one collapses into
        # the hub and the rest fly outward, all fading. The sub-items (if the
        # mode has any) fan out to take their place, so the dived ring is
        # symmetric: as wide as a sub-item fan, or just the hub.
        if focused["sub_items"]:
            ring_reach = theme.RING_RADIUS + theme.SUB_WIDTH / 2
        else:
            ring_reach = theme.HUB_DIVE_SIZE / 2
        # The ring drifts left while the panel fades in beside it so the pair
        # stays centered on screen.
        full_pan = (theme.DETAILS_GAP + panel_w) / 2
        center_x = allocation.width / 2 - dive_t * full_pan
        center_y = allocation.height / 2

        hub_size = theme.HUB_SIZE + dive_t * (theme.HUB_DIVE_SIZE - theme.HUB_SIZE)
        self.hub.set_size_request(round(hub_size), round(hub_size))
        self.plane.move(
            self.hub, round(center_x - hub_size / 2), round(center_y - hub_size / 2)
        )
        self.hub_title.set_opacity(dive_t)

        for index, slot_id in enumerate(RING):
            slot = self.slots[slot_id]
            radius = theme.RING_RADIUS * open_t
            if slot_id == self.focused:
                radius *= 1.0 - dive_t
            else:
                radius += dive_t * theme.RING_DIVE_PUSH
            slot["card"].set_opacity(1.0 - dive_t)
            # 0° is the right of the ring; pills go clockwise from there.
            theta = math.radians(90.0 * index + angle)
            x = center_x + radius * math.cos(theta) - theme.SLOT_WIDTH / 2
            y = center_y + radius * math.sin(theta) - theme.SLOT_HEIGHT / 2
            self.plane.move(slot["card"], round(x), round(y))

        for index, item in enumerate(focused["sub_items"]):
            # Fan out at a fixed gap per item, swung so the selected one is on
            # the right; later items lag a little so they fan out one by one.
            theta = math.radians(theme.SUB_GAP_DEG * index + sub_angle)
            lag = index * theme.SUB_STAGGER
            progress = max(0.0, min(1.0, (dive_t - lag) / (1.0 - lag)))
            radius = theme.RING_RADIUS * progress
            x = center_x + radius * math.cos(theta) - theme.SUB_WIDTH / 2
            y = center_y + radius * math.sin(theta) - theme.SUB_HEIGHT / 2
            self.plane.move(item["widget"], round(x), round(y))
            item["widget"].set_opacity(progress)

        # The panel holds the heavy lists, so it is placed at its final spot
        # and only faded — moving it would redraw every row each frame.
        panel_x = allocation.width / 2 - full_pan + ring_reach + theme.DETAILS_GAP
        panel_y = center_y - panel_h / 2
        self.plane.move(focused["details"], round(panel_x), round(panel_y))
        focused["details"].set_opacity(dive_t)

    def _on_size_allocate(self, _widget, allocation):
        size = (allocation.width, allocation.height)
        if size == self._last_size:
            return
        self._last_size = size
        if self._open_pending:
            self._open_pending = False
            GLib.idle_add(self._start_open)
        elif self.showing:
            GLib.idle_add(self._layout_frame)

    # ── rail / command ──

    def _add_rail_entry(self, entry):
        mark = {"ok": "✓", "err": "✗"}.get(entry["status"], "·")
        line = Label(
            label=f"{entry['offset']:5.2f}s {mark} {entry['step']:<7} {entry['text']}",
            style_classes=["rail-line", "mono", entry["status"]],
            h_align="end",
        )
        line.show()
        self.rail.add(line)
        children = self.rail.get_children()
        if len(children) > theme.RAIL_MAX_LINES:
            children[0].destroy()
        self.rail.set_visible(True)

    def _render_chrome(self):
        in_text_mode = self.mode in ("command", "wifi-pass", "filter")
        self.command_bar.set_visible(in_text_mode)
        prompt_ctx = self.prompt_label.get_style_context()
        prompt_ctx.remove_class("filter")
        if self.mode == "filter":
            self.prompt_label.set_label("/")
            prompt_ctx.add_class("filter")
        elif self.mode == "wifi-pass":
            self.prompt_label.set_label("pw")
        else:
            self.prompt_label.set_label(":")
        if in_text_mode:
            self.entry.set_visibility(self.mode != "wifi-pass")
            self.entry.grab_focus()
            self.entry.set_position(-1)
        else:
            self.grab_focus()

    def _on_entry_text(self, entry, *_args):
        if self.mode != "filter":
            return
        self.filter_text = entry.get_text()
        self._refilter_focused()

    def enter_filter(self):
        if not self.dived or self.focused not in FILTERABLE:
            return
        self.mode = "filter"
        self.entry.set_text(self.filter_text)
        self._render_chrome()

    def enter_command(self):
        self.mode = "command"
        self.entry.set_text("")
        self._render_chrome()

    def back_to_normal(self):
        was_filter = self.mode == "filter"
        self.mode = "normal"
        self.wifi_ssid = ""
        self.entry.set_text("")
        if was_filter and self.filter_text:
            self.filter_text = ""
            self._refilter_focused()
        self._render_chrome()

    def run_command_line(self):
        line = self.entry.get_text().strip()
        self.mode = "normal"
        self.entry.set_text("")
        self._render_chrome()
        if line == "":
            return
        if line in ("q", "quit"):
            self.request_close()
            return
        if line == "run":
            self._add_rail_entry(
                {"offset": 0.0, "status": "err", "step": "command", "text": "run what?"}
            )
            return
        if line.startswith("run "):
            self.runlog.run(line[4:].strip())
            return
        self._add_rail_entry(
            {
                "offset": 0.0,
                "status": "err",
                "step": "command",
                "text": f"unknown: {line}",
            }
        )

    def handle_escape(self):
        if self.hold.active():
            self.hold.cancel()
            self.hold_source = ""
            return
        if self.mode in ("command", "filter", "wifi-pass"):
            self.back_to_normal()
            return
        if self.dived:
            self.undive()
            return
        self.request_close()

    def accept(self, keyval=0):
        if not self.dived:
            self.dive()
            return
        self.panes[self.focused].accept(keyval)

    def rotate_ring(self, step):
        # l brings the next pill clockwise to the right, h the previous one.
        index = (RING.index(self.focused) + step) % len(RING)
        self.focused = RING[index]
        self._apply_focus()
        self._rotate_to(self.focused)

    def move_selection(self, dx, dy):
        if self.dived:
            self.panes[self.focused].move(dx, dy)

    def jump_selection(self, to_end):
        # vim gg / G: first or last entry of the dived pane.
        if self.dived:
            self.panes[self.focused].jump(to_end)

    # ── keys ──

    def _erase(self, text, key):
        # Ctrl-w drops the last word; Ctrl-u the whole line.
        if key == Gdk.KEY_u:
            return ""
        return text.rstrip().rsplit(" ", 1)[0] if " " in text.rstrip() else ""

    def letter_of(self, event):
        if event.string and len(event.string) == 1:
            ch = event.string.lower()
            if "a" <= ch <= "z":
                return ch
        keyval = event.keyval
        if Gdk.KEY_a <= keyval <= Gdk.KEY_z:
            return chr(keyval)
        if Gdk.KEY_A <= keyval <= Gdk.KEY_Z:
            return chr(keyval + 32)
        return ""

    def on_key_press(self, _widget, event):
        if not self.showing:
            return False
        now_ms = GLib.get_monotonic_time() // 1000
        if now_ms < self._opened_ms + theme.OPEN_GUARD_MS:
            return True
        if self.hold.active() and event.keyval == self.hold_keyval:
            return True
        if (
            self.hold.active()
            and event.keyval != Gdk.KEY_Escape
            and event.keyval != self.hold_keyval
        ):
            self.hold.cancel()
            self.hold_source = ""
            self.hold_keyval = 0

        key = event.keyval
        ctrl = bool(event.state & Gdk.ModifierType.CONTROL_MASK)
        if key == Gdk.KEY_Escape or (ctrl and key == Gdk.KEY_bracketleft):
            self.handle_escape()
            return True
        # Ctrl-n / Ctrl-p walk the list like vim's completion menu, in every
        # mode, so the filter line does not have to be left to move.
        if ctrl and key in (Gdk.KEY_n, Gdk.KEY_p):
            self.move_selection(0, 1 if key == Gdk.KEY_n else -1)
            return True

        # Text modes: intercept a small allowlist (Enter, list navigation,
        # vim-style erasing) and let everything else fall through to the
        # focused Entry — typed letters can never be eaten as navigation.
        if self.mode in ("filter", "command", "wifi-pass"):
            if key in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
                if self.mode == "wifi-pass":
                    self.connect_wifi(self.wifi_ssid, self.entry.get_text())
                    self.back_to_normal()
                elif self.mode == "command":
                    self.run_command_line()
                else:
                    self.accept()
                return True
            if self.mode == "filter" and key == Gdk.KEY_Down:
                self.move_selection(0, 1)
                return True
            if self.mode == "filter" and key == Gdk.KEY_Up:
                self.move_selection(0, -1)
                return True
            if ctrl and key in (Gdk.KEY_u, Gdk.KEY_w):
                self.entry.set_text(self._erase(self.entry.get_text(), key))
                self.entry.set_position(-1)
                return True
            return False

        if key == Gdk.KEY_slash:
            if self.dived and self.focused in FILTERABLE:
                self.enter_filter()
            return True
        if key == Gdk.KEY_colon or (
            key == Gdk.KEY_semicolon and event.state & Gdk.ModifierType.SHIFT_MASK
        ):
            self.enter_command()
            return True
        if key in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            self.accept(key)
            return True

        direction = {
            Gdk.KEY_h: "h",
            Gdk.KEY_H: "h",
            Gdk.KEY_Left: "h",
            Gdk.KEY_l: "l",
            Gdk.KEY_L: "l",
            Gdk.KEY_Right: "l",
            Gdk.KEY_j: "j",
            Gdk.KEY_J: "j",
            Gdk.KEY_Down: "j",
            Gdk.KEY_k: "k",
            Gdk.KEY_K: "k",
            Gdk.KEY_Up: "k",
        }.get(key)
        if direction is not None:
            if self.dived:
                dx = {"h": -1, "l": 1}.get(direction, 0)
                dy = {"k": -1, "j": 1}.get(direction, 0)
                self.move_selection(dx, dy)
            elif direction == "h":
                self.rotate_ring(-1)
            elif direction == "l":
                self.rotate_ring(1)
            elif direction == "j":
                self.dive()
            return True

        if key == Gdk.KEY_G:
            self.jump_selection(to_end=True)
            return True
        if key == Gdk.KEY_g:
            # vim "gg": two bare g presses in a row jump to the first entry.
            if self.pending_g:
                self.pending_g = False
                self.jump_selection(to_end=False)
            else:
                self.pending_g = True
            return True
        self.pending_g = False

        letter = self.letter_of(event)
        if letter == "":
            return True

        if letter == "q" and not self.dived:
            self.request_close()
            return True

        if letter in PREFIX:
            self.focused = PREFIX[letter]
            self.dive()
            return True

        # Panes with lettered sub-items (power actions, network sub-modes)
        # get first crack at the remaining letters.
        pane = self.panes[self.focused]
        if hasattr(pane, "on_letter") and pane.on_letter(letter, event.keyval):
            return True

        return True

    def on_scroll(self, _widget, event):
        # Wheel spins the mode ring while nothing is dived; inside a pane the
        # scrolled lists keep handling their own wheel events.
        if not self.showing or self.dived or self.mode != "normal":
            return False
        if event.direction == Gdk.ScrollDirection.UP:
            self.rotate_ring(-1)
            return True
        if event.direction == Gdk.ScrollDirection.DOWN:
            self.rotate_ring(1)
            return True
        if event.direction == Gdk.ScrollDirection.SMOOTH:
            if event.delta_y < -0.2:
                self.rotate_ring(-1)
                return True
            if event.delta_y > 0.2:
                self.rotate_ring(1)
                return True
        return False

    def on_key_release(self, _widget, event):
        if not self.showing:
            return False
        if self.hold_source == "key" and event.keyval == self.hold_keyval:
            if self.hold.active():
                self.hold.cancel()
            self.hold_source = ""
            self.hold_keyval = 0
            return True
        return False
