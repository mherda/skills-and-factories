#!/usr/bin/env python3
"""Read the factory's trackers: roadmap, issues, decisions, releases.

  tracker.py roadmap [--json]          roadmap with progress per milestone
  tracker.py next                      first open roadmap item (for /factory next)
  tracker.py issues [status...]        issues, needs-input first
  tracker.py issue-id <slug>           claim the next issue id, print the file path
  tracker.py inbox [--brief]           what needs the user: issues needing input, escalated jobs
  tracker.py decisions [--json]        decision index (id, date, title, scope, status)
  tracker.py decision-id               next decision id

Writes are done by the skills with Edit (one exact line at a time), so two
sessions changing different lines never clobber each other.
"""
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
F = os.path.abspath(os.environ.get("FACTORY_DIR") or os.path.join(REPO, "factory"))  # FACTORY_DIR: preview drafts (factory-init)
ROADMAP = os.path.join(F, "roadmap.md")
ISSUES = os.path.join(F, "issues")
DECISIONS = os.path.join(F, "decisions.md")
JOBS = os.path.join(REPO, "factory", "jobs")

MARKS = {" ": "todo", "~": "doing", "x": "done", "?": "needs-input", "-": "parked"}
ICONS = {"todo": "○", "doing": "◐", "done": "●", "needs-input": "?", "parked": "–"}
ITEM = re.compile(r"^- \[(.)\] (.*)$")


def read(path, strip_comments=False):
    try:
        with open(path) as f:
            text = f.read()
    except FileNotFoundError:
        return ""
    return re.sub(r"<!--.*?-->", "", text, flags=re.S) if strip_comments else text


# --- roadmap ---------------------------------------------------------------------

def parse_roadmap():
    milestones, current = [], None
    for line in read(ROADMAP, strip_comments=True).splitlines():
        if line.startswith("## "):
            current = {"title": line[3:].strip(), "goal": "", "items": []}
            milestones.append(current)
        elif current is not None and line.lower().startswith("goal:"):
            current["goal"] = line[5:].strip()
        elif current is not None and (m := ITEM.match(line)):
            text = m.group(2)
            current["items"].append({
                "status": MARKS.get(m.group(1), "todo"),
                "text": text.split(" · ")[0].strip(),
                "refs": [r.strip() for r in text.split(" · ")[1:]],
                "line": line,
            })
    return milestones


def bar(done, total, width=20):
    if total == 0:
        return "░" * width
    filled = round(width * done / total)
    return "█" * filled + "░" * (width - filled)


def cmd_roadmap(as_json):
    ms = parse_roadmap()
    if as_json:
        print(json.dumps(ms, indent=2, ensure_ascii=False))
        return
    all_items = [i for m in ms for i in m["items"] if i["status"] != "parked"]
    done = sum(i["status"] == "done" for i in all_items)
    print(f"Roadmap  {bar(done, len(all_items), 30)}  {done}/{len(all_items)} done\n")
    for m in ms:
        live = [i for i in m["items"] if i["status"] != "parked"]
        d = sum(i["status"] == "done" for i in live)
        print(f"{m['title']}\n  {bar(d, len(live))}  {d}/{len(live)}" + (f"  · {m['goal']}" if m["goal"] else ""))
        for i in m["items"]:
            refs = f"  [{', '.join(i['refs'])}]" if i["refs"] else ""
            print(f"    {ICONS[i['status']]} {i['text']}{refs}")
        print()
    print("● done  ◐ in progress  ○ to do  ? needs your input  – parked")


def cmd_next():
    for m in parse_roadmap():
        for i in m["items"]:
            if i["status"] == "todo":
                print(json.dumps({"milestone": m["title"], **i}, ensure_ascii=False))
                return
    print("{}")


# --- issues ----------------------------------------------------------------------

def frontmatter(text):
    meta = {}
    if text.startswith("---"):
        block = text.split("---", 2)[1]
        for line in block.strip().splitlines():
            if ":" in line:
                k, v = line.split(":", 1)
                meta[k.strip()] = v.split(" #")[0].strip()  # drop trailing "# comment"
    return meta


def load_issues():
    out = []
    if not os.path.isdir(ISSUES):
        return out
    for name in sorted(os.listdir(ISSUES)):
        if re.match(r"^ISS-\d+.*\.md$", name):
            meta = frontmatter(read(os.path.join(ISSUES, name)))
            meta["file"] = f"factory/issues/{name}"
            out.append(meta)
    return out


