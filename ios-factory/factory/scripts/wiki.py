#!/usr/bin/env python3
"""Maintain the project wiki (docs/wiki by default; WIKI_DIR in factory/config.sh).

Works on the git checkout you run it from, so agents run it inside a job's
worktree:  cd <worktree> && python3 -I <factory>/scripts/wiki.py <command>

  wiki.py pages-for <path>...     pages whose `code:` covers any of these paths
  wiki.py pages-for --diff [ref]  same, for files changed since ref (default main)
  wiki.py pages-for --commit <ref> | --range <a..b> | --staged
                                  same, for one commit, a range, or what's staged
  wiki.py verify <page>...        mark pages as checked against the code (resets "stale")
  wiki.py coverage                source files no page covers
  wiki.py stale                   pages whose code changed after the page did
  wiki.py lint                    frontmatter, links, code paths, index; exit 1 on errors
  wiki.py index                   regenerate the page map in index.md
  wiki.py list [--json]           every page: path, type, title, summary

Page frontmatter (inline lists only):
  ---
  title: Area progress
  type: feature            # feature | module | architecture | guide | reference
  summary: One line for the index.
  code: [ios/ExploreClaim/Areas/, ios/ExploreClaim/Services/AreaService.swift]
  related: [modules/services.md, architecture/data.md]
  decisions: [D-004]
  shipped: 1.1 (202610081932)   # features only: a version, "unreleased" or "n/a"
  ---
"""
import fnmatch
import json
import os
import re
import subprocess
import sys

TYPES = ["architecture", "feature", "module", "guide", "reference"]
REQUIRED = ["title", "type", "summary"]
SOURCE_EXT = (".swift", ".m", ".h", ".metal", ".intentdefinition", ".xcdatamodeld")
INDEX_START, INDEX_END = "<!-- wiki:index:start -->", "<!-- wiki:index:end -->"


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


ROOT = git("rev-parse", "--show-toplevel").strip()


def wiki_dir():
    cfg = os.path.join(ROOT, "factory", "config.sh")
    if os.path.exists(cfg):
        m = re.search(r'^WIKI_DIR="([^"]+)"', open(cfg).read(), re.M)
        if m:
            return m.group(1)
    return "docs/wiki"


WIKI = wiki_dir()
WIKI_ABS = os.path.join(ROOT, WIKI)


def parse_list(v):
    v = v.strip()
    if v.startswith("[") and v.endswith("]"):
        return [x.strip().strip("'\"") for x in v[1:-1].split(",") if x.strip()]
    return [v] if v else []


def load_pages():
    pages = []
    for dirpath, _, files in os.walk(WIKI_ABS):
        if "/_templates" in dirpath.replace(os.sep, "/") + "/":
            continue
        for f in sorted(files):
            if not f.endswith(".md"):
                continue
            abs_path = os.path.join(dirpath, f)
            rel = os.path.relpath(abs_path, WIKI_ABS)
            text = open(abs_path).read()
            meta, body = {}, text
            m = re.match(r"^---\n(.*?)\n---\n?(.*)$", text, re.S)
            if m:
                body = m.group(2)
                for line in m.group(1).splitlines():
                    if ":" in line:
                        k, v = line.split(":", 1)
                        meta[k.strip()] = v.split(" #")[0].strip()
            for k in ("code", "related", "decisions"):
                meta[k] = parse_list(meta.get(k, ""))
            pages.append({"path": rel, "meta": meta, "body": body, "has_frontmatter": bool(m)})
    return pages


def covers(pattern, path):
    pattern = pattern.rstrip("/") if not any(c in pattern for c in "*?[") else pattern
    return path == pattern or path.startswith(pattern + "/") or fnmatch.fnmatch(path, pattern)


def tracked_sources():
    return [p for p in git("-C", ROOT, "ls-files").splitlines() if p.endswith(SOURCE_EXT) or ".xcdatamodeld/" in p]


