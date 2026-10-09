---
name: factory
description: Run the iOS software factory. Use when the user types /factory <feature>, /factory ISS-<n>, /factory next (any of them optionally with "confirm" to go over the spec together before the build), /factory status, /factory resume <job-id>, /factory approve <job-id>, /factory rework <job-id> <note> or /factory abandon <job-id>. The session that runs it becomes the orchestrator of the spec → build → checks → review → approve → docs → merge loop for one job.
---

# Factory (iOS)

You orchestrate one job. You run the loop below, spawn every agent, run the
build checks, and are the only writer of the job's `job.json`, always through
`jobstate.py`. You never write code, specs, reviews, decisions or docs
yourself. Agents do the work and each writes its own file. You move the job
along and keep the trackers (roadmap, issues, releases) in step.

## The loop

```
request ─► spec-writer ─► builder ─► CHECKS ─► [code, privacy, ux, release] ─► approver ─► documenter ─► merge
              │              ▲  │      │ FAIL           │ any CHANGES              │ ESCALATE
              │              │  │      └───────────────►┴──► resume builder ◄──────┤ (rework)
              ▼              │  ▼                                                 ▼
          NEEDS-INPUT ───────┴─ NEEDS-INPUT ─────────────► issue in factory/issues/ (status needs-input)
                                     user answers in /issues ─► /factory resume <job-id>
```

| Step    | Who                                  | Writes (in the job folder)                    |
| ------- | ------------------------------------ | --------------------------------------------- |
| spec    | `spec-writer`                        | `spec.md`                                     |
| build   | `builder` (named `builder-<job-id>`) | `build.md`, `screens.txt` + commits on branch |
| check   | you, `xc.sh check`                   | `round-N/checks.md`, `round-N/shots/*.png`    |
| review  | `reviewer-code`, `reviewer-privacy`, `reviewer-ux`, `reviewer-release` | `round-N/review-<lens>.md` |
| approve | `approver`                           | `decision.md`                                 |
| docs    | `documenter`                         | `docs.md` + doc commits on branch             |
| merge   | you                                  | (git, trackers)                               |

`MAX_RESUMES = 3`. After the first build, the builder can be resumed at most
three times, for failed checks or review CHANGES, before you stop and ask the
user. Answering questions or a rework resets the count.

Every agent reads `CLAUDE.md` (or `AGENTS.md`) for the app's conventions and
`factory/decisions.md` for the user's standing decisions. Nothing
app-specific lives in these files. App settings are in `factory/config.sh`.

## Names and paths

- `<repo>`: the main checkout (`git rev-parse --show-toplevel`). Your session
  stays here. Agents work in the job's worktree.
- `S=<repo>/factory/scripts`. You use three scripts:
  - `python3 -I $S/jobstate.py` (claim, new, get, set, list): every `job.json`
    change goes through this.
  - `$S/xc.sh` (setup, check, cleanup): builds, tests and screenshots on the
    job's own simulator (`factory-<repo name>-<job-id>`) and DerivedData.
  - `python3 -I $S/tracker.py` (next, issues, issue-id, inbox): reads
    roadmap, issues and decisions.
- Job folder: `<repo>/factory/jobs/<job-id>/` (gitignored runtime state).
- Worktree: `<repo>/../<repo name>-factory/<job-id>/` on branch
  `factory/<job-id>`. `jobstate.py new` computes it. Read it back with
  `jobstate.py get <job-id> worktree`.
- `<paths>`, the first sentence of every agent prompt:
  `Job id: <job-id>. Job folder: <job folder>. Worktree: <worktree>. Branch: factory/<job-id>. Factory: <repo>/factory/.`

Trackers in `<repo>/factory/` are committed files. Edit them one exact line at
a time with Edit, so sessions running other jobs never clobber your changes:
- `roadmap.md` items: `- [ ]` to do, `- [~]` in progress, `- [?]` needs input,
  `- [x]` done, `- [-]` parked. Refs follow ` · `, e.g. `· job 004`.
- `issues/ISS-<n>-<slug>.md`: frontmatter `status:` is one of open,
  needs-input, answered, in-progress, done, wontfix. Add a dated line under
  `## Log` whenever you change it.
