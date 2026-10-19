# Lifecycle log for `:run <query>`: parse -> resolve -> spawn -> window.
# The last step follows a shared `niri msg -j event-stream` Fabricator.
# Entries go to the overlay's corner rail, which stays hidden until the
# first line.
import json
import shutil
import time

import apps
from fabric.core.fabricator import Fabricator
from fabric.utils import exec_shell_command_async
from gi.repository import GLib

WINDOW_TIMEOUT_SECONDS = 15


def best_app(app_items, query):
    needle = query.lower()
    best = None
    best_score = 0
    for app in app_items:
        score = apps.score_app(needle, app)
        if score > best_score:
            best_score = score
            best = app
    return best


class RunLog:
    def __init__(self, on_entry):
        self.on_entry = on_entry
        self.entries = []
        self.app_cache = []
        self.stream = None
        self.known_window_ids = set()
        self.watches = []
        self.last_window_id = 0

    def run(self, query):
        started = time.monotonic()
        self._emit(started, "pending", "parse", f"run {query}")
        if not self.app_cache:
            self.app_cache = apps.list_apps()
        app = best_app(self.app_cache, query)
        if app is not None:
            name = apps.shown_name(app)
            shown = apps.binary_of(app) or "desktop entry"
            self._emit(started, "ok", "resolve", f"{query} → {name} ({shown})")
            app.launch()
            self._emit(started, "ok", "spawn", "launched via desktop entry")
            tokens = [apps.binary_of(app), name]
        else:
            words = query.split()
            binary = shutil.which(words[0]) if words else None
            if binary is None:
                self._emit(started, "err", "resolve", f"nothing matches '{query}'")
                return
            self._emit(started, "ok", "resolve", f"{query} → {binary}")
            exec_shell_command_async(words)
            self._emit(started, "ok", "spawn", "process started")
            tokens = [words[0]]
        self._watch_window(started, tokens)

    def _emit(self, started, status, step, text):
        offset = time.monotonic() - started
        entry = {"offset": offset, "status": status, "step": step, "text": text}
        self.entries.append(entry)
        self.entries = self.entries[-40:]
        self.on_entry(entry)

    def _watch_window(self, started, tokens):
        watch = {
            "tokens": [token.lower() for token in tokens if token],
            "started": started,
            "done": False,
        }
        self.watches.append(watch)
        if self.stream is None:
            self.stream = Fabricator(
                poll_from="niri msg -j event-stream",
                stream=True,
                on_changed=lambda _fabricator, line: self._handle_event(line),
            )
        GLib.timeout_add_seconds(WINDOW_TIMEOUT_SECONDS, self._timeout_watch, watch)

    def _timeout_watch(self, watch):
        if not watch["done"]:
            watch["done"] = True
            self._emit(
                watch["started"],
                "err",
                "window",
                f"no window after {WINDOW_TIMEOUT_SECONDS}s",
            )
        return False

    def _handle_event(self, line):
        try:
            event = json.loads(line)
        except ValueError:
            return
        snapshot = event.get("WindowsChanged")
        if snapshot is not None:
            for window in snapshot.get("windows", []):
                self.known_window_ids.add(window.get("id"))
            return
        changed = event.get("WindowOpenedOrChanged")
        if changed is None:
            return
        window = changed.get("window", {})
        window_id = window.get("id")
        if window_id in self.known_window_ids:
            return
        self.known_window_ids.add(window_id)
        hay = ((window.get("app_id") or "") + " " + (window.get("title") or "")).lower()
        for watch in self.watches:
            if watch["done"]:
                continue
            if any(token in hay for token in watch["tokens"]):
                watch["done"] = True
                self.last_window_id = window_id
                elapsed = time.monotonic() - watch["started"]
                title = window.get("title") or window.get("app_id") or "window"
                self._emit(
                    watch["started"],
                    "ok",
                    "window",
                    f'"{title}" appeared ({elapsed:.1f}s)',
                )
        self.watches = [watch for watch in self.watches if not watch["done"]]
