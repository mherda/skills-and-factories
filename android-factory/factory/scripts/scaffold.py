#!/usr/bin/env python3
"""Render the starter app (factory/templates/app/) into a repo. Used by /factory-new.

  python3 -I factory/scripts/scaffold.py <values.json> [--dest <repo>] [--dry-run]

values.json:
  {"app": "HabitLoop",                     Kotlin identifier: theme and project names
   "display_name": "Habit Loop",           launcher name
   "application_id": "com.example.habitloop",   also the Kotlin package and namespace
   "min_sdk": 26,                          26 or higher (adaptive launcher icon)
   "compile_sdk": 37,                      compileSdk: the newest platform (AndroidX needs it)
   "target_sdk": 36}                       targetSdk: newest the app is tested on; Play sets a floor

Placeholders {{APP}}, {{DISPLAY_NAME}}, {{APPLICATION_ID}}, {{MIN_SDK}},
{{COMPILE_SDK}} and {{TARGET_SDK}} are replaced in text files, and __PKG__ in paths becomes the
package folders (com/example/habitloop). Binary files (the Gradle wrapper jar)
are copied as they are, and executable bits are kept. Existing files are never
overwritten: they're listed as skipped. gitignore.append is merged into
.gitignore (only the lines it doesn't have yet). Prints the files written, one
per line. Exits 1 on bad values.
"""
import json
import os
import re
import shutil
import sys

FACTORY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(FACTORY, "templates", "app")
BINARY = (".jar", ".png", ".webp")
# Kotlin hard keywords can't be package segments.
KEYWORDS = {"as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if", "in",
            "interface", "is", "null", "object", "package", "return", "super", "this", "throw",
            "true", "try", "typealias", "typeof", "val", "var", "when", "while"}


def load(path):
    with open(path, encoding="utf-8") as f:
        v = json.load(f)
    errors = []
    if not re.fullmatch(r"[A-Z][A-Za-z0-9]*", v.get("app", "")):
        errors.append("app must be a PascalCase identifier (letters and digits, e.g. HabitLoop)")
    parts = str(v.get("application_id", "")).split(".")
    if len(parts) < 2 or not all(re.fullmatch(r"[a-z][a-z0-9_]*", p) for p in parts):
        errors.append("application_id must look like com.example.habitloop (lowercase segments)")
    elif any(p in KEYWORDS for p in parts):
        errors.append("application_id can't contain a Kotlin keyword as a segment")
    if not isinstance(v.get("min_sdk"), int) or v["min_sdk"] < 26:
        errors.append("min_sdk must be a number, 26 or higher")
    if not isinstance(v.get("compile_sdk"), int) or v["compile_sdk"] < 35:
        errors.append("compile_sdk must be a number, 35 or higher")
    if not isinstance(v.get("target_sdk"), int):
        errors.append("target_sdk must be a number")
    elif isinstance(v.get("compile_sdk"), int) and isinstance(v.get("min_sdk"), int) \
            and not v["min_sdk"] <= v["target_sdk"] <= v["compile_sdk"]:
        errors.append("need min_sdk <= target_sdk <= compile_sdk")
    if not v.get("display_name"):
        errors.append("display_name is required")
    if errors:
        sys.exit("✗ " + "\n✗ ".join(errors))
    return v


def render(text, v, xml=False):
    name = v["display_name"]
    if xml:  # Android string resources: XML-escape, and apostrophes need a backslash
        name = name.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("'", "\\'")
    subs = {
        "APP": v["app"],
        "DISPLAY_NAME": name,
        "APPLICATION_ID": v["application_id"],
        "MIN_SDK": str(v["min_sdk"]),
        "COMPILE_SDK": str(v["compile_sdk"]),
        "TARGET_SDK": str(v["target_sdk"]),
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
    pkg = v["application_id"].replace(".", "/")
    for root, _, files in os.walk(TEMPLATE):
        for name in sorted(files):
            if name == ".DS_Store":
                continue
            src = os.path.join(root, name)
            if name == "gitignore.append":
                append_gitignore(src, os.path.join(dest, ".gitignore"), dry)
                continue
            rel = os.path.relpath(src, TEMPLATE).replace("__PKG__", pkg)
            target = os.path.join(dest, rel)
            if os.path.exists(target):
                print(f"skip (exists) {rel}")
                continue
            print(rel)
            if dry:
                continue
            os.makedirs(os.path.dirname(target), exist_ok=True)
            if name.endswith(BINARY):
                shutil.copyfile(src, target)
            else:
                with open(src, encoding="utf-8") as f:
                    text = render(f.read(), v, xml=name.endswith(".xml"))
                with open(target, "w", encoding="utf-8") as f:
                    f.write(text)
            shutil.copymode(src, target)


if __name__ == "__main__":
    main(sys.argv[1:])