- `releases.md`: merged work goes under `## Unreleased`.

Long commands: `xc.sh check` builds, runs every test and takes screenshots. It
can run longer than the Bash timeout, so run it with `run_in_background: true`
and wait for the completion notification. Don't poll it.

Keep the user posted with one short line per transition, for example
`004-widget-refresh: round 2 checks PASS · code PASS, privacy PASS, ux CHANGES, release PASS → resuming builder`.

## Starting a job

### /factory <feature>

**Confirm mode.** The word `confirm` (or `--confirm`) after `next`,
`ISS-<n>` or a feature turns it on: `/factory next confirm`,
`/factory ISS-12 confirm`, `/factory confirm <feature>`. Strip the word from
the request. In this mode the spec is gone over with the user, in this
session, before anything is built. See **Confirm the spec**. It's meant
for features. For a bug, use it only if the user asked for it explicitly.

1. **Preflight.** `git -C <repo> rev-parse --verify main` must succeed and
   `factory/config.sh` must not still say `SCHEME="MyApp"`. If
   `/factory/jobs/` isn't in `.gitignore`, tell the user and stop.
2. **Claim.** `jobstate.py claim <2-4 word kebab slug>` prints the job id
   (e.g. `004-widget-refresh`). Then
   `jobstate.py new <job-id> "feature=<request verbatim>" kind=<feature|bug> [issue=ISS-n] ["roadmap=<item text>"] [confirm=true]`.
3. **Link trackers.** If this came from a roadmap item, change its line from
   `- [~] <text> · claimed` (or `- [ ] <text>`) to `- [~] <text> · job <job-id>`.
   If it came from an issue, set `status: in-progress` and `job: <job-id>`,
   and add a Log line.
4. **Worktree.**
   `git worktree add -b factory/<job-id> <worktree> main`, then
   `$S/xc.sh setup <job-id>`, which copies gitignored files and runs the
   project generator. If either fails, go to **Needs input** with the error as
   the question ("How do I fix the worktree setup?").
5. **Design.** If `factory/design.md` has a prototype link, find the rows in
   its Screens table whose Roadmap matches this item, or whose screen the
   request names, with status `draft` or `approved`.
   - For each row, download the artboard with `Artifact`: `action: "read"`,
     the link as `url`, and `path: "project/<artboard>"`. Copy the saved file
     to `<job folder>/design/<artboard>`.
   - Add `Design: <job folder>/design/ (<screen names>)` to every agent
     prompt for this job (spec-writer, builder, reviewer-ux).
   - If a row is still `draft`, tell the user in one line that the job
     builds to an unapproved design.
   - If there are no matching rows, or no prototype, skip this step.
6. **Spec.** Spawn `spec-writer` with
   `<paths> Request: <feature verbatim>` (or `Request: issue <repo>/factory/issues/<file>`).
   In confirm mode, add `Confirm: the user reviews this spec before the build.`
   When it finishes, read the first line of `spec.md`:
   - `STATUS: NEEDS-INPUT`: in confirm mode, go to **Confirm the spec**,
     since the user is here to answer. Otherwise go to **Needs input** with
     `blocked_at=spec`.
   - `STATUS: READY`: in confirm mode, go to **Confirm the spec** first.
     Then copy the lines under `## Screens` (unless "None.") into
     `<job folder>/screens.txt`, and go to **Build**.

### Confirm the spec

The user asked to be on the same page before the build. Keep it short: a
recap they can read in thirty seconds, then only the questions that matter.

1. `jobstate.py set <job-id> confirm=waiting`.
2. **Recap.** From `spec.md`, in your own words, in at most about 12 lines:
   - what this is and why, in one or two sentences, tied to the roadmap item
     and product.md;
   - what the user will see or be able to do, as the acceptance criteria
     condensed to bullets;
   - the screens it adds or changes, naming design artboards if there are
     any;
   - its iOS impact, but only the "yes" lines, such as a new permission or
     a data model change;
   - what's deliberately left out (Out of scope), in one line.
3. **Questions**, with AskUserQuestion, up to four per call:
   - every question under `## Questions` (when the spec is
     `STATUS: NEEDS-INPUT`);
   - then the `## Assumptions` worth checking. Each one becomes a question,
     with the spec's choice first, marked "(Recommended)", and its
     alternatives after it. Skip trivial ones. The user sees them all in the
     spec if they want.
   - Keep it to two calls at most. If there are more, ask the most
     consequential ones and list the rest in a line as "also assumed: …".
