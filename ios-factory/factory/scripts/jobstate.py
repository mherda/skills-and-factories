#!/usr/bin/env python3
"""Read and write factory job state (factory/jobs/<job-id>/job.json).

The orchestrator is the only writer of a job's job.json and always goes through
this script, so the file stays valid JSON and every stage change lands in the
job's history.

  jobstate.py claim <slug>                         claim the next job number, print the job id
  jobstate.py new <job-id> feature=... [kind=feature|bug|docs] [issue=ISS-001] [roadmap=...] [confirm=true]
  jobstate.py get <job-id> [dotted.key]            print the job (or one value)
  jobstate.py set <job-id> key=value ...           update keys (dotted keys, JSON values allowed)
  jobstate.py list [--active]                      one line per job
"""
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
JOBS = os.path.join(REPO, "factory", "jobs")
ACTIVE = {"spec", "build", "check", "review", "approve", "docs", "merge"}
STAGES = ACTIVE | {"needs-input", "merged", "abandoned"}


def now():
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def path(job_id):
    return os.path.join(JOBS, job_id, "job.json")


def load(job_id):
    with open(path(job_id)) as f:
        return json.load(f)


def save(job):
    job["updated"] = now()
    tmp = path(job["id"]) + ".tmp"
    with open(tmp, "w") as f:
        json.dump(job, f, indent=2)
        f.write("\n")
    os.replace(tmp, path(job["id"]))  # atomic, so the dashboard never reads half a file


def parse_value(raw):
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def set_dotted(obj, key, value):
    parts = key.split(".")
    for p in parts[:-1]:
        obj = obj.setdefault(p, {})
    obj[parts[-1]] = value


def get_dotted(obj, key):
    for p in key.split("."):
        obj = obj[p]
    return obj


def git_lines(*args):
    try:
        out = subprocess.run(["git", "-C", REPO, *args], capture_output=True, text=True)
    except OSError:
        return []
    return out.stdout.splitlines() if out.returncode == 0 else []


def used_numbers():
    """Job numbers already used anywhere. factory/jobs/ is gitignored, so a fresh
    clone has none there: also count job branches, merge commits and the
    "job NNN" refs in the roadmap, releases and issues."""
    nums = {int(d[:3]) for d in os.listdir(JOBS) if re.match(r"^\d{3}-", d)}
    text = git_lines("for-each-ref", "--format=%(refname:short)", "refs/heads/factory/", "refs/remotes/")
    text += git_lines("log", "--all", "--merges", "--format=%s")
    for rel in ("roadmap.md", "releases.md", "issues"):
        p = os.path.join(REPO, "factory", rel)
        files = [os.path.join(p, f) for f in os.listdir(p)] if os.path.isdir(p) else [p]
        for f in files:
            if os.path.isfile(f):
                with open(f, errors="replace") as fh:
                    text += fh.read().splitlines()
    for line in text:
        nums.update(int(n) for n in re.findall(r"factory/(\d{3})-", line))
        nums.update(int(n) for n in re.findall(r"\bjob:?\s+(\d{3})\b", line))
    return nums


def claim(slug):
    os.makedirs(JOBS, exist_ok=True)
    slug = re.sub(r"[^a-z0-9-]+", "-", slug.lower()).strip("-")
    while True:
        job_id = f"{max(used_numbers(), default=0) + 1:03d}-{slug}"
        try:
            os.mkdir(os.path.join(JOBS, job_id))  # fails if another session took it
            return job_id
        except FileExistsError:
            continue


def new(job_id, pairs):
    name = os.path.basename(REPO)
    job = {
        "id": job_id,
        "kind": "feature",
        "feature": "",
        "branch": f"factory/{job_id}",
        "worktree": os.path.join(os.path.dirname(REPO), f"{name}-factory", job_id),
        "simulator": f"factory-{name}-{job_id}",
        "stage": "spec",
        "round": 0,
        "resumes": 0,
        "reviews": {k: "pending" for k in ("code", "privacy", "ux", "release")},
        "checks": "pending",
        "issue": None,
        "roadmap": None,
        "blocked_at": None,
        "confirm": None,  # true → the user confirms the spec before the build; then "waiting", "done"
        "created": now(),
        "history": [{"at": now(), "stage": "spec"}],
    }
    for k, v in pairs.items():
        set_dotted(job, k, v)
    save(job)
    print(json.dumps(job, indent=2))


def update(job_id, pairs, note=None):
    job = load(job_id)
    for k, v in pairs.items():
        if k == "stage" and v not in STAGES:
            sys.exit(f"unknown stage {v!r}; one of {sorted(STAGES)}")
        set_dotted(job, k, v)
        if k == "stage":
            job["history"].append({"at": now(), "stage": v, **({"note": note} if note else {})})
    save(job)


def listing(active_only):
    if not os.path.isdir(JOBS):
        return
    for d in sorted(os.listdir(JOBS)):
        if not os.path.exists(path(d)):
            continue
        j = load(d)
        if active_only and j["stage"] not in ACTIVE | {"needs-input"}:
            continue
        reviews = " ".join(f"{k}:{v}" for k, v in j.get("reviews", {}).items())
        extra = f" · {j['issue']}" if j.get("issue") else ""
        print(f"{j['id']:<32} {j['stage']:<12} round {j['round']}  {reviews}{extra}")


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    cmd, args = argv[1], argv[2:]
    pairs = {}
    note = None
    for a in args[1:]:
        if "=" in a:
            k, v = a.split("=", 1)
            if k == "note":
                note = v
            else:
                pairs[k] = parse_value(v)
    if cmd == "claim":
        print(claim(args[0]))
    elif cmd == "new":
        new(args[0], pairs)
    elif cmd == "get":
        job = load(args[0])
        val = get_dotted(job, args[1]) if len(args) > 1 else job
        print(val if isinstance(val, str) else json.dumps(val, indent=2))
    elif cmd == "set":
        update(args[0], pairs, note)
    elif cmd == "list":
        listing("--active" in args)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
