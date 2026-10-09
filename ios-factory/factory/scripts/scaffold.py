#!/usr/bin/env python3
"""Render the starter app (factory/templates/app/) into a repo. Used by /factory-new.

  python3 -I factory/scripts/scaffold.py <values.json> [--dest <repo>] [--dry-run]

values.json:
  {"app": "HabitLoop",                 Swift identifier: target, scheme, folder names
   "display_name": "Habit Loop",       home-screen name
   "bundle_id": "com.example.HabitLoop",
   "team_id": "",                      Apple team id; "" builds for the simulator only
   "ios_min": "17.0",
   "devices": "iphone"}                "iphone" or "universal"

Placeholders {{APP}}, {{DISPLAY_NAME}}, {{BUNDLE_ID}}, {{TEAM_ID}}, {{IOS_MIN}},
{{DEVICE_FAMILY}} are replaced in contents, and __APP__ in paths. A line ending in
"# only:universal" or "# only:iphone" is kept (without the marker) only for those
devices. Existing files are never overwritten: they're listed as skipped.
gitignore.append is merged into .gitignore (only the lines it doesn't have yet).
Prints the files written, one per line. Exits 1 on bad values.
"""
import json
import os
import re
import sys

FACTORY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(FACTORY, "templates", "app")
ONLY = re.compile(r"\s*# only:(iphone|universal)\s*$")


def load(path):
    with open(path, encoding="utf-8") as f:
        v = json.load(f)
    errors = []
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", v.get("app", "")):
        errors.append("app must be a Swift identifier (letters, digits, _; no spaces)")
    if not re.fullmatch(r"[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+", v.get("bundle_id", "")):
        errors.append("bundle_id must look like com.example.App")
    if not re.fullmatch(r"\d+\.\d+", v.get("ios_min", "")):
        errors.append('ios_min must look like "17.0"')
    if v.get("devices") not in ("iphone", "universal"):
        errors.append('devices must be "iphone" or "universal"')
    if not v.get("display_name"):
        errors.append("display_name is required")
    if errors:
        sys.exit("✗ " + "\n✗ ".join(errors))
    return v


def render(text, v):
    out = []
    for line in text.splitlines(keepends=True):
        m = ONLY.search(line)
        if m:
            if m.group(1) != v["devices"]:
                continue
            line = line[: m.start()] + "\n"
        out.append(line)
    text = "".join(out)
    subs = {
        "APP": v["app"],
        "DISPLAY_NAME": v["display_name"],
        "BUNDLE_ID": v["bundle_id"],
        "TEAM_ID": v.get("team_id", ""),
        "IOS_MIN": v["ios_min"],
        "DEVICE_FAMILY": "1" if v["devices"] == "iphone" else "1,2",
    }
    return re.sub(r"\{\{([A-Z_]+)\}\}", lambda m: subs.get(m.group(1), m.group(0)), text)


def append_gitignore(src, target, dry):
    have = set()
    if os.path.exists(target):
        with open(target, encoding="utf-8") as f:
            have = {line.strip() for line in f}
    with open(src, encoding="utf-8") as f:
        missing = [line.rstrip("\n") for line in f if line.strip() and line.strip() not in have]
    if not missing or all(line.startswith("#") for line in missing):
        return
    print(".gitignore (+%d lines)" % sum(not line.startswith("#") for line in missing))
    if dry:
        return
    with open(target, "a", encoding="utf-8") as f:
        if have:
            f.write("\n")
        f.write("\n".join(missing) + "\n")


def main(argv):
    if not argv or argv[0].startswith("-"):
        sys.exit(__doc__)
    v = load(argv[0])
    dest = argv[argv.index("--dest") + 1] if "--dest" in argv else os.getcwd()
    dry = "--dry-run" in argv
    for root, _, files in os.walk(TEMPLATE):
        for name in sorted(files):
            if name == ".DS_Store":
                continue
            src = os.path.join(root, name)
            if name == "gitignore.append":
                append_gitignore(src, os.path.join(dest, ".gitignore"), dry)
                continue
            rel = os.path.relpath(src, TEMPLATE).replace("__APP__", v["app"])
            target = os.path.join(dest, rel)
            if os.path.exists(target):
                print(f"skip (exists) {rel}")
                continue
            print(rel)
            if dry:
                continue
            os.makedirs(os.path.dirname(target), exist_ok=True)
            if name.endswith(".json") and "xcassets" in rel:
                with open(src, "rb") as f, open(target, "wb") as g:
                    g.write(f.read())
                continue
            with open(src, encoding="utf-8") as f:
                text = render(f.read(), v)
            with open(target, "w", encoding="utf-8") as f:
                f.write(text)


if __name__ == "__main__":
    main(sys.argv[1:])