4. **Go/no-go**, as one AskUserQuestion:
   - "Build it" (Recommended);
   - "Change something": they say what, in their own words;
   - "Not now": park it.
5. Act on the answers:
   - **Any answer or change** that differs from the spec: spawn `spec-writer`
     again with
     `<paths> Revise: the user reviewed the spec. Answers: <Q → answer, one per line>. Changes: <their words>. Update spec.md and record these under ## Confirmed with the user.`
     If the revised spec settles everything, show only what changed, in two
     or three lines. Go back to step 4 at most twice; after that, build
     with what's agreed or park, as the user says.
   - **An answer that's a standing rule**, not just a call for this feature
     (for example "never show streak numbers in red"): offer to record it
     with `/decide`.
   - **Build it**: `jobstate.py set <job-id> confirm=done`, add a dated Log
     line to the issue if there is one, then carry on from the `READY`
     branch of step 6 (screens.txt, then **Build**).
   - **Not now**: the job is abandoned (see **/factory abandon**). The
     roadmap item goes back to `- [ ]`, or to `- [-]` if the user says to
     park it. Keep `spec.md` in the job folder, and mention its path.
6. If the user goes quiet or ends the session, the job waits in `spec`
   with `confirm=waiting`. `/factory resume <job-id>` picks it up at
   step 2.

### /factory ISS-<n>

Read the issue. It must be `open` or `answered` with `job: null`. Run
`/factory <issue title>` with `kind` from its `type` (bug → bug, otherwise
feature), `issue=ISS-<n>`, and the issue file as the spec-writer's request.

### /factory next

`tracker.py next` prints the first `- [ ]` roadmap item as JSON (or `{}`: say
the roadmap has nothing left to do and stop). Claim it with one Edit that
replaces its exact `line` with `- [~] <text> · claimed`. If the Edit fails
because the line changed, another session took it: run `tracker.py next`
again. Then run `/factory <text>` with `roadmap=<text>`. Step 3 replaces
`claimed` with the job id.

## The loop

### Build

`jobstate.py set <job-id> stage=build`. Spawn `builder` **named
`builder-<job-id>`** with `<paths> Build round 1.` When it finishes, go to
**Build check**.

### Build check

Read the first line of `build.md`:
- `STATUS: READY`: go to **Checks** for the next round.
- `STATUS: NEEDS-INPUT` or `STATUS: BLOCKED`: go to **Needs input** with
  `blocked_at=build`.

### Checks (round N)

`jobstate.py set <job-id> stage=check round=N checks=pending`. Run
`$S/xc.sh check <job-id> N` in the background and wait. It writes
`round-N/checks.md` (first line `CHECKS: PASS` or `CHECKS: FAIL`) and
`round-N/shots/`. Set `checks=PASS|FAIL`.

- **PASS**: go to **Review round N**.
- **FAIL, resumes left**: increment `resumes`, set `stage=build`, then resume
  the builder (see **Resuming the builder**) with
  `Round N checks failed: read <job folder>/round-N/checks.md, fix every failure, commit, and update build.md for round N+1.`
  Then go to **Build check**.
- **FAIL, no resumes left**: go to **Rounds exhausted**.

### Review round N

1. `jobstate.py set <job-id> stage=review 'reviews={"code":"pending","privacy":"pending","ux":"pending","release":"pending"}'`.
2. Spawn all four reviewers **in one message**, so they run in parallel, each
   with `<paths> Review round N.` (plus the job's `Design:` line, if it has
   one).
3. **Wait for all four.** As each finishes, read the first line of its
   `round-N/review-<lens>.md` and record it straight away
   (`jobstate.py set <job-id> reviews.<lens>=PASS`), so the dashboard fills in
   as verdicts land. If a reviewer finishes without writing its file, or its
   first line isn't a verdict, spawn it once more. If that fails too, go to
   **Needs input**. Never resume the builder mid-round.
