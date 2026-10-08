---
name: docs
description: Check and update the project wiki against the code, on its own branch, and merge it, or show its health (lint, coverage, stale pages). Use when the user types /docs, /docs status or /docs audit, or asks to bring the docs or wiki up to date.
---

# Docs

The factory's documenter updates the wiki after every approved job. This skill
covers everything else: commits made outside the factory, pages that drifted,
or code no page covers yet.

Read `factory/config.sh` for `WIKI_DIR` and `DOC_PATHS`.
`S=<repo>/factory/scripts`.

## /docs status

Run `python3 -I $S/wiki.py lint`, `wiki.py coverage` and `wiki.py stale` in
the main checkout. Show a short health report: page count by type, coverage
percentage, errors, stale pages, and uncovered folders (grouped, not every
file). Suggest `/docs audit` if there's anything to fix.

## /docs audit (or /docs)

1. **Job.** Claim a job (`jobstate.py claim docs-audit`), then
   `jobstate.py new <job-id> kind=docs "feature=Documentation audit" stage=docs`.
   Create the worktree:
   `git worktree add -b factory/<job-id> <worktree> main`. No simulator is
   needed.
2. **Document.** Spawn `documenter` with
   `Job id: <job-id>. Job folder: <job folder>. Worktree: <worktree>. Branch: factory/<job-id>. Factory: <repo>/factory/. Mode: audit. Wiki: <WIKI_DIR>. Doc paths you may edit: <DOC_PATHS>.`
   Add any focus the user gave (for example "only the sync pages").
3. **Check.** `git -C <worktree> diff --name-only main..HEAD` must list only
   doc paths. Show the user `docs.md` and the diff stat. Offer the full diff.
4. **Merge** after the user says yes. Follow the factory skill's **Merge**
   section (checks the main checkout is clean, merges with `--no-ff`, removes
   the worktree and branch). Skip the tracker and release steps. On no, run
   `/factory abandon <job-id>`.
5. List the mismatches the documenter couldn't fix, and offer to file each as
   an issue (`/issues new`).
