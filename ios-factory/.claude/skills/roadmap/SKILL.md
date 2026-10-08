---
name: roadmap
description: Show and edit the product roadmap with what's done, in progress, waiting on the user and still to do. Use when the user types /roadmap, /roadmap add, /roadmap milestone, /roadmap move, /roadmap park, /roadmap import <file>, /roadmap sync or /roadmap open, or asks what's left, what's been done, or what's next.
---

# Roadmap

`factory/roadmap.md` is the plan: milestones (`## ` headings, optional `Goal:`
line) with one item per line:

```
- [ ] to do   - [~] in progress   - [?] waiting on the user   - [x] done   - [-] parked
- [x] Home-screen widget · job 004 · ISS-002 · TF 1.1 (202610081932)
```

Refs after ` · ` link the item to its job, issue and the TestFlight build it
shipped in. `/factory next` takes the first `- [ ]` from the top, so the order
of items is the priority order. The factory updates statuses as jobs move.
This skill shows the roadmap and lets the user shape it.

`T="python3 -I <repo>/factory/scripts/tracker.py"`.

## /roadmap

1. Run `$T roadmap` and show its output as is, in a code block (it has
   progress bars).
2. Under it, add up to four short lines: what's in progress (and which jobs),
   what's waiting on the user (`/issues`), what's next in line, and what
   shipped in the last TestFlight build (from `factory/releases.md`).
3. Mention once that the dashboard has a visual Roadmap tab:
   `python3 -I factory/scripts/serve.py` →
   <http://localhost:8765/dashboard.html#roadmap>.

## /roadmap add [<milestone>] <item>

Append `- [ ] <item>` to the milestone (by number or name; default: the first
milestone that still has open items). If the user says it's urgent, put it
first among that milestone's `[ ]` items. Keep item text short. Detail belongs
in an issue: offer `/issues new` if the user gives more than a line.

## /roadmap milestone <name> [goal]

Add `## M<n> · <name>` (plus a `Goal:` line) at the end, or where the user
says.

## /roadmap move <item> <up|down|top|milestone>, /roadmap park <item>, /roadmap unpark <item>

Reorder, move between milestones, or set `[-]` / `[ ]`. Never change `[~]` or
`[?]` items by hand: a job owns them. Point the user at `/factory abandon` or
`/issues` instead.

## /roadmap import <file>

Seed the roadmap from an existing plan (for example a PLAN.md with phases and
a status section). Read the file, map its phases to milestones and its features
to items, and mark items done or in progress as the file says. Show the
proposed roadmap.md and write it only after the user confirms. Keep the
source file as it is. Afterwards, suggest the user treat `factory/roadmap.md` as
the status source of truth (and update CLAUDE.md or memory if they used to say
otherwise).

## /roadmap sync

Reconcile the roadmap with reality:
- an item with `· job <id>` whose job is `merged` → `[x]`; `needs-input` →
  `[?]`; `abandoned` → `[ ]` with the job ref removed;
- an item with an issue ref whose issue is `done` → `[x]`;
- a merged job with a `roadmap` value whose item is missing → offer to add it
  as done.
Show the changes and apply them with one Edit per line.

## /roadmap open

Start the dashboard in the background
(`python3 -I <repo>/factory/scripts/serve.py`) if port 8765 is free, and
give the user <http://localhost:8765/dashboard.html#roadmap>.
