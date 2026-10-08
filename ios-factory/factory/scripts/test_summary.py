#!/usr/bin/env python3
"""Summarise an xcodebuild test run as markdown.

  test_summary.py <tests.xcresult> <xcodebuild log> <xcodebuild exit status>
"""
import json
import os
import re
import subprocess
import sys

bundle, log, status = sys.argv[1], sys.argv[2], int(sys.argv[3])
print("## Build & tests")

summary = None
if os.path.exists(bundle):
    try:
        out = subprocess.run(
            ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", bundle],
            capture_output=True, text=True, check=True,
        ).stdout
        summary = json.loads(out)
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        summary = None

log_text = open(log, errors="replace").read() if os.path.exists(log) else ""
errors = sorted(set(re.findall(r"^.*?: error: .*$", log_text, re.M)))
warnings = sorted(set(re.findall(r"^(/\S+?:\d+:\d+): warning: (.*)$", log_text, re.M)))

if summary:
    print(f"result: {summary.get('result', '?')} · {summary.get('totalTestCount', '?')} tests, "
          f"{summary.get('passedTests', '?')} passed, {summary.get('failedTests', '?')} failed, "
          f"{summary.get('skippedTests', 0)} skipped")
    failures = summary.get("testFailures") or []
    if failures:
        print("\n### Failures")
        for f in failures[:30]:
            name = f.get("testIdentifierString") or f.get("testName", "?")
            print(f"- `{name}`: {f.get('failureText', '').strip()[:400]}")
elif status != 0:
    print("result: build failed (no test results)")
else:
    print("result: passed (no result bundle to summarise)")

if errors:
    print("\n### Compiler errors")
    for e in errors[:30]:
        print(f"- {e.strip()[:400]}")

print(f"\nwarnings: {len(warnings)}")
for loc, msg in warnings[:15]:
    print(f"- {os.path.basename(loc)}: {msg[:200]}")
print(f"\nfull log: {os.path.relpath(log, os.path.dirname(os.path.dirname(bundle)))}")
