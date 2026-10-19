# Process entry: Fabric ring overlay.
# The QuickShell bar stays in the other process until this one grows a bar.
# Mod+Space talks to this process via `fabric-toggle` (DBus InvokeAction).
import os
import signal
import subprocess
import time
from pathlib import Path

import theme
from fabric import Application
from fabric.utils import get_relative_path, monitor_file
from gi.repository import GLib
from overlay import Overlay

DBUS_NAME = "org.Fabric.fabric.shell"


def css_vars():
    return f"""
:vars {{
  --card: {theme.BASE00};
  --ink: {theme.BASE05};
  --ink-soft: {theme.BASE04};
  --hi: {theme.BASE09};
  --success: {theme.BASE0B};
  --danger: {theme.BASE08};
}}
"""


def release_existing():
    # A second fabric-shell cannot take the DBus name; kill the previous
    # owner so a relaunch is a clean process instead of a fight.
    probe = subprocess.run(
        [
            "gdbus",
            "call",
            "--session",
            "--dest",
            "org.freedesktop.DBus",
            "--object-path",
            "/org/freedesktop/DBus",
            "--method",
            "org.freedesktop.DBus.GetConnectionUnixProcessID",
            DBUS_NAME,
        ],
        capture_output=True,
        text=True,
        timeout=2,
    )
    if probe.returncode != 0:
        return
    digits = "".join(ch if ch.isdigit() else " " for ch in probe.stdout).split()
    if not digits:
        return
    pid = int(digits[-1])
    if pid == os.getpid():
        return
    try:
        os.kill(pid, signal.SIGTERM)
    except OSError:
        return
    for _ in range(25):
        owned = subprocess.run(
            [
                "gdbus",
                "call",
                "--session",
                "--dest",
                "org.freedesktop.DBus",
                "--object-path",
                "/org/freedesktop/DBus",
                "--method",
                "org.freedesktop.DBus.NameHasOwner",
                DBUS_NAME,
            ],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if "false" in owned.stdout:
            return
        time.sleep(0.04)


if __name__ == "__main__":
    release_existing()
    overlay = Overlay()

    @Application.action()
    def toggle():
        overlay.toggle()

    @Application.action()
    def quit():
        overlay.hide()
        GLib.idle_add(os._exit, 0)

    app = Application("shell", overlay)
    style_path = get_relative_path("./style.css")

    def apply_style(*_args):
        app.set_stylesheet_from_string(css_vars() + Path(style_path).read_text())

    apply_style()
    style_monitor = monitor_file(style_path)
    style_monitor.connect("changed", apply_style)
    app.run()
