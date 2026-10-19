# Local wallpapers in assets/wallpapers. Thumbs live in ~/.cache/fabric.
import hashlib
import os
from pathlib import Path

import gi

gi.require_version("GdkPixbuf", "2.0")
from fabric.utils import exec_shell_command_async
from gi.repository import GdkPixbuf, GLib
from theme import WALLPAPER_DIR, WALLPAPER_THUMB_HEIGHT, WALLPAPER_THUMB_WIDTH

THUMB_DIR = os.path.join(
    os.path.expanduser("~"), ".cache", "fabric", "wallpaper-thumbs"
)
EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".gif"}
THUMB_WIDTH = WALLPAPER_THUMB_WIDTH
THUMB_HEIGHT = WALLPAPER_THUMB_HEIGHT


def list_wallpapers():
    folder = Path(WALLPAPER_DIR)
    if not folder.is_dir():
        return []
    os.makedirs(THUMB_DIR, exist_ok=True)
    items = []
    for path in sorted(folder.iterdir()):
        if not path.is_file():
            continue
        if path.suffix.lower() not in EXTENSIONS:
            continue
        items.append(
            {
                "path": str(path),
                "name": path.name,
                "thumb": thumb_for(path),
            }
        )
    return items


def thumb_for(path):
    key = f"{path}:cover{THUMB_WIDTH}x{THUMB_HEIGHT}"
    digest = hashlib.sha256(key.encode()).hexdigest()[:16]
    thumb = os.path.join(THUMB_DIR, digest + ".jpg")
    source_mtime = path.stat().st_mtime
    if os.path.isfile(thumb) and os.path.getmtime(thumb) >= source_mtime:
        return thumb
    file_format, width, height = GdkPixbuf.Pixbuf.get_file_info(str(path))
    if file_format is None or width <= 0 or height <= 0:
        return str(path)
    # Scale to cover the tile, then center-crop: uniform thumbs, no distortion.
    scale = max(THUMB_WIDTH / width, THUMB_HEIGHT / height)
    scaled_width = max(THUMB_WIDTH, round(width * scale))
    scaled_height = max(THUMB_HEIGHT, round(height * scale))
    try:
        pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
            str(path), scaled_width, scaled_height, False
        )
    except GLib.Error:
        # Animated GIFs refuse partially-loaded scaling; use the first frame.
        try:
            animation = GdkPixbuf.PixbufAnimation.new_from_file(str(path))
            pixbuf = animation.get_static_image().scale_simple(
                scaled_width, scaled_height, GdkPixbuf.InterpType.BILINEAR
            )
        except GLib.Error:
            return str(path)
    if pixbuf is None:
        return str(path)
    cropped = pixbuf.new_subpixbuf(
        (scaled_width - THUMB_WIDTH) // 2,
        (scaled_height - THUMB_HEIGHT) // 2,
        THUMB_WIDTH,
        THUMB_HEIGHT,
    )
    try:
        cropped.savev(thumb, "jpeg", ["quality"], ["80"])
    except GLib.Error:
        return str(path)
    return thumb


def filter_wallpapers(items, query):
    needle = query.lower()
    if needle == "":
        return items
    matches = []
    for item in items:
        if needle in item["name"].lower():
            matches.append(item)
    return matches


def apply_wallpaper(path):
    exec_shell_command_async(
        [
            "awww",
            "img",
            path,
            "--transition-type",
            "wipe",
            "--transition-duration",
            "1",
        ]
    )
