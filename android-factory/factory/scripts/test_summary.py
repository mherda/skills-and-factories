#!/usr/bin/env python3
"""Summarise a Gradle test run, or an Android Lint run, as markdown.

  test_summary.py <junit xml dir> <gradle log> <gradle exit status>
  test_summary.py --lint <gradle log> <gradle exit status> [lint-results-*.xml ...]
"""
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET


def read(path):
    return open(path, errors="replace").read() if os.path.exists(path) else ""


def gradle_problems(log_text):
    """Kotlin compiler errors and warnings, and Gradle's "What went wrong" block."""
    errors = sorted(set(re.findall(r"^e: (.*)$", log_text, re.M)))
    errors += [l.strip() for l in re.findall(r"^.*\berror: .*$", log_text, re.M) if not l.startswith("e: ")][:10]
    warnings = sorted(set(re.findall(r"^w: (?:file://)?(\S+?:\d+:\d+) (.*)$", log_text, re.M)))
    wrong = re.search(r"\* What went wrong:\n(.*?)(?:\n\* Try:|\Z)", log_text, re.S)
    return errors, warnings, (wrong.group(1).strip() if wrong else "")


def tests(junit_dir, log, status):
    print("## Build & tests")
    total = failed = skipped = 0
    failures = []
    for path in sorted(glob.glob(os.path.join(junit_dir, "*.xml"))):
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError:
            continue
        for case in root.iter("testcase"):
            total += 1
            name = f"{case.get('classname', '?')}.{case.get('name', '?')}"
            if case.find("skipped") is not None:
                skipped += 1
            problem = case.find("failure")
            if problem is None:
                problem = case.find("error")
            if problem is not None:
                failed += 1
                text = (problem.get("message") or problem.text or "").strip().splitlines()
                failures.append((name, text[0] if text else ""))
    log_text = read(log)
    errors, warnings, wrong = gradle_problems(log_text)
    if total:
        result = "passed" if failed == 0 and status == 0 else "failed"
        print(f"result: {result} · {total} tests, {total - failed - skipped} passed, {failed} failed, {skipped} skipped")
        if failures:
            print("\n### Failures")
            for name, text in failures[:30]:
                print(f"- `{name}`: {text[:400]}")
    elif status != 0:
        print("result: build failed (no test results)")
    else:
        print("result: passed (no tests ran)")
    if status != 0 and wrong:
        print("\n### What went wrong")
        print("```\n" + wrong[:1500] + "\n```")
    if errors:
        print("\n### Compiler errors")
        for e in errors[:30]:
            print(f"- {e.strip()[:400]}")
    print(f"\nwarnings: {len(warnings)}")
    for loc, msg in warnings[:15]:
        print(f"- {os.path.basename(loc)}: {msg[:200]}")
    print(f"\nfull log: {os.path.relpath(log, os.path.dirname(os.path.dirname(os.path.abspath(log))))}")


def lint(log, status, reports):
    print("## Lint")
    issues = []
    for path in reports:
        try:
            root = ET.parse(path).getroot()
        except (ET.ParseError, FileNotFoundError):
            continue
        for issue in root.iter("issue"):
            loc = issue.find("location")
            where = ""
            if loc is not None:
                where = f"{os.path.basename(loc.get('file', ''))}:{loc.get('line', '?')}"
            issues.append((issue.get("severity", "?"), issue.get("id", "?"), where, issue.get("message", "")))
    errors = [i for i in issues if i[0] in ("Error", "Fatal")]
    warnings = [i for i in issues if i[0] == "Warning"]
    if not reports and status != 0:
        _, _, wrong = gradle_problems(read(log))
        print("result: lint didn't run")
        if wrong:
            print("```\n" + wrong[:1500] + "\n```")
        return
    print(f"result: {'passed' if status == 0 else 'failed'} · {len(errors)} errors, {len(warnings)} warnings")
    for sev, iid, where, msg in (errors + warnings)[:20]:
        print(f"- {sev} `{iid}` {where}: {msg[:200]}")


if __name__ == "__main__":
    if sys.argv[1] == "--lint":
        lint(sys.argv[2], int(sys.argv[3]), sys.argv[4:])
    else:
        tests(sys.argv[1], sys.argv[2], int(sys.argv[3]))
