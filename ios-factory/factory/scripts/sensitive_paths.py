#!/usr/bin/env python3
"""List files a job branch changed that need extra care on iOS.

  sensitive_paths.py <worktree> [data model globs...]

Prints a markdown list grouped by why each path matters, or "None.".
Reviewers and the approver read this from checks.md instead of guessing.
"""
import fnmatch
import subprocess
import sys

worktree, model_globs = sys.argv[1], sys.argv[2:]
changed = subprocess.run(
    ["git", "-C", worktree, "diff", "--name-only", "main...HEAD"],
    capture_output=True, text=True, check=True,
).stdout.split()

RULES = [
    ("Entitlements / capabilities", ["*.entitlements"]),
    ("Info.plist (purpose strings, background modes, URL schemes)", ["*Info.plist"]),
    ("Privacy manifest", ["*PrivacyInfo.xcprivacy"]),
    ("Project / build settings / signing", ["*project.yml", "*Project.swift", "*.pbxproj", "*.xcconfig", "*.xcscheme"]),
    ("Dependencies", ["*Package.swift", "*Package.resolved", "*Podfile", "*Podfile.lock", "*Cartfile*"]),
    ("Data model (SwiftData / Core Data / CloudKit schema)", list(model_globs) + ["*.xcdatamodeld/*", "*.xcdatamodel/*"]),
    ("Release tooling", ["*ExportOptions*.plist", "fastlane/*", "*/testflight*.sh", "ci_scripts/*", ".github/*"]),
    ("Factory files (job branches must not touch these)", ["factory/*", ".claude/*"]),
]

hits = {}
for path in changed:
    for label, globs in RULES:
        if any(fnmatch.fnmatch(path, g) for g in globs):
            hits.setdefault(label, []).append(path)

# A Swift file that declares a SwiftData model is a schema change wherever it lives.
for path in changed:
    if path.endswith(".swift"):
        diff = subprocess.run(["git", "-C", worktree, "diff", "main...HEAD", "--", path],
                              capture_output=True, text=True).stdout
        if any(l.startswith(("+", "-")) and ("@Model" in l or "@Attribute" in l or "@Relationship" in l)
               for l in diff.splitlines()):
            label = "Data model (SwiftData / Core Data / CloudKit schema)"
            if path not in hits.get(label, []):
                hits.setdefault(label, []).append(path)

if not hits:
    print("None.")
for label, paths in hits.items():
    print(f"- **{label}**: " + ", ".join(f"`{p}`" for p in paths))
