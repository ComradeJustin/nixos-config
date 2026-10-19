# Network pane: wifi / bluetooth / volume / output sub-modes on the fan,
# each rendering its rows into the shared details panel.
import settings as net
import theme
from fabric.utils import exec_shell_command_async
from fabric.widgets.box import Box
from fabric.widgets.button import Button
from fabric.widgets.label import Label
from fabric.widgets.scale import Scale
from fabric.widgets.scrolledwindow import ScrolledWindow
from gi.repository import GLib
from panes import header_label, make_sub_pill, scroll_into_view


class NetworkPane:
    def __init__(self, shell):
        self.shell = shell
        self.sub = "wifi"
        self.index = 0
        self.rows = []
        self.sub_items = []
        self.wifi_state = None
        self.wifi_fetching = False
        self.backends = net.Backends()

    def details_size(self):
        return theme.DETAILS_WIDTH, theme.DETAILS_SETTINGS_HEIGHT

    def build_subs(self):
        for spec in net.SUBS:
            item = make_sub_pill(
                spec["key"],
                spec["label"],
                lambda *_a, sub=spec["id"]: self.set_sub(sub),
            )
            item["sub_id"] = spec["id"]
            self.sub_items.append(item)
        return self.sub_items

    def build_details(self):
        self.header = header_label("Wi-Fi")
        self.details = Box(orientation="v", spacing=4)
        self.scroller = ScrolledWindow(
            child=self.details,
            min_content_size=(-1, 240),
            max_content_size=(-1, 240),
            h_scrollbar_policy="never",
            v_scrollbar_policy="automatic",
        )
        self.volume_scale = Scale(
            min_value=0, max_value=100, value=0, h_expand=True, draw_value=False
        )
        self.volume_scale.connect("change-value", self._on_volume_scale)
        self.volume_label = Label(style_classes="mute", label="")
        return Box(
            orientation="v",
            spacing=8,
            children=[
                self.header,
                Box(style_classes="detail-rule"),
                self.scroller,
            ],
        )

    def ensure(self):
        self._highlight_subs()
        if self.sub == "wifi":
            self.scan_wifi()
        self.refresh()
        for item in net.SUBS:
            if item["id"] == self.sub:
                self.header.set_label(item["label"])

    def set_sub(self, sub_id):
        self.sub = sub_id
        self.index = 0
        title = "Network"
        for item in net.SUBS:
            if item["id"] == sub_id:
                title = item["label"]
        self.header.set_label(title)
        self._highlight_subs()
        if sub_id == "wifi":
            self.scan_wifi()
        self.refresh()
        return True

    def _highlight_subs(self):
        for index, item in enumerate(self.sub_items):
            ctx = item["body"].get_style_context()
            if item["sub_id"] == self.sub:
                ctx.add_class("selected")
                item["dot"].get_style_context().add_class("on")
                self.shell._rotate_sub_to(index)
            else:
                ctx.remove_class("selected")
                item["dot"].get_style_context().remove_class("on")

    def step_sub(self, step):
        # h / l swing the fan: wifi → bluetooth → volume → output.
        ids = [spec["id"] for spec in net.SUBS]
        index = (ids.index(self.sub) + step) % len(ids)
        self.set_sub(ids[index])

    def refresh(self):
        keep = {self.volume_scale, self.volume_label}
        for child in list(self.details.get_children()):
            self.details.remove(child)
            if child not in keep:
                child.destroy()
        self.rows = []
        if self.sub == "wifi":
            widgets = self._wifi_rows()
        elif self.sub == "bluetooth":
            widgets = self._bluetooth_rows()
        elif self.sub == "volume":
            widgets = self._volume_rows()
        else:
            widgets = self._output_rows()
        for widget in widgets:
            self.details.add(widget)
        self.details.show_all()
        self._highlight_rows()
        return False

    def scan_wifi(self):
        if self.wifi_fetching:
            return
        self.wifi_fetching = True
        net.fetch_wifi_async(self._on_wifi_fetched)

    def _on_wifi_fetched(self, enabled, networks):
        self.wifi_fetching = False
        self.wifi_state = (enabled, networks)
        here = self.shell.dived and self.shell.focused == "network"
        if here and self.sub == "wifi":
            self.refresh()
        return False

    def _forget_wifi(self):
        self.wifi_state = None
        self.scan_wifi()
        self.refresh()
        return False

    def _wifi_rows(self):
        if self.wifi_state is None:
            return [Label(style_classes="empty", label="Scanning…")]
        enabled, networks = self.wifi_state
        toggle = self._action_row(
            "Enable Wi-Fi" if not enabled else "Disable Wi-Fi",
            lambda: (
                net.set_wifi_enabled(not enabled),
                # The radio takes a moment to flip; rescan after it settles.
                GLib.timeout_add(1500, self._forget_wifi),
            ),
        )
        rows = [toggle]
        if not enabled:
            return rows
        if not networks:
            rows.append(Label(style_classes="empty", label="No networks"))
            return rows
        for network in networks:
            mark = "✓ " if network["active"] else ""
            lock = " ⚿" if network["secured"] else ""
            label = f"{mark}{network['ssid']}  {network['signal']}%{lock}"
            rows.append(
                self._action_row(
                    label,
                    lambda ssid=network["ssid"], secured=network["secured"]: (
                        self._wifi_pick(ssid, secured)
                    ),
                )
            )
        return rows

    def _wifi_pick(self, ssid, secured):
        if secured:
            self.shell.begin_wifi_password(ssid)
            return
        self.shell.connect_wifi(ssid)

    def _bluetooth_rows(self):
        client = self.backends.ensure_bluetooth()
        if client is None:
            return [
                Label(
                    style_classes="empty",
                    label=self.backends.bluetooth_error or "Bluetooth unavailable",
                )
            ]
        toggle = self._action_row(
            "Disable Bluetooth" if client.powered else "Enable Bluetooth",
            lambda: (
                client.toggle_power(),
                GLib.timeout_add(400, self.refresh),
            ),
        )
        scan = self._action_row(
            "Stop scan" if client.scanning else "Scan",
            lambda: (
                client.toggle_scan(),
                GLib.timeout_add(400, self.refresh),
            ),
        )
        rows = [toggle, scan]
        for device in client.devices:
            mark = "✓ " if device.connected else ("· " if device.paired else "+ ")
            rows.append(
                self._action_row(
                    mark + (device.name or device.address),
                    lambda dev=device: (
                        dev.connect_device(not dev.connected),
                        GLib.timeout_add(600, self.refresh),
                    ),
                )
            )
        if len(rows) == 2:
            rows.append(Label(style_classes="empty", label="No devices"))
        return rows

    def _volume_rows(self):
        audio = self.backends.ensure_audio()
        if audio is None:
            return [
                Label(
                    style_classes="empty",
                    label=self.backends.audio_error or "Audio unavailable",
                )
            ]
        speaker = audio.speaker
        volume = int(speaker.volume) if speaker else 0
        muted = speaker.muted if speaker else False
        self.volume_scale.set_value(volume)
        self.volume_label.set_label(f"{volume}%{'  muted' if muted else ''}")
        mute_row = self._action_row(
            "Unmute" if muted else "Mute",
            lambda: self._toggle_mute(),
        )
        return [
            mute_row,
            self.volume_label,
            self.volume_scale,
        ]

    def _output_rows(self):
        audio = self.backends.ensure_audio()
        if audio is None:
            return [
                Label(
                    style_classes="empty",
                    label=self.backends.audio_error or "Audio unavailable",
                )
            ]
        rows = []
        for stream in audio.speakers:
            mark = "✓ " if stream is audio.speaker else ""
            rows.append(
                self._action_row(
                    mark + (stream.description or stream.name),
                    lambda name=stream.name: exec_shell_command_async(
                        ["pactl", "set-default-sink", name]
                    ),
                )
            )
        if not rows:
            rows.append(Label(style_classes="empty", label="No outputs"))
        return rows

    def _action_row(self, text, on_click):
        label = Label(
            label=text,
            style_classes="action-label",
            h_align="start",
            h_expand=True,
            ellipsization="end",
        )
        row = Button(
            style_classes="action",
            child=label,
            h_expand=True,
            on_clicked=lambda *_a: on_click(),
        )
        row.set_can_focus(False)
        self.rows.append(
            {
                "widget": row,
                "on_click": on_click,
            }
        )
        return row

    def _highlight_rows(self):
        if self.index >= len(self.rows):
            self.index = max(0, len(self.rows) - 1)
        for index, row in enumerate(self.rows):
            ctx = row["widget"].get_style_context()
            if index == self.index:
                ctx.add_class("selected")
                scroll_into_view(self.scroller, self.details, row["widget"])
            else:
                ctx.remove_class("selected")

    def _toggle_mute(self):
        audio = self.backends.ensure_audio()
        if audio and audio.speaker:
            audio.speaker.muted = not audio.speaker.muted
        self.refresh()

    def _on_volume_scale(self, _scale, _scroll, value):
        audio = self.backends.ensure_audio()
        if audio and audio.speaker:
            audio.speaker.volume = value
            self.volume_label.set_label(f"{int(value)}%")
        return False

    def nudge_volume(self, delta):
        audio = self.backends.ensure_audio()
        if audio is None or audio.speaker is None:
            return
        next_value = max(0, min(100, audio.speaker.volume + delta))
        audio.speaker.volume = next_value
        self.volume_scale.set_value(next_value)
        self.volume_label.set_label(f"{int(next_value)}%")

    def move(self, dx, dy):
        if dx != 0:
            self.step_sub(dx)
            return
        if self.sub == "volume":
            self.nudge_volume(-5 if dy > 0 else 5)
            return
        next_index = self.index + dy
        if next_index < 0 or next_index >= len(self.rows):
            return
        self.index = next_index
        self._highlight_rows()

    def jump(self, to_end):
        if self.rows:
            self.index = len(self.rows) - 1 if to_end else 0
            self._highlight_rows()

    def accept(self, _keyval):
        if not self.rows:
            return
        if self.index < 0 or self.index >= len(self.rows):
            return
        self.rows[self.index]["on_click"]()

    def on_letter(self, letter, _keyval):
        for item in net.SUBS:
            if item["key"] == letter:
                if not self.shell.dived:
                    self.shell.dive()
                self.set_sub(item["id"])
                return True
        return False