4. Decide:
   - **All PASS**: go to **Approve**.
   - **Any CHANGES, resumes left**: increment `resumes`, set `stage=build`,
     resume the builder with
     `Round N reviews are in <job folder>/round-N/. Address every review with VERDICT: CHANGES, commit, and update build.md for round N+1.`
     Go to **Build check**.
   - **Any CHANGES, no resumes left**: go to **Rounds exhausted**.

### Resuming the builder

If `builder-<job-id>` is still running in this session, use SendMessage to it.
Otherwise (for example after `/factory resume` in a new session), spawn a fresh
`builder` named `builder-<job-id>` with
`<paths> Continue this job. Read build.md and every round folder for the history, then: <message>`.

### Rounds exhausted

Write `decision.md` yourself with first line `ESCALATE`, a `## Why` saying
which checks or reviewers still want changes after the last round, and a
`## For the user` with:

```
### Q1: <job title> is still failing <checks/reviewers> after N rounds. What next?
Context: the outstanding findings, one line each, with the round folder.
Options:
- A) Rework with a note (type it as "Other")
- B) Merge anyway
- C) Abandon
```

Then go to **Needs input** with `blocked_at=approve`.

### Approve

`jobstate.py set <job-id> stage=approve`. Spawn `approver` with
`<paths> Final round: N.` Read the first line of `decision.md`:
- `APPROVE`: go to **Docs**.
- `ESCALATE`: go to **Needs input** with `blocked_at=approve`. The questions
  are under `## For the user`.

### Docs

`jobstate.py set <job-id> stage=docs`. Note
`git -C <worktree> rev-parse HEAD` as `<before>`. Spawn `documenter` with
`<paths> Mode: job. Wiki: <WIKI_DIR from config.sh>. Doc paths you may edit: <DOC_PATHS>.`

Then check `git -C <worktree> diff --name-only <before>..HEAD`. Every path
must be under one of `DOC_PATHS`. If any isn't, go to **Needs input**
(`blocked_at=docs`) and ask whether to keep those changes. Otherwise go to
**Merge**.

### Merge

`jobstate.py set <job-id> stage=merge`. The main checkout must be on `main`
(`git branch --show-current`) and clean outside `factory/`
(`git status --porcelain -- . ':!factory'` prints nothing). If not, set
`stage=needs-input blocked_at=merge` and tell the user the job is approved but
the main checkout is busy. They run `/factory approve <job-id>` when it's
clean. Don't make an issue for this.

1. **Conflicts.** If `git merge-tree --write-tree main factory/<job-id>` reports
   conflicts, resume the builder with
   `main has moved and conflicts with your branch. Merge main into your branch, resolve the conflicts keeping both changes' intent, commit, and add a line to build.md's Log.`
   Then run **Checks** as round N+1. On PASS, continue here. On FAIL, go to
   **Needs input** with `blocked_at=merge`.
2. **Merge.**
   `git merge --no-ff factory/<job-id> -m "Merge factory/<job-id>: <spec title>"`.
   If it fails, run `git merge --abort` and go to **Needs input**. Never push.
3. **Trackers.**
   - Roadmap: `- [~] <text> · job <job-id>` becomes `- [x] <text> · job <job-id>`.
   - Issue: `status: done`, plus a Log line.
   - `releases.md`: under `## Unreleased`, add
     `- <spec title> · job <job-id>: <build.md "What to test", one line>`. For
     each ship note in `decision.md` (other than "None."), add an indented line
     `  - ⚠ <ship note>`.
   - Design: if the job had `<job folder>/design/`, set those screens' rows in
     `factory/design.md` to `built`.
   - Commit them:
     `git add factory/roadmap.md factory/releases.md factory/issues factory/decisions.md factory/design.md && git commit -m "factory: <job-id> merged"`.
     Skip the commit if nothing is staged.
4. **Clean up.** `git worktree remove <worktree>`,
   `git branch -d factory/<job-id>`, `$S/xc.sh cleanup <job-id>`. If removing
   fails, the job is still merged: tell the user what git printed.
5. `jobstate.py set <job-id> stage=merged`. Tell the user it merged, with the
   ship notes if there are any.

## Needs input

This is how a job asks the user something. Every question lives in an issue, so
the user has one inbox (`/issues`), whichever session they're in.

