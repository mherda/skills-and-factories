---
name: docs
description: Keep the project wiki consistent with the code. /docs status shows its health (lint, coverage, stale pages); /docs sync [<commit|range>] updates the pages affected by recent or given commits (e.g. manual changes made outside the factory); /docs audit re-checks the whole wiki. Use when the user types any of these, or asks to check, sync or update the docs or wiki after changing code.
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

## /docs sync [<commit | range>]

The "I changed code myself, update the docs" command. The post-commit hook
suggests it.

1. **Scope.**
   - With a commit or range (`HEAD`, `a1b2c3d`, `main~5..main`):
     `wiki.py pages-for --commit <sha>` (or `--range <a..b>`) gives the
     affected pages and uncovered files.
   - With no argument: `wiki.py stale` (pages whose code changed after the page
     did) plus `wiki.py lint` errors, plus `wiki.py coverage` filtered to files
     changed in the stale pages' commits.
   Show the scope in a few lines. If it's empty, say the wiki is in sync and
   stop.
2. **Job.** As in step 1 of audit below, with the slug `docs-sync`.
3. **Document.** Spawn `documenter` with
   `Job id: <job-id>. Job folder: <job folder>. Worktree: <worktree>. Branch: factory/<job-id>. Factory: <repo>/factory/. Mode: sync. Wiki: <WIKI_DIR>. Doc paths you may edit: <DOC_PATHS>. Pages: <list>. Uncovered files: <list>. Commits: <range, if given>.`
4. Then steps 3–5 of audit below (check paths, show docs.md and the diff,
   merge on yes).

## /docs hooks

Report whether the git hooks are installed: check `.git/hooks/pre-commit` and
`post-commit` (via `git rev-parse --git-common-dir`). Both should be symlinks
to `factory/hooks/`. If they're missing (common on a fresh clone, because
hooks aren't versioned), offer to link them. Don't overwrite an existing hook.
Show the user how to call ours from theirs instead.

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
