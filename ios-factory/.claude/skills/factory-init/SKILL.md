---
name: factory-init
description: Onboard an existing iOS repo into the factory. Scans the repo's docs, plans and notes and the Xcode project, drafts roadmap, decisions, issues, product brief, config and CLAUDE.md changes, asks the user about anything unclear (in rounds), applies everything on a branch, and archives docs whose content has moved. Use when the user types /factory-init (optionally with --refresh), or asks to set up or onboard the factory in a repo.
---

# Factory init

Turns what a repo already knows about itself into the factory's structure, so
the agents start with the full context and there's one source of truth for
plan, decisions and open questions. Nothing is deleted: migrated docs move to
`docs/archive/` with an index of where each piece went.

`S=<repo>/factory/scripts`.

## 0. Preconditions

- `factory/` and `.claude/skills/factory/` exist (copied in, or by
  `install.sh`). If not, tell the user to run
  `<path to ios-factory>/install.sh <repo>` first.
- There's an app to onboard. If the repo has no Xcode project
  (`*.xcodeproj`, `project.yml`, `Project.swift`) and no Swift sources outside
  `factory/`, it's a new app: stop and point to `/factory-new`, which starts
  from an idea file.
- The working tree is clean (`git status --porcelain`). Init ends in one
  reviewable commit, and must not mix with unrelated changes.
- If `factory/roadmap.md` already has real items (not the template's example),
  this repo is already initialised. Offer `--refresh` instead: adopt only docs
  that aren't in `docs/archive/` and aren't known **keep** docs, then merge their
  content into the existing trackers. Never overwrite existing entries.

## 1. Mine

`mkdir -p factory/init` and spawn `doc-miner` with
`Repo: <repo>. Factory: <repo>/factory/. Write drafts to <repo>/factory/init/.`
(add `Mode: refresh. Only these docs: …` for `--refresh`). It writes
`inventory.md`, `summary.md`, `questions.md` and the drafts.

If the inventory has **wiki** docs (or none at all, but there's code to
document), spawn `documenter` with
`Job id: init. Job folder: <repo>/factory/init/. Worktree: <repo>. Branch: none (don't commit). Factory: <repo>/factory/. Mode: seed. Sources: <the wiki docs>. Plan: <repo>/factory/init/wiki-plan.md. Target: <repo>/factory/init/wiki/. Write docs.md to <repo>/factory/init/docs.md.`
This can run while you ask the questions in step 2, unless a question changes
the wiki plan.

Show the user `summary.md` and the inventory table (file → verdict → where
it goes) in a compact form.

## 2. Ask, in rounds

Go through `questions.md` with AskUserQuestion, **up to four questions per
call**, most consequential first. For each one: a header of `Q<n>` plus the
topic, the question, and the options with "(Recommended)" on the first. Use
"Other" for free text.

- Before the first round, tell the user how many questions there are, and
  that any they skip become issues they can answer later in `/issues`.
- After each round, apply the answers to the drafts in `factory/init/` right
  away, and record them in `questions.md` under each question as
  `Answer: …`. An answer can turn a note into a decision, change a roadmap
  status, fill a config value, or change a doc's verdict.
- After every two rounds, ask whether to continue or stop and file the rest
  as issues.
- The user may also say "that's wrong" about anything in the summary. Fix the
  draft and carry on.

Questions the user skips become issues: `status: needs-input`,
`type: question`, with the question in the issue's `## Questions` format and
`job: null`.

## 3. Review

Show the final picture before writing anything:
- the roadmap, rendered from the draft with
  `FACTORY_DIR=factory/init python3 -I $S/tracker.py roadmap` (the same works
  for `decisions` and `issues`);
- decisions: one line each (id, title, scope);
- issues: one line each;
- `config.sh` values, with `TODO(init)` lines highlighted;
- CLAUDE.md changes as before/after;
- the wiki: the page tree (type, title, one-line summary) and the documenter's
  **Source map**, so the user can see every section of the old notes landed
  somewhere;
- docs: **archive** (moving to `docs/archive/`, including the old tech notes
  once the wiki has replaced them), **split** (sections replaced by
  pointers), **keep**.

Ask with AskUserQuestion: "Apply" (Recommended) / "Change something" / "Cancel".
Cancel deletes `factory/init/` and stops.

## 4. Apply on a branch

1. `git switch -c factory/init`.
2. Move the drafts into place: `factory/roadmap.md`, `factory/decisions.md`,
   `factory/releases.md`, `factory/product.md`, `factory/config.sh`, and
   `factory/issues/ISS-*.md`. Keep the format comment blocks at the top of
   roadmap.md and decisions.md.
3. Move `factory/init/wiki/` to `WIKI_DIR` (default `docs/wiki/`), then run
   `python3 -I $S/wiki.py index` and `wiki.py lint`, and fix any errors. Show
   `wiki.py coverage`. Uncovered code is fine at this point, and `/docs audit`
   can fill it in later.
4. Apply `claude-md.patch.md` to CLAUDE.md (or create it). CLAUDE.md should
   point to `docs/wiki/index.md` and keep only conventions, commands and the
   Screens section. Architecture prose moves to the wiki.
5. **Split** docs: replace each migrated section with a one-line pointer, e.g.
   `Status and plan: see factory/roadmap.md (migrated <date>; original in docs/archive/PLAN.md).`
6. **Archive** docs: `git mv <file> docs/archive/<same relative path>`.
   **Untracked or gitignored** docs (often private notes) can't be `git mv`'d
   and must not be committed by surprise. Ask once: move them to
   `docs/archive/` but keep them out of git (add their new path to
   `.gitignore`), commit them, or leave them where they are. Then
   write `docs/archive/README.md`:

   ```markdown
   # Archived docs

   Moved here by /factory-init on <date>. Their content now lives in the factory:

   | Original | Now in |
   | --- | --- |
   | PLAN.md §1–6 | factory/product.md, factory/decisions.md D-001…D-006 |
   | PLAN.md §7 | factory/roadmap.md |
   | TECH_NOTES.md §5 Architecture | docs/wiki/architecture/overview.md |
   | TECH_NOTES.md §7.7 Area progress | docs/wiki/features/area-progress.md |
   | mynotes.txt | factory/issues/ISS-001…ISS-004, factory/roadmap.md M3 |

   Kept for history. Agents don't read this folder; don't update these files.
   ```

7. Grep the repo (CLAUDE.md, README, wiki, scripts) for references to
   archived files and update them to the new location. Also mention any
   references in the user's Claude memory, but don't edit memory without
   asking.
8. Make sure `.gitignore` has `/factory/jobs/` and `/build/`, and delete
   `factory/init/`.
9. Validate: `python3 -I $S/tracker.py roadmap`, `tracker.py decisions` and
   `tracker.py issues` all parse. `bash -n factory/config.sh` passes. If the
   config has no `TODO(init)` left, run `$S/xc.sh build main` in the background
   and report the result.
10. Commit `Factory init: roadmap, decisions, issues, product brief, wiki; archive migrated docs`,
   then ask whether to merge `factory/init` into `main` now. Merge with
   `--no-ff` on yes. Never push.

## 5. Hand-off

Tell the user what landed (counts), the issues created from skipped questions,
any `TODO(init)` config values left, and the obvious first job. Usually that's
adding the DEBUG `-factoryScreen` / `-factoryNoPrompts` hooks from CLAUDE.md's
Screens section, so the UX reviewer can see screens:
`/factory Add DEBUG launch arguments for factory screenshots (see CLAUDE.md Screens)`.
Then `/roadmap` to see the plan.
