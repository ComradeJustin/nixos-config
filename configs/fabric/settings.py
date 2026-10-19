# East satellite backends: nmcli wifi, Fabric Bluetooth, Fabric Audio.
# Wifi calls go through fabric's async subprocess helpers so the GTK thread
# (and the dive animation) never waits on nmcli.
from fabric.core.fabricator import Fabricator
from fabric.utils import exec_shell_command_async
from gi.repository import GLib

SUBS = [
    {"key": "i", "id": "wifi", "label": "Wi-Fi"},
    {"key": "b", "id": "bluetooth", "label": "Bluetooth"},
    {"key": "a", "id": "volume", "label": "Volume"},
    {"key": "o", "id": "output", "label": "Output"},
]


def set_wifi_enabled(enabled):
    exec_shell_command_async(["nmcli", "radio", "wifi", "on" if enabled else "off"])


def connect_wifi(ssid, password="", on_line=None):
    # on_line receives each nmcli output line, so callers can surface
    # success or failure instead of connecting silently.
    args = ["nmcli", "dev", "wifi", "connect", ssid]
    if password:
        args.extend(["password", password])
    exec_shell_command_async(args, on_line)


def fetch_wifi_async(on_done):
    # Two async steps: read the radio state, then stream the network list.
    # on_done(enabled, networks) runs on the main loop either way.
    def on_radio_line(line):
        if line.strip().lower() != "enabled":
            on_done(False, [])
            return
        lines = []
        Fabricator(
            poll_from="nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list",
            stream=True,
            on_changed=lambda _fabricator, line: lines.append(line),
            on_polling_done=lambda _fabricator, _last: on_done(
                True, parse_networks(lines)
            ),
        )

    try:
        exec_shell_command_async("nmcli -t -f WIFI general", on_radio_line)
    except GLib.Error:
        on_done(False, [])


def parse_networks(lines):
    networks = []
    seen = set()
    for line in lines:
        parts = line.split(":")
        if len(parts) < 3:
            continue
        ssid = parts[1]
        if ssid == "" or ssid in seen:
            continue
        seen.add(ssid)
        security = ":".join(parts[3:]) if len(parts) > 3 else ""
        networks.append(
            {
                "active": parts[0] == "yes",
                "ssid": ssid,
                "signal": parts[2],
                "secured": security not in ("", "--"),
            }
        )
    return networks


class Backends:
    def __init__(self):
        self.audio = None
        self.bluetooth = None
        self.audio_error = ""
        self.bluetooth_error = ""

    def ensure_audio(self):
        if self.audio is not None or self.audio_error:
            return self.audio
        try:
            from fabric.audio import Audio

            self.audio = Audio()
        except ImportError as error:
            self.audio_error = str(error)
        return self.audio

    def ensure_bluetooth(self):
        if self.bluetooth is not None or self.bluetooth_error:
            return self.bluetooth
        try:
            from fabric.bluetooth import BluetoothClient

            self.bluetooth = BluetoothClient()
        except ImportError as error:
            self.bluetooth_error = str(error)
        return self.bluetooth
