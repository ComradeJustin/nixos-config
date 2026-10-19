# Power pane: session actions on the fan; reboot/shutdown need a 2s hold.
# The Hold timer itself lives on the overlay (its key handling is global).
import power
import theme
from fabric.widgets.box import Box
from fabric.widgets.label import Label
from panes import header_label, make_sub_pill


class PowerPane:
    def __init__(self, shell):
        self.shell = shell
        self.index = 0
        self.subs = {}

    def details_size(self):
        return theme.DETAILS_WIDTH, theme.DETAILS_POWER_HEIGHT

    def build_subs(self):
        items = []
        for index, action in enumerate(power.ACTIONS):
            item = make_sub_pill(
                action["key"],
                action["label"],
                lambda *_a, i=index, act=action: self._on_pointer_press(i, act),
            )
            item["widget"].connect(
                "button-release-event",
                lambda *_a: self._on_pointer_release(),
            )
            self.subs[action["id"]] = item
            items.append(item)
        return items

    def build_details(self):
        self.header = header_label("Lock")
        self.dot = Box(style_classes="detail-dot")
        self.status = Label(
            label="press enter",
            style_classes="detail-status",
            h_align="start",
        )
        status_row = Box(orientation="h", spacing=10, children=[self.dot, self.status])
        return Box(
            orientation="v",
            spacing=10,
            children=[self.header, Box(style_classes="detail-rule"), status_row],
        )

    def ensure(self):
        self.index = 0
        self.highlight()

    def _on_pointer_press(self, index, action):
        self.index = index
        self.highlight()
        self.activate(action, source="pointer")
        return True

    def _on_pointer_release(self):
        if self.shell.hold_source == "pointer":
            self.shell.hold.cancel()
            self.shell.hold_source = ""
        return True

    def highlight(self):
        for index, action in enumerate(power.ACTIONS):
            item = self.subs[action["id"]]
            ctx = item["body"].get_style_context()
            if index == self.index:
                ctx.add_class("selected")
                item["dot"].get_style_context().add_class("on")
            else:
                ctx.remove_class("selected")
                item["dot"].get_style_context().remove_class("on")
        self.shell._rotate_sub_to(self.index)
        action = power.ACTIONS[self.index]
        self.header.set_label(action["label"])
        if action["id"] in power.HOLD_ACTIONS:
            self.status.set_label("hold 2 seconds")
            self.dot.get_style_context().add_class("on")
        else:
            self.status.set_label("press enter")
            self.dot.get_style_context().remove_class("on")

    def activate(self, action, source="key"):
        if action["id"] in power.HOLD_ACTIONS:
            self.shell.hold_source = source
            self.shell.hold.begin(action["id"])
            return
        power.run_action(action["id"])
        self.shell.request_close()

    def set_hold_progress(self, action_id, progress):
        # Paint the progress as a hard-stop gradient on the pill's own
        # background: the pill's border-radius clips it, so no morphing.
        item = self.subs.get(action_id)
        if item is None:
            return
        if progress <= 0.0:
            item["body"].set_style("")
            return
        stop = progress * 100.0
        item["body"].set_style(
            f"background-image: linear-gradient(to right,"
            f" alpha({theme.BASE09}, 0.55) {stop:.1f}%,"
            f" alpha({theme.BASE09}, 0.0) {stop:.1f}%);"
        )

    def move(self, dx, dy):
        # The fan keeps swinging: selection wraps around.
        step = dx if dx != 0 else dy
        self.index = (self.index + step) % len(power.ACTIONS)
        self.highlight()

    def jump(self, to_end):
        self.index = len(power.ACTIONS) - 1 if to_end else 0
        self.highlight()

    def accept(self, keyval):
        # Remember which key started a hold so releasing it cancels;
        # without this a tap of Enter on reboot would fire 2s later.
        action = power.ACTIONS[self.index]
        if action["id"] in power.HOLD_ACTIONS:
            self.shell.hold_keyval = keyval
        self.activate(action, source="key")

    def on_letter(self, letter, keyval):
        for index, action in enumerate(power.ACTIONS):
            if action["key"] == letter:
                if not self.shell.dived:
                    self.shell.dive()
                self.index = index
                self.highlight()
                if action["id"] in power.HOLD_ACTIONS:
                    self.shell.hold_keyval = keyval
                self.activate(action, source="key")
                return True
        return False
