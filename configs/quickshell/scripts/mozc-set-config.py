#!/usr/bin/env python3
# Mozc config1.db field setter.
#
# Reads ~/.config/mozc/config1.db, replaces specified boolean/enum fields by
# stripping their existing tags and appending new tag+value bytes, then writes
# atomically and kills mozc_server so fcitx5 respawns it with fresh config.
#
# Why: mozc has no CLI config command. The Config protobuf is the only knob.
# Field numbers verified against google/mozc src/protocol/config.proto.
#
# Usage: mozc-set-config.py field=value [field=value ...]

import os
import sys
import subprocess
from pathlib import Path

# field_name -> (field_number, wire_type). wire_type 0 = varint (bool/enum).
FIELDS = {
    "use_auto_conversion":       (61,  0),
    "incognito_mode":            (20,  0),
    "presentation_mode":         (23,  0),
    "history_learning_level":    (50,  0),
    "use_history_suggest":       (100, 0),
    "use_dictionary_suggest":    (101, 0),
    "use_realtime_conversion":   (102, 0),
}


def encode_varint(n: int) -> bytes:
    out = bytearray()
    while n > 0x7F:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    out.append(n & 0x7F)
    return bytes(out)


def decode_varint(data: bytes, offset: int):
    result, shift = 0, 0
    while True:
        b = data[offset]
        offset += 1
        result |= (b & 0x7F) << shift
        if not (b & 0x80):
            return result, offset
        shift += 7


def parse_proto(data: bytes):
    # Returns list of (field_num, raw_tag_bytes, raw_body_bytes) preserving order.
    fields, offset = [], 0
    while offset < len(data):
        tag_start = offset
        tag, offset = decode_varint(data, offset)
        field_num, wire_type = tag >> 3, tag & 7
        tag_bytes = data[tag_start:offset]
        if wire_type == 0:
            body_start = offset
            _, offset = decode_varint(data, offset)
            body = data[body_start:offset]
        elif wire_type == 2:
            len_start = offset
            length, offset = decode_varint(data, offset)
            body = data[len_start:offset] + data[offset:offset + length]
            offset += length
        elif wire_type == 1:
            body = data[offset:offset + 8]; offset += 8
        elif wire_type == 5:
            body = data[offset:offset + 4]; offset += 4
        else:
            raise ValueError(f"unsupported wire type {wire_type} at offset {tag_start}")
        fields.append((field_num, tag_bytes, body))
    return fields


def parse_value(name: str, raw: str) -> int:
    if name == "history_learning_level":
        return int(raw)
    return 1 if raw.lower() in ("true", "1", "on", "yes") else 0


def main():
    if len(sys.argv) < 2:
        print(f"usage: {sys.argv[0]} field=value [field=value ...]", file=sys.stderr)
        sys.exit(2)

    updates = {}
    for arg in sys.argv[1:]:
        name, _, val = arg.partition("=")
        if name not in FIELDS:
            print(f"unknown field: {name}", file=sys.stderr)
            sys.exit(2)
        updates[name] = parse_value(name, val)

    cfg = Path.home() / ".config" / "mozc" / "config1.db"
    cfg.parent.mkdir(parents=True, exist_ok=True)

    data = cfg.read_bytes() if cfg.exists() else b""
    try:
        fields = parse_proto(data) if data else []
    except Exception as exc:
        print(f"warning: existing config unparseable ({exc}), rewriting", file=sys.stderr)
        fields = []

    drop = {FIELDS[n][0] for n in updates}
    fields = [(num, tag, body) for (num, tag, body) in fields if num not in drop]

    for name, value in updates.items():
        num, wire = FIELDS[name]
        fields.append((num, encode_varint((num << 3) | wire), encode_varint(value)))

    out = b"".join(tag + body for (_, tag, body) in fields)

    tmp = cfg.with_suffix(".db.tmp")
    tmp.write_bytes(out)
    os.chmod(tmp, 0o600)
    tmp.replace(cfg)

    # Mozc reloads config on next IME session; killing the server forces an
    # immediate respawn with fresh settings on the next keystroke.
    subprocess.run(["pkill", "-x", "mozc_server"], check=False)
    print("ok")


if __name__ == "__main__":
    main()
