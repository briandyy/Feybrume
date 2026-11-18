#!/usr/bin/env python3
"""Generate the Luau preset data from the theme registry."""

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "design/themes.json"
TARGET = ROOT / "src/engine/Presets.luau"


def luau(value, depth=0):
    if isinstance(value, str):
        if any(ord(char) < 32 for char in value):
            raise ValueError("Preset strings must contain printable characters")
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return json.dumps(value, allow_nan=False)
    if isinstance(value, (list, dict)):
        items = (f"[{luau(key)}] = {luau(item, depth + 1)}" for key, item in value.items()) if isinstance(value, dict) \
            else (luau(item, depth + 1) for item in value)
        indent = "    " * depth
        return "{\n" + "".join(indent + "    " + item + ",\n" for item in items) + indent + "}"
    raise TypeError(f"Unsupported data: {value!r}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rows = json.loads(SOURCE.read_text(encoding="utf-8"))
    records = [{k: v for k, v in row.items() if k not in {"testCase", "status", "robloxStatus", "brief"}} for row in rows]
    expected = "-- Generated from design/themes.json.\nreturn " + luau(records) + "\n"
    if args.check:
        if TARGET.read_text(encoding="utf-8") != expected:
            parser.exit(1, "Preset data is out of date\n")
    else:
        TARGET.write_text(expected, encoding="utf-8")


if __name__ == "__main__":
    main()