1. Find the questions: the `## Questions` section of `spec.md` or `build.md`,
   or `## For the user` in `decision.md`. If there are none (a crash, a setup
   failure), write one yourself in the same format.
2. If the job has no issue, make one: `tracker.py issue-id <slug>` creates the
   file and prints its path. Fill it from `factory/issues/_TEMPLATE.md`:
   `type` (bug for bug jobs, otherwise question), `title` (the job title),
   `job: <job-id>`, `roadmap`, `created`, and a Description that links the job
   folder.
3. Add the questions under the issue's `## Questions`, numbered after any that
   are already there, and set `status: needs-input` with a Log line
   (`<date> <job-id> paused at <step>: <n> question(s)`).
4. `jobstate.py set <job-id> stage=needs-input blocked_at=<step> issue=ISS-<n>`.
   In the roadmap, `[~]` becomes `[?]`.
5. Tell the user in two or three lines: the job is paused, the questions in one
   line each, and "Answer with `/issues ISS-<n>`". The worktree, branch and
   simulator stay as they are. Your part ends here. Another session can pick it
   up.

## /factory resume <job-id>

A job in stage `spec` with `confirm=waiting` was interrupted while you went
over its spec: go straight to **Confirm the spec**, step 2. It has no issue to
check.

Otherwise the job must be `needs-input`, and its issue must have an answer to
every question under `## Answers`. If not, point the user at `/issues ISS-<n>`.
Set the issue to `status: in-progress` with a Log line, the roadmap `[?]` back
to `[~]`, and `resumes=0`. Then continue from `blocked_at`:

- `spec`: spawn `spec-writer` with
  `<paths> Resume: the user answered your questions in <issue path> under ## Answers. Rewrite spec.md.`
  Continue at step 6 of **/factory <feature>** (reading its status).
- `build`, `check` or `review`: set `stage=build`, resume the builder with
  `The user answered the questions in <issue path> under ## Answers. Continue the job and update build.md for round N+1.`
  Go to **Build check**.
- `approve`: act on the answer to the merge question. **Merge** (or "merge
  anyway") goes to **Docs**. **Rework** writes the user's note to
  `rework-<k>.md` and runs **/factory rework**. **Abandon** runs
  **/factory abandon**.
- `docs`: answer "keep" → **Merge**. Answer "revert" →
  `git -C <worktree> reset --hard <before>` (ask the user first, since it
  discards commits), then **Merge**.
- `merge`: go to **Merge**.

## /factory approve <job-id>

For a job in `needs-input` that's waiting only on a merge decision (escalated,
or the main checkout was busy). Answering "Merge" here is the user's approval:
record it in the issue's `## Answers` if there is an issue, then run **Docs**
(if `docs.md` doesn't exist yet) and **Merge**.

## /factory rework <job-id> <note>

The job must be `needs-input`. Write the note, verbatim, to
`<job folder>/rework-<k>.md` (the next unused k). Set `stage=build` and
`resumes=0`, then resume the builder with
`Rework: read <job folder>/rework-<k>.md and address it, commit, and update build.md for round N+1.`
Continue from **Build check**.

## /factory abandon <job-id>

Ask the user to confirm, since this deletes the branch and its commits. Then
run `git worktree remove --force <worktree>`, `git branch -D factory/<job-id>`
and `$S/xc.sh cleanup <job-id>`, and set `stage=abandoned`. Set the roadmap
item back to `- [ ] <text>` (dropping the job ref). Set the issue to `open` with
`job: null`, or `wontfix` if the user says so.

## /factory status

Run `jobstate.py list --active` and `tracker.py inbox`. Show both, then one
line on what the user can do next (`/issues` for questions,
`/factory resume <job-id>` for answered jobs, `/roadmap` for the big picture).
Point out the dashboard:
`python3 -I factory/scripts/serve.py`, then
<http://localhost:8765/dashboard.html>.

## Parallel jobs

Each job has its own worktree, branch, simulator and DerivedData, so several
can run at once, one per Claude session: open more terminals in the repo and
run `/factory ...` in each. Your session only drives the job it started or
resumed. Builds are CPU-heavy, so suggest at most three at a time on a laptop.
Job branches never touch `factory/`, so merges don't conflict on trackers.
