#!/usr/bin/env python3
"""List files a job branch changed that need extra care on iOS or Android.

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

DATA_MODEL = "Data model (SwiftData / Core Data / CloudKit, Room / DataStore, migrations)"
RULES = [
    # iOS
    ("iOS entitlements / capabilities", ["*.entitlements"]),
    ("iOS Info.plist (purpose strings, background modes, URL schemes)", ["*Info.plist"]),
    ("iOS privacy manifest", ["*PrivacyInfo.xcprivacy"]),
    ("iOS project / build settings / signing", ["*project.yml", "*Project.swift", "*.pbxproj", "*.xcconfig", "*.xcscheme"]),
    ("iOS dependencies", ["*Package.swift", "*Package.resolved", "*Podfile", "*Podfile.lock", "*Cartfile*"]),
    # Android
    ("Android manifest (permissions, exported components, intent filters, deep links, services)", ["*AndroidManifest.xml"]),
    ("Android backup and data transfer rules", ["*/res/xml/*backup*", "*/res/xml/*extraction*"]),
    ("Android network security config", ["*/res/xml/*network_security*"]),
    ("Gradle build config / signing / SDK levels (also shared code)", ["*build.gradle.kts", "*build.gradle", "*settings.gradle*", "*gradle.properties", "*gradle/wrapper/*"]),
    ("Gradle dependencies (also shared code)", ["*libs.versions.toml", "*.lockfile", "*gradle/verification-metadata.xml"]),
    ("R8 / ProGuard keep rules (Android release build only)", ["*proguard*.pro", "*consumer-rules.pro", "*r8*.pro"]),
    ("Services config (Firebase, Maps keys)", ["*google-services.json", "*GoogleService-Info.plist", "*secrets*.properties"]),
    # Both
    (DATA_MODEL, list(model_globs) + ["*.xcdatamodeld/*", "*.xcdatamodel/*", "*/schemas/*.json", "*.proto"]),
    ("Release tooling", ["*ExportOptions*.plist", "fastlane/*", "*/testflight*.sh", "*/play*.sh", "ci_scripts/*", ".github/*"]),
    ("Factory files (job branches must not touch these)", ["factory/*", ".claude/*"]),
]

hits = {}
for path in changed:
    for label, globs in RULES:
        if any(fnmatch.fnmatch(path, g) for g in globs):
            hits.setdefault(label, []).append(path)

# A source file that declares a SwiftData model or a Room entity/database is a
# schema change wherever it lives.
MODEL = {
    (".swift",): re.compile(r"@(Model|Attribute|Relationship)\b"),
    (".kt", ".java"): re.compile(r"@(Entity|Database|ColumnInfo|PrimaryKey|Embedded|Relation|TypeConverter|Fts4|AutoMigration)\b"),
}
for path in changed:
    for exts, pattern in MODEL.items():
        if path.endswith(exts):
            diff = subprocess.run(["git", "-C", worktree, "diff", "main...HEAD", "--", path],
                                  capture_output=True, text=True).stdout
            if any(l.startswith(("+", "-")) and pattern.search(l) for l in diff.splitlines()):
                if path not in hits.get(DATA_MODEL, []):
                    hits.setdefault(DATA_MODEL, []).append(path)

if not hits:
    print("None.")
for label, paths in hits.items():
    print(f"- **{label}**: " + ", ".join(f"`{p}`" for p in paths))