def cmd_pages_for(args):
    if args and args[0] == "--diff":
        ref = args[1] if len(args) > 1 else "main"
        paths = git("-C", ROOT, "diff", "--name-only", f"{ref}...HEAD").split()
    elif args and args[0] == "--commit":
        paths = git("-C", ROOT, "diff-tree", "--no-commit-id", "--name-only", "-r", args[1]).split()
    elif args and args[0] == "--range":
        paths = git("-C", ROOT, "diff", "--name-only", args[1]).split()
    elif args and args[0] == "--staged":
        paths = git("-C", ROOT, "diff", "--cached", "--name-only").split()
    else:
        paths = args
    pages = load_pages()
    hits = {}
    for p in pages:
        matched = [path for path in paths for pat in p["meta"]["code"] if covers(pat, path)]
        if matched:
            hits[p["path"]] = sorted(set(matched))
    uncovered = [path for path in paths if path.endswith(SOURCE_EXT)
                 and not any(path in v for v in hits.values())]
    for page, files in sorted(hits.items()):
        print(f"{WIKI}/{page}: " + ", ".join(files))
    if uncovered:
        print("\nNo page covers: " + ", ".join(uncovered))
    if not hits and not uncovered:
        print("No wiki pages affected.")


def cmd_coverage():
    patterns = [pat for p in load_pages() for pat in p["meta"]["code"]]
    missing = [s for s in tracked_sources() if not any(covers(pat, s) for pat in patterns)]
    total = len(tracked_sources())
    print(f"{total - len(missing)}/{total} source files covered by a wiki page")
    for s in missing:
        print(f"  {s}")


def cmd_verify(names):
    """Stamp `verified: <date> <sha>` on pages the documenter checked and found right.
    Committing that change moves the page's git timestamp past its code, so it stops
    showing as stale without inventing edits."""
    sha = git("-C", ROOT, "rev-parse", "--short", "HEAD").strip()
    stamp = f"verified: {__import__('datetime').date.today().isoformat()} {sha}"
    for name in names:
        rel = name.split(WIKI + "/", 1)[-1]
        path = os.path.join(WIKI_ABS, rel)
        text = open(path).read()
        m = re.match(r"^---\n(.*?)\n---", text, re.S)
        if not m:
            sys.exit(f"{name}: no frontmatter")
        head = re.sub(r"^verified:.*\n?", "", m.group(1), flags=re.M).rstrip("\n")
        text = f"---\n{head}\n{stamp}\n---" + text[m.end():]
        open(path, "w").write(text)
        print(f"{WIKI}/{rel}: {stamp}")


def last_commit(path):
    out = git("-C", ROOT, "log", "-1", "--format=%ct", "--", path).strip()
    return int(out) if out else 0


def cmd_stale():
    found = False
    for p in load_pages():
        if not p["meta"]["code"]:
            continue
        page_time = last_commit(os.path.join(WIKI, p["path"]))
        newer = []
        for pat in p["meta"]["code"]:
            files = [s for s in git("-C", ROOT, "ls-files").splitlines() if covers(pat, s)]
            newer += [f for f in files if last_commit(f) > page_time]
        if newer:
            found = True
            print(f"{WIKI}/{p['path']}: code changed since the page did: " + ", ".join(sorted(set(newer))[:8]))
    if not found:
        print("No stale pages.")


LINK = re.compile(r"\]\(([^)#\s]+\.md)(#[^)]*)?\)")


