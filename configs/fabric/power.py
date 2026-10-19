# Power satellite actions. Lock / suspend / logout run immediately.
# Reboot and shutdown require a 2-second hold; the overlay draws the fill.
import theme
from fabric.utils import exec_shell_command_async
from gi.repository import GLib

HOLD_ACTIONS = {"reboot", "shutdown"}

ACTIONS = [
    {"key": "l", "id": "lock", "label": "Lock", "color": "keyword"},
    {"key": "u", "id": "suspend", "label": "Suspend", "color": "warning"},
    {"key": "o", "id": "logout", "label": "Logout", "color": "accent"},
    {"key": "r", "id": "reboot", "label": "Reboot", "color": "warm"},
    {"key": "d", "id": "shutdown", "label": "Shutdown", "color": "danger"},
]

COMMANDS = {
    "lock": ["loginctl", "lock-session"],
    "suspend": ["systemctl", "suspend"],
    "logout": ["niri", "msg", "action", "quit"],
    "reboot": ["systemctl", "reboot"],
    "shutdown": ["systemctl", "poweroff"],
}


def run_action(action_id):
    command = COMMANDS.get(action_id)
    if command:
        exec_shell_command_async(command)


class Hold:
    def __init__(self, on_progress, on_complete):
        self.on_progress = on_progress
        self.on_complete = on_complete
        self.action_id = ""
        self._timer = 0
        self._started = 0

    def begin(self, action_id):
        self.cancel()
        self.action_id = action_id
        self._started = GLib.get_monotonic_time()
        self._timer = GLib.timeout_add(16, self._tick)
        self.on_progress(action_id, 0.0)

    def cancel(self):
        if self._timer:
            GLib.source_remove(self._timer)
            self._timer = 0
        previous = self.action_id
        self.action_id = ""
        if previous:
            self.on_progress(previous, 0.0)

    def active(self):
        return self.action_id != ""

    def _tick(self):
        elapsed_ms = (GLib.get_monotonic_time() - self._started) / 1000.0
        progress = min(1.0, elapsed_ms / theme.HOLD_MS)
        self.on_progress(self.action_id, progress)
        if progress >= 1.0:
            action_id = self.action_id
            self._timer = 0
            self.action_id = ""
            self.on_complete(action_id)
            return False
        return True
