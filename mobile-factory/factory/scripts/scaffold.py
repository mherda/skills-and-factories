#!/usr/bin/env python3
"""Render the starter app(s) (factory/templates/app/) into a repo. Used by /factory-new.

  python3 -I factory/scripts/scaffold.py <values.json> [--dest <repo>] [--dry-run]

values.json:
  {"platforms": ["ios", "android"],      one or both
   "app": "HabitLoop",                   PascalCase identifier: target, scheme, theme names
   "display_name": "Habit Loop",         home-screen name on both
   -- iOS (when "ios" is in platforms) --
   "bundle_id": "com.example.HabitLoop",
   "team_id": "",                        Apple team id; "" builds for the simulator only
   "ios_min": "17.0",
   "devices": "iphone",                  "iphone" or "universal"
   -- Android (when "android" is in platforms) --
   "application_id": "com.example.habitloop",   also the Kotlin package and namespace
   "min_sdk": 26,                        26 or higher (adaptive launcher icon)
   "compile_sdk": 37,                    the newest platform (AndroidX needs it)
   "target_sdk": 37}                     at least Play's current requirement

The template has ios/ and android/ folders; only the selected platforms are
rendered. Placeholders {{APP}}, {{DISPLAY_NAME}}, {{BUNDLE_ID}}, {{TEAM_ID}},
{{IOS_MIN}}, {{DEVICE_FAMILY}}, {{APPLICATION_ID}}, {{MIN_SDK}}, {{COMPILE_SDK}}
and {{TARGET_SDK}} are replaced in text files; __APP__ in paths becomes the app
name and __PKG__ the package folders (com/example/habitloop). A line ending in
"# only:<x>" or "<!-- only:<x> -->" is kept (without the marker) only when <x>
applies: ios or android (a platform), iphone or universal (iOS devices).
Binary files are copied as they are, and executable bits are kept. Existing
files are never overwritten: they're listed as skipped. gitignore.append is
merged into .gitignore. Prints the files written, one per line. Exits 1 on bad
values.
"""
import json
import os
import re
import shutil
import sys

FACTORY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(FACTORY, "templates", "app")
ONLY = re.compile(r"\s*(?:# only:(\w+)|<!-- only:(\w+) -->)\s*$")
BINARY = (".jar", ".png", ".webp")
KEYWORDS = {"as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if", "in",
            "interface", "is", "null", "object", "package", "return", "super", "this", "throw",
            "true", "try", "typealias", "typeof", "val", "var", "when", "while"}


def load(path):
    with open(path, encoding="utf-8") as f:
        v = json.load(f)
    errors = []
    platforms = v.get("platforms")
    if not platforms or not set(platforms) <= {"ios", "android"}:
        errors.append('platforms must be ["ios"], ["android"] or ["ios", "android"]')
        platforms = []
    if not re.fullmatch(r"[A-Z][A-Za-z0-9]*", v.get("app", "")):
        errors.append("app must be a PascalCase identifier (letters and digits, e.g. HabitLoop)")
    if not v.get("display_name"):
        errors.append("display_name is required")
    if "ios" in platforms:
        if not re.fullmatch(r"[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+", v.get("bundle_id", "")):
            errors.append("bundle_id must look like com.example.App")
        if not re.fullmatch(r"\d+\.\d+", v.get("ios_min", "")):
            errors.append('ios_min must look like "17.0"')
        if v.get("devices") not in ("iphone", "universal"):
            errors.append('devices must be "iphone" or "universal"')
    if "android" in platforms:
        parts = str(v.get("application_id", "")).split(".")
        if len(parts) < 2 or not all(re.fullmatch(r"[a-z][a-z0-9_]*", p) for p in parts):
            errors.append("application_id must look like com.example.habitloop (lowercase segments)")
        elif any(p in KEYWORDS for p in parts):
            errors.append("application_id can't contain a Kotlin keyword as a segment")
        sdk = [v.get(k) for k in ("min_sdk", "target_sdk", "compile_sdk")]
        if not all(isinstance(x, int) for x in sdk):
            errors.append("min_sdk, target_sdk and compile_sdk must be numbers")
        elif sdk[0] < 26 or sdk[2] < 35 or not sdk[0] <= sdk[1] <= sdk[2]:
            errors.append("need 26 <= min_sdk <= target_sdk <= compile_sdk, and compile_sdk >= 35")
    if errors:
        sys.exit("✗ " + "\n✗ ".join(errors))
    return v


def keep(marker, v):
    if marker in ("ios", "android"):
        return marker in v["platforms"]
    return marker == v.get("devices")


def render(text, v, xml=False):
    out = []
    for line in text.splitlines(keepends=True):
        m = ONLY.search(line)
        if m:
            if not keep(m.group(1) or m.group(2), v):
                continue
            line = line[: m.start()] + "\n"
        out.append(line)
    text = "".join(out)
    name = v["display_name"]
    if xml:  # Android string resources: XML-escape, and apostrophes need a backslash
        name = name.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("'", "\\'")
    subs = {
        "APP": v["app"],
        "DISPLAY_NAME": name,
        "BUNDLE_ID": v.get("bundle_id", ""),
        "TEAM_ID": v.get("team_id", ""),
        "IOS_MIN": v.get("ios_min", ""),
        "DEVICE_FAMILY": "1" if v.get("devices") == "iphone" else "1,2",
        "APPLICATION_ID": v.get("application_id", ""),
        "MIN_SDK": str(v.get("min_sdk", "")),
        "COMPILE_SDK": str(v.get("compile_sdk", "")),
        "TARGET_SDK": str(v.get("target_sdk", "")),
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
    pkg = v.get("application_id", "").replace(".", "/")
    for root, _, files in os.walk(TEMPLATE):
        top = os.path.relpath(root, TEMPLATE).split(os.sep)[0]
        if top in ("ios", "android") and top not in v["platforms"]:
            continue
        for name in sorted(files):
            if name == ".DS_Store":
                continue
            src = os.path.join(root, name)
            if name == "gitignore.append":
                append_gitignore(src, os.path.join(dest, ".gitignore"), dry)
                continue
            rel = os.path.relpath(src, TEMPLATE).replace("__APP__", v["app"]).replace("__PKG__", pkg)
            target = os.path.join(dest, rel)
            if os.path.exists(target):
                print(f"skip (exists) {rel}")
                continue
            print(rel)
            if dry:
                continue
            os.makedirs(os.path.dirname(target), exist_ok=True)
            if name.endswith(BINARY) or (name.endswith(".json") and "xcassets" in rel):
                shutil.copyfile(src, target)
            else:
                with open(src, encoding="utf-8") as f:
                    text = render(f.read(), v, xml=name.endswith(".xml"))
                with open(target, "w", encoding="utf-8") as f:
                    f.write(text)
            shutil.copymode(src, target)


if __name__ == "__main__":
    main(sys.argv[1:])
