#!/usr/bin/env python3
"""List files a job branch changed that need extra care on Android.

  sensitive_paths.py <worktree> [data model globs...]

Prints a markdown list grouped by why each path matters, or "None.".
Reviewers and the approver read this from checks.md instead of guessing.
"""
import fnmatch
import re
import subprocess
import sys

worktree, model_globs = sys.argv[1], sys.argv[2:]
changed = subprocess.run(
    ["git", "-C", worktree, "diff", "--name-only", "main...HEAD"],
    capture_output=True, text=True, check=True,
).stdout.split()

DATA_MODEL = "Data model (Room entities and schema, DataStore, migrations)"
RULES = [
    ("Manifest (permissions, exported components, intent filters, deep links, services)", ["*AndroidManifest.xml"]),
    ("Backup and data transfer rules", ["*/res/xml/*backup*", "*/res/xml/*extraction*"]),
    ("Network security config", ["*/res/xml/*network_security*"]),
    ("Build config / signing / SDK levels", ["*build.gradle.kts", "*build.gradle", "*settings.gradle*", "*gradle.properties", "*gradle/wrapper/*"]),
    ("Dependencies", ["*libs.versions.toml", "*.lockfile", "*gradle/verification-metadata.xml"]),
    ("R8 / ProGuard keep rules (release build only)", ["*proguard*.pro", "*consumer-rules.pro", "*r8*.pro"]),
    ("Services config (Firebase, Maps keys)", ["*google-services.json", "*secrets*.properties"]),
    (DATA_MODEL, list(model_globs) + ["*/schemas/*.json", "*.proto"]),
    ("Release tooling", ["fastlane/*", "*/play*.sh", ".github/*"]),
    ("Factory files (job branches must not touch these)", ["factory/*", ".claude/*"]),
]

hits = {}
for path in changed:
    for label, globs in RULES:
        if any(fnmatch.fnmatch(path, g) for g in globs):
            hits.setdefault(label, []).append(path)

# A Kotlin/Java file that declares a Room entity or database is a schema change
# wherever it lives.
ROOM = re.compile(r"@(Entity|Database|ColumnInfo|PrimaryKey|Embedded|Relation|TypeConverter|Fts4|AutoMigration)\b")
for path in changed:
    if path.endswith((".kt", ".java")):
        diff = subprocess.run(["git", "-C", worktree, "diff", "main...HEAD", "--", path],
                              capture_output=True, text=True).stdout
        if any(l.startswith(("+", "-")) and ROOM.search(l) for l in diff.splitlines()):
            if path not in hits.get(DATA_MODEL, []):
                hits.setdefault(DATA_MODEL, []).append(path)

if not hits:
    print("None.")
for label, paths in hits.items():
    print(f"- **{label}**: " + ", ".join(f"`{p}`" for p in paths))