def cmd_lint():
    pages = load_pages()
    names = {p["path"] for p in pages}
    errors, warnings = [], []
    all_files = git("-C", ROOT, "ls-files").splitlines()
    index = next((p for p in pages if p["path"] == "index.md"), None)
    if not index:
        errors.append("index.md is missing")
    for p in pages:
        where = f"{WIKI}/{p['path']}"
        if p["path"] in ("index.md",):
            continue
        if not p["has_frontmatter"]:
            errors.append(f"{where}: no frontmatter")
            continue
        for k in REQUIRED:
            if not p["meta"].get(k):
                errors.append(f"{where}: missing `{k}`")
        t = p["meta"].get("type")
        if t and t not in TYPES:
            errors.append(f"{where}: type `{t}` is not one of {TYPES}")
        if t in ("feature", "module") and not p["meta"]["code"]:
            warnings.append(f"{where}: {t} page with no `code:` paths")
        if t == "feature" and not p["meta"].get("shipped"):
            warnings.append(f"{where}: feature page with no `shipped:`")
        for pat in p["meta"]["code"]:
            if not any(covers(pat, f) for f in all_files):
                errors.append(f"{where}: code path `{pat}` matches no tracked file")
        for r in p["meta"]["related"]:
            if r not in names:
                errors.append(f"{where}: related page `{r}` doesn't exist")
        if index and p["path"] not in index["body"]:
            warnings.append(f"{where}: not listed in index.md (run `wiki.py index`)")
    for p in pages:
        base = os.path.dirname(p["path"])
        for target, _ in LINK.findall(p["body"]):
            if target.startswith(("http://", "https://")):
                continue
            resolved = os.path.normpath(os.path.join(WIKI_ABS, base, target))
            if not os.path.exists(resolved):
                errors.append(f"{WIKI}/{p['path']}: broken link `{target}`")
    for e in errors:
        print(f"✗ {e}")
    for w in warnings:
        print(f"⚠ {w}")
    print(f"{len(pages)} pages · {len(errors)} errors · {len(warnings)} warnings")
    sys.exit(1 if errors else 0)


HEADINGS = {"architecture": "Architecture", "feature": "Features", "module": "Modules",
            "guide": "Guides", "reference": "Reference"}


def cmd_index():
    pages = [p for p in load_pages() if p["path"] != "index.md" and p["has_frontmatter"]]
    lines = [INDEX_START, ""]
    for t in TYPES:
        group = sorted((p for p in pages if p["meta"].get("type") == t), key=lambda p: p["meta"].get("title", ""))
        if not group:
            continue
        lines.append(f"## {HEADINGS[t]}")
        lines.append("")
        for p in group:
            extra = f" · shipped {p['meta']['shipped']}" if t == "feature" and p["meta"].get("shipped") else ""
            lines.append(f"- [{p['meta'].get('title', p['path'])}]({p['path']}): {p['meta'].get('summary', '')}{extra}")
        lines.append("")
    lines.append(INDEX_END)
    block = "\n".join(lines)
    path = os.path.join(WIKI_ABS, "index.md")
    text = open(path).read() if os.path.exists(path) else "# Wiki\n\n"
    if INDEX_START in text and INDEX_END in text:
        text = re.sub(re.escape(INDEX_START) + r".*?" + re.escape(INDEX_END), lambda _: block, text, flags=re.S)
    else:
        text = text.rstrip() + "\n\n" + block + "\n"
    open(path, "w").write(text)
    print(f"index.md: {len(pages)} pages")


def cmd_list(as_json):
    rows = [{"path": f"{WIKI}/{p['path']}", "type": p["meta"].get("type", ""), "title": p["meta"].get("title", ""),
             "summary": p["meta"].get("summary", "")} for p in load_pages()]
    if as_json:
        print(json.dumps(rows, indent=2, ensure_ascii=False))
    else:
        for r in rows:
            print(f"{r['type']:<13} {r['path']:<48} {r['summary']}")


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    cmd, args = argv[1], argv[2:]
    if not os.path.isdir(WIKI_ABS) and cmd != "index":
        sys.exit(f"No wiki at {WIKI}/ (set WIKI_DIR in factory/config.sh, or run /factory-init)")
    if cmd == "pages-for":
        cmd_pages_for(args)
    elif cmd == "verify":
        cmd_verify(args)
    elif cmd == "coverage":
        cmd_coverage()
    elif cmd == "stale":
        cmd_stale()
    elif cmd == "lint":
        cmd_lint()
    elif cmd == "index":
        os.makedirs(WIKI_ABS, exist_ok=True)
        cmd_index()
    elif cmd == "list":
        cmd_list("--json" in args)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