ORDER = ["needs-input", "answered", "open", "in-progress", "done", "wontfix"]


def cmd_issues(statuses):
    issues = load_issues()
    if statuses:
        issues = [i for i in issues if i.get("status") in statuses]
    issues.sort(key=lambda i: (ORDER.index(i.get("status")) if i.get("status") in ORDER else 99, i.get("id", "")))
    if not issues:
        print("No issues.")
    for i in issues:
        job = f" · job {i['job']}" if i.get("job") not in (None, "", "null") else ""
        print(f"{i.get('id', '?'):<8} {i.get('status', '?'):<12} {i.get('type', '?'):<8} {i.get('title', '')}{job}")


def cmd_issue_id(slug):
    os.makedirs(ISSUES, exist_ok=True)
    slug = re.sub(r"[^a-z0-9-]+", "-", slug.lower()).strip("-")[:40]
    while True:
        nums = [int(m.group(1)) for n in os.listdir(ISSUES) if (m := re.match(r"^ISS-(\d+)", n))]
        iid = f"ISS-{max(nums, default=0) + 1:03d}"
        path = os.path.join(ISSUES, f"{iid}-{slug}.md")
        try:
            with open(path, "x") as f:  # exclusive create: another session can't take the same id
                f.write(f"---\nid: {iid}\n---\n")
            print(path)
            return
        except FileExistsError:
            continue


def escalated_jobs():
    out = []
    if not os.path.isdir(JOBS):
        return out
    for d in sorted(os.listdir(JOBS)):
        p = os.path.join(JOBS, d, "job.json")
        if os.path.exists(p):
            j = json.load(open(p))
            if j.get("stage") == "needs-input":
                out.append(j)
    return out


def cmd_inbox(brief):
    waiting = [i for i in load_issues() if i.get("status") == "needs-input"]
    answered = [i for i in load_issues() if i.get("status") == "answered"]
    jobs = escalated_jobs()
    if brief:
        if waiting or answered or jobs:
            print(f"Factory inbox: {len(waiting)} issue(s) need the user's input, "
                  f"{len(answered)} answered and ready to resume, {len(jobs)} job(s) paused. "
                  "Mention this once and suggest /issues.")
        return
    print(f"Needs your input ({len(waiting)})")
    for i in waiting:
        print(f"  {i['id']}  {i.get('title', '')}" + (f" · job {i['job']}" if i.get("job") not in (None, "", "null") else ""))
    print(f"\nAnswered, ready to resume ({len(answered)})")
    for i in answered:
        print(f"  {i['id']}  {i.get('title', '')}")
    print(f"\nPaused jobs ({len(jobs)})")
    for j in jobs:
        print(f"  {j['id']}  blocked at {j.get('blocked_at')} · {j.get('issue') or 'no issue'}")


# --- decisions -------------------------------------------------------------------

DECISION = re.compile(r"^## (D-\d+) · (\S+) · (.*)$")


def parse_decisions():
    out, cur = [], None
    for line in read(DECISIONS, strip_comments=True).splitlines():
        if m := DECISION.match(line):
            cur = {"id": m.group(1), "date": m.group(2), "title": m.group(3), "scope": "", "status": "active"}
            out.append(cur)
        elif cur and line.startswith("Scope:"):
            cur["scope"] = line[6:].strip()
        elif cur and line.startswith("Status:"):
            cur["status"] = line[7:].strip()
    return out


def cmd_decisions(as_json):
    ds = parse_decisions()
    if as_json:
        print(json.dumps(ds, indent=2, ensure_ascii=False))
        return
    for d in ds:
        flag = "" if d["status"] == "active" else f"  ({d['status']})"
        print(f"{d['id']:<6} {d['date']}  {d['title']}  [{d['scope']}]{flag}")


def cmd_decision_id():
    nums = [int(d["id"][2:]) for d in parse_decisions()]
    print(f"D-{max(nums, default=0) + 1:03d}")


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    cmd, args = argv[1], argv[2:]
    if cmd == "roadmap":
        cmd_roadmap("--json" in args)
    elif cmd == "next":
        cmd_next()
    elif cmd == "issues":
        cmd_issues(args)
    elif cmd == "issue-id":
        cmd_issue_id(args[0] if args else "issue")
    elif cmd == "inbox":
        cmd_inbox("--brief" in args)
    elif cmd == "decisions":
        cmd_decisions("--json" in args)
    elif cmd == "decision-id":
        cmd_decision_id()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
