# Android Factory: Tech Notes

How the factory works inside, for when you want to change it. The README covers
using it.

## Contents

1. [The moving parts](#1-the-moving-parts)
2. [Job lifecycle](#2-job-lifecycle)
3. [Files and formats](#3-files-and-formats)
4. [Scripts](#4-scripts)
5. [Concurrency: running jobs in parallel](#5-concurrency-running-jobs-in-parallel)
6. [The question → answer → resume loop](#6-the-question--answer--resume-loop)
7. [Docs and releases](#7-docs-and-releases)
8. [The wiki](#8-the-wiki)
9. [Onboarding (/factory-init)](#9-onboarding-factory-init)
10. [Changing the factory](#10-changing-the-factory)

## 1. The moving parts

```
.claude/
  skills/
    factory/SKILL.md     orchestrator: the loop, job.json, trackers, merge
    issues/SKILL.md      inbox: list, answer (AskUserQuestion), resume
    bug/SKILL.md         file a bug, then fix now / roadmap / track
    decide/SKILL.md      append / supersede entries in decisions.md
    roadmap/SKILL.md     show (progress bars), add, move, park, import, sync
    play/SKILL.md        checklist (incl. release smoke test) → confirm → upload → record
    docs/SKILL.md        docs-only audit job
    factory-init/SKILL.md  onboarding: doc-miner → questions in rounds → apply on a branch → archive
    design/SKILL.md      Claude Design canvas: new, add, revise (incl. canvas comments), approve → design.md
    factory-new/SKILL.md   new app: app-planner shape → you approve suggestions → app-planner draft → questions → scaffold.py → build/test/shots → wiki seed
  agents/                one file per agent (frontmatter: tools + model)
factory/
  config.sh              per-app settings, sourced by the shell scripts
  product.md             committed: product brief (what, who, tone, principles, not doing)
  roadmap.md             committed tracker
  decisions.md           committed tracker
  releases.md            committed tracker
  design.md              committed: prototype link, visual direction, screen rows (draft/approved/built)
  UPSTREAM.md            committed: fixes to factory-owned files made in this app, not yet ported to android-factory
  issues/                committed tracker, one file per issue (+ _TEMPLATE.md)
  jobs/                  gitignored runtime state, one folder per job
  dashboard.html         read-only view of all of the above
  templates/wiki/        seed for docs/wiki: index.md, glossary.md, _templates/ per page type
  templates/app/         starter app for /factory-new ({{APP}} placeholders, __PKG__ in paths)
docs/wiki/               (in the app repo) the project wiki, kept by the documenter
  scripts/
    jobstate.py          the only writer of job.json
    tracker.py           read-side of roadmap / issues / decisions; id claiming
    wiki.py              wiki: pages-for (paths/--diff/--commit/--range/--staged), coverage, stale, lint, index, verify
  hooks/
    pre-commit           wiki lint: blocks wiki-touching commits on errors, warns otherwise
    post-commit          lists wiki pages a commit may have made stale (silent on factory/* and merges)
    droid.sh             build / test / run / screenshot / smoke per job, one emulator each
    test_summary.py      JUnit XML + Gradle log → markdown; Lint XML → markdown
    sensitive_paths.py   changed files that need Android-specific care
    play.sh              signed bundle + upload to a Play track (honours VERSION_CODE)
    serve.py             dashboard server (deep connection queue, no-cache)
```

**Skills vs agents.** Skills run in your session and talk to you: picking
from the inbox, confirming uploads. Agents are subagents with narrow tools and
one output file each. They never talk to you directly. When they need you,
they write questions into their output file, and the orchestrator moves them
into an issue.

**Agents get context from files, not the conversation.** Every prompt starts
with the same `<paths>` sentence: job id, job folder, worktree, branch and
factory folder. Everything else comes from `CLAUDE.md`, `decisions.md` and the
job folder. That's what makes a job resumable from a different session days
later.

**Each file has one writer.**

| File | Writer |
| --- | --- |
| `job.json` | orchestrator, via `jobstate.py` |
| `spec.md` | spec-writer |
| `build.md`, `screens.txt` | builder (screens.txt is seeded by the orchestrator from the spec) |
| `round-N/checks.md`, `round-N/shots/` | `droid.sh check` |
| `round-N/review-<lens>.md` | the reviewer for that lens |
| `decision.md` | approver (or the orchestrator when rounds run out) |
| `docs.md` | documenter |
| `rework-k.md` | orchestrator (your note, verbatim) |
| `decisions.md` | you, via `/decide` or `/issues` |
| issues | `/bug`, `/issues`, and the orchestrator (questions, status, log) |

## 2. Job lifecycle

Stages in `job.json`:

```
spec → build → check → review → approve → docs → merge → merged
  │      │       │        │        │        │       │
  └──────┴───────┴────────┴────────┴────────┴───────┴──► needs-input ──(/factory resume)──► back to blocked_at
                                                       └──► abandoned (/factory abandon)
```

- **Round N** starts at **check**. Checks FAIL counts as a builder resume, just
  like review CHANGES. `MAX_RESUMES = 3` per stretch. Answering questions or
  a rework resets the count.
- **check → review** only on `CHECKS: PASS`. Reviewers never see a red build.
- **approve → docs** on `APPROVE`. The documenter commits on the job branch,
  so docs land in the same merge as the code. The orchestrator then checks
  that the documenter only touched `DOC_PATHS`.
- **merge** first checks that the main checkout is on `main` and clean outside
  `factory/`. If `git merge-tree` predicts conflicts, the builder merges `main`
  into the branch and a fresh check round runs before merging.
- `blocked_at` records which step to go back to on resume: `spec`, `build`,
  `approve`, `docs` or `merge`.

Each agent's first line is machine-read:

| File | First line |
| --- | --- |
| spec.md | `STATUS: READY` / `STATUS: NEEDS-INPUT` |
| build.md | `STATUS: READY` / `STATUS: NEEDS-INPUT` / `STATUS: BLOCKED` |
| checks.md | `CHECKS: PASS` / `CHECKS: FAIL` |
| review-*.md | `VERDICT: PASS` / `VERDICT: CHANGES` |
| decision.md | `APPROVE` / `ESCALATE` |
| docs.md | `DOCS: UPDATED` / `DOCS: NO-CHANGE` |

## 3. Files and formats

### job.json

```json
{
  "id": "004-widget-refresh", "kind": "feature",
  "feature": "Refresh the widget at midnight",
  "branch": "factory/004-widget-refresh",
  "worktree": "/Users/you/projects/explore-claim-factory/004-widget-refresh",
  "stage": "review", "round": 2, "resumes": 1,
  "checks": "PASS",
  "reviews": { "code": "PASS", "privacy": "PASS", "ux": "pending", "release": "CHANGES" },
  "issue": "ISS-007", "roadmap": "Home-screen widget", "blocked_at": null,
  "created": "…", "updated": "…",
  "history": [ { "at": "…", "stage": "spec" }, { "at": "…", "stage": "build" } ]
}
```

`jobstate.py set` takes `key=value` pairs, with dotted keys (`reviews.ux=PASS`)
and JSON values (`issue=null`, `round=2`). A change to `stage` appends to
`history`, which feeds the dashboard timeline. Writes are atomic (temp file +
rename), so the dashboard never reads half a file.

### Issue files

YAML-ish frontmatter (`key: value`, with `# comments` allowed after values),
then `## Description`, `## Questions` (`### Q<n>: …?` with Context and
lettered Options, the recommended one first), `## Answers`
(`### A<n> (to Q<n>) · <date>`) and `## Log`. An issue has unanswered
questions when there are more `### Q` headings than `### A` headings. The
dashboard counts them the same way.

### Roadmap

`## ` milestones, an optional `Goal:` line, then `- [m] text · ref · ref` items
with m being one of ` ~ x ? -`. Refs: `job <id>`, `ISS-<n>`,
`Play <version name> (<version code>)`, or anything else (shown as a plain chip).

### Decisions

```
## D-<n> · <date> · <title>
Scope: …
Decision: …
Why: …
Source: user | ISS-<n>
Status: active | escalate | superseded by D-<m>
```

HTML comments in roadmap.md and decisions.md are ignored by the parsers, so
the format notes at the top of each file are safe.

## 4. Scripts

### droid.sh

Everything Android-specific about building lives here. Agents call it instead
of `./gradlew` with a device or `adb`, so they never pick a device or port
themselves.

- **Emulator per job**: a headless copy of `AVD_NAME` started with
  `-read-only -no-snapshot`, so any number of copies of one AVD run at once,
  each boots clean, and the AVD itself is never written. Each job claims an
  even port from 5580 with an atomic `mkdir` under
  `~/.android-factory/ports/`, so the serial is `emulator-<port>`. The
  port, PID and emulator log live in `~/.android-factory/<repo>/<job>/`, and
  `cleanup` kills the emulator and frees the port.
- **One start at a time**: two copies of an AVD booting at the same moment
  corrupt each other's overlay images ("Image is not in qcow2 format"), so
  starts take a lock (`~/.android-factory/start.lock`) until the device is
  online. Booting takes about a minute; a job's emulator then stays up
  between rounds.
- **Repeatable devices**: after boot, animations are off (for UI tests), the
  screen stays on, the keyguard is dismissed, and the status bar is in demo
  mode (12:00, full battery and signal, no notification icons). SystemUI can
  miss demo mode right after boot, so `shots` applies it again. The emulated
  location is set from config.
- **Build output** stays in each worktree's own `build/` and `.gradle/`
  folders, so nothing is shared but Gradle's download cache (safe, it's
  locked) and the daemon.
- **`setup`** copies `COPY_INTO_WORKTREE` files (gitignored ones such as
  `local.properties` or `google-services.json`) from the main checkout, then
  runs `SETUP_CMD`. `build` and `check` re-run setup each time.
- **`build`** assembles the variant's app, unit tests and UI tests:
  `assemble<Variant>`, `assemble<Variant>UnitTest`,
  `assemble<Variant>AndroidTest`.
- **`test`** runs `test<Variant>UnitTest` in every module, then
  `connected<Variant>AndroidTest` on the job's emulator (`ANDROID_SERIAL`),
  with `--continue` so a unit failure doesn't hide UI results. It deletes old
  result folders first, copies every JUnit XML into `<out>/junit/`, and
  writes `test-summary.md` (result, counts, failures, Gradle's "What went
  wrong", Kotlin compiler errors and warnings) via `test_summary.py`. Extra
  arguments replace the default tasks, for filtered runs. It skips the
  `UI_TEST_SCREENS` class (a `notClass` runner argument), which `shots` runs
  separately.
- **`shots`** installs the debug APK (its package is read with `aapt2`, so an
  `applicationIdSuffix` is fine), grants `PERMISSION_GRANTS`, and then, for
  each variant (light, dark = `cmd uimode night yes`, large-text = font scale
  `LARGE_TEXT_SCALE`), cold-starts each screen with `am start -S` plus its
  extras (or a `url:` deep link), waits `SCREEN_WAIT`, and takes a
  `screencap`. If `UI_TEST_SCREENS` is set, it runs that class per variant and
  copies the PNGs its tests saved with TestStorage (AGP pulls them into
  `build/outputs/connected_android_test_additional_output/`). A connected test
  run uninstalls the app, so each variant installs it again.
- **`smoke`** builds the release variant (R8), installs it, clears the crash
  log, launches it, screenshots it and fails if it crashed or exited. Without
  an upload key the release build is signed with the debug key, just so it
  installs.
- **`check`** = setup + test + `LINT_TASK` (Lint errors fail the round) +
  shots + `sensitive_paths.py` → `checks.md`. Run by the orchestrator in the
  background. It takes a few minutes, mostly the first emulator boot.
- **`main`** as a job id means "the main checkout". `/play` uses it for the
  pre-release test run and the smoke test.

### sensitive_paths.py

Groups changed files (`main...HEAD`) by why they need care: the manifest,
backup and data transfer rules, the network security config, Gradle build
files and SDK levels, dependencies (the version catalog), R8 rules, services
config, the data model (globs from config, Room's exported schemas, `.proto`
files, plus any Kotlin/Java diff line touching a Room annotation such as
`@Entity` or `@Database`), release tooling, and factory files (which job
branches must never touch). Reviewers and the approver read this section of
`checks.md` instead of each grepping the diff their own way.

### tracker.py / jobstate.py

Read-only views (`roadmap`, `issues`, `inbox`, `decisions`, `list`) plus id
claiming: `jobstate.py claim` uses `mkdir` and `tracker.py issue-id` uses an
exclusive file create, so two sessions can't take the same number. All other
tracker writes are single-line `Edit`s done by the skills.

## 5. Concurrency: running jobs in parallel

| Shared thing | How collisions are avoided |
| --- | --- |
| Source tree | one git worktree per job, outside the repo |
| Gradle `build/`, `.gradle/` | inside each worktree |
| Emulator | one read-only copy of the AVD per job, on its own port |
| Emulator start-up | one at a time (lock), so first boots don't corrupt the AVD's images |
| `job.json` | one per job, one writer |
| Job numbers / issue numbers | atomic `mkdir` / exclusive create |
| roadmap.md, issues | single-line Edits that fail if the line changed underneath |
| `main` | merges only from a clean main checkout, conflicts pre-checked with `git merge-tree` |
| Reviewers inside one job | read the round's `checks.md` and shots, never build |

What isn't isolated: CPU and RAM (Gradle is heavy and each emulator holds
2–3 GB), the Gradle daemon and download cache (shared by design), and the
AVD's Google account (read-only copies start with whatever the AVD had,
usually none, which is what you want for tests).

## 6. The question → answer → resume loop

**Confirm mode** (`/factory next confirm`) is the live, in-session version
of this loop, used when you'd rather agree on a feature than discover the
spec in review.
- The spec-writer gets `Confirm:`. It turns its open product calls into
  **Assumptions** with alternatives, instead of settling them quietly, and
  still writes a full spec.
- The orchestrator recaps the spec, asks the assumptions and any
  `## Questions` as AskUserQuestion pickers (at most two rounds), then asks
  build / change / not now.
- Differences go back to the spec-writer as `Revise:`. It records them under
  `## Confirmed with the user`, and those answers are binding.
- `job.json` has `confirm: true → waiting → done`. A job left `waiting`
  stays in stage `spec`, and the dashboard shows a "confirm spec" chip.
  `/factory resume` picks it up.
- No issue is created, because the user answers on the spot.

1. An agent writes `STATUS: NEEDS-INPUT` (or the approver writes `ESCALATE`)
   with `### Q<n>` questions, each with lettered options and a recommendation.
2. The orchestrator copies the questions into the job's issue (creating one
   if needed), sets `status: needs-input` on the issue, `stage: needs-input`
   with `blocked_at` on the job, and `[?]` on the roadmap item, then stops.
   The session is free.
3. Later, in any session, `/issues` lists it. Picking it turns each question
   into an AskUserQuestion with the same options (your own text goes through
   "Other"). Answers are written under `## Answers`, and the issue becomes
   `answered`.
4. If an answer is a general rule, `/issues` offers to record it in
   `decisions.md` with `Source: ISS-<n>`, so the next job doesn't ask again.
5. `/factory resume <job>` (offered right away) re-enters at `blocked_at`. A
   fresh agent reads the issue's answers. Answers are binding, like decisions.

## 7. Docs and releases

- **Documenter, job mode**: after APPROVE, it updates the wiki pages the diff
  touches, creates feature or module pages for new code (features start
  `shipped: unreleased`), regenerates the index, lints, and commits on the job
  branch.
- **Documenter, audit mode** (`/docs`): lint + coverage + stale, then fixes,
  on its own `factory/<id>-docs-audit` branch.
- **Ship notes**: reviewer-release writes manual steps (update the Data
  safety form, fill in a restricted-permission declaration), the approver
  copies them into `decision.md`, and the merge copies them into
  `releases.md` as `⚠` lines. `/play` won't upload until you confirm each one.
- **`/play`** turns Unreleased into
  `## <version name> (<version code>) · <date>` with the release notes, sets
  `shipped:` on the wiki's unreleased feature pages, adds `Play …` refs to
  roadmap items, and tags `play/<version name>-<version code>`. The next
  release's diff starts from that tag. Version codes are minutes since
  2020-01-01: always higher than the last, and nowhere near Play's
  2,100,000,000 limit (that's about 4,000 years of minutes).

## 8. The wiki

`docs/wiki/` replaces a single tech-notes file once a project outgrows one.
Pages are typed (architecture, feature, module, guide, reference), and each
type has a template with fixed sections. Frontmatter carries `title`, `type`,
`summary` (shown in the index), `code:` (the paths the page documents),
`related:`, `decisions:` and, for features, `shipped:`.

The `code:` mapping drives everything:
- **Agents read less.** The spec-writer, builder and reviewers run
  `wiki.py pages-for <paths>` (or `--diff main`) and read those pages, not
  the whole wiki.
- **Targeted updates.** The documenter starts from `pages-for --diff main`, and
  every changed source file must end up covered by some page.
- **Health.** `coverage` lists source files no page claims. `stale` lists pages
  whose code has commits newer than the page (by git timestamps). `lint`
  checks required frontmatter, types, that `code:` paths still match tracked
  files, related pages and relative links, and that each page is in the
  index (exit 1 on errors). `/docs status` shows all three.
- **Index.** `wiki.py index` regenerates the block between
  `<!-- wiki:index:start/end -->` in `index.md`, grouped by type. The text
  above it is hand-written.

Writing rules (in the documenter): one fact on one page, link instead of
repeating, real type names but no line numbers or counts (they go stale), a
split once a page passes about 250 lines, and decisions linked by id, never
restated.

`/play` turns `shipped: unreleased` into the build, so a feature page says
when it reached testers.

**Consistency over time.** Staleness is computed rather than recorded: a page
is stale when any file in its `code:` has a commit newer than the page's last
commit. Three things clear it: the documenter editing the page (job, sync and
audit modes), or `wiki.py verify <page>`, which writes
`verified: <date> <sha>` into the frontmatter after the documenter confirms
the page is still right. Committing that moves the page's timestamp, with no
fake edits.

The git hooks are symlinks from `.git/hooks/` (the common dir, so worktrees
share them) into `factory/hooks/`, so `install.sh --update` updates them.
Hooks aren't versioned, so a fresh clone needs `install.sh --update` (or
`/docs hooks`) to link them. They never run an agent: every commit stays fast,
and the expensive semantic check is `/docs sync`, on demand.

## 9. Onboarding (/factory-init)

1. **Mine**: `doc-miner` writes only to `factory/init/`: `inventory.md` (every
   doc → keep / archive / split / ignore, and where its content goes), drafts
   of every factory file in the real formats with source tags, `questions.md`,
   and `summary.md`.
2. **Ask**: the skill asks the questions four per AskUserQuestion call,
   applying each round's answers to the drafts straight away. Skipped
   questions become `needs-input` issues.
3. **Preview**: `FACTORY_DIR=factory/init tracker.py roadmap|decisions|issues`
   renders the drafts with the normal views.
4. **Apply** on a `factory/init` branch: drafts into place, CLAUDE.md patched,
   split docs get pointers, archived docs are `git mv`'d to `docs/archive/`
   with a mapping README, references updated, one commit, merge only on
   confirmation.

Old tech notes go through a **seed** step. doc-miner plans the pages
(`wiki-plan.md`), and the documenter writes them into `factory/init/wiki/`,
checking claims against the code, with a **source map** from every original
section to its page. After apply, the old file is archived.

Why archive rather than delete: the mapping keeps every original sentence
traceable. CLAUDE.md is never archived, because it's the agents' entry point.
It slims down to conventions, commands, Screens and a pointer to the wiki.

### New apps (/factory-new)

The same shape as init, with an idea in place of existing docs, plus a
shaping step first.
- `app-planner` runs twice. In **shape** mode it writes only
  `suggestions.md`: specific improvements, each with its kind, cost and
  effect on the plan.
- The user gives each one a verdict: yes, yes with changes, later, or no.
- In **draft** mode it gets the approved ids (rejected ones are never
  brought back), and drafts into `factory/init/`.

Two separate runs keep the plan from ever containing a suggestion the user
didn't see. The idea file stays as written. The suggestions and their
verdicts are archived beside it. The skill asks the questions, required ones
first, then applies everything on `factory/init`.

The starter app is a template, not a job. `scaffold.py` renders
`factory/templates/app/`:
- it replaces `{{APP}}`, `{{DISPLAY_NAME}}` (XML-escaped in resources),
  `{{APPLICATION_ID}}`, `{{MIN_SDK}}`, `{{COMPILE_SDK}}` and `{{TARGET_SDK}}`,
  and `__PKG__` in paths with the package folders;
- binary files (the Gradle wrapper jar) are copied as they are, and
  executable bits (`gradlew`) are kept;
- `gitignore.append` is merged into `.gitignore`;
- it never overwrites a file.

A template is deterministic and tested. It's also the same every time, so
the first real job isn't spent reviewing boilerplate. The skill still proves
the result with `droid.sh build`, `test` and `shots` before it commits.

What the template gives every app:
- a Gradle project (Kotlin DSL, a version catalog with exact versions, the
  wrapper, configuration cache on), Compose and Material 3 with the app's own
  colour scheme, edge to edge;
- `FactoryLaunch` (`factoryScreen`, `factoryNoPrompts` intent extras, debug
  builds only), so the UX reviewer can see screens from the first job;
- backup and data-extraction rules, so the privacy reviewer has a file to
  check;
- a release build type with R8 and resource shrinking, signed from
  environment variables (debug key as a fallback, for the smoke test);
- `AppInfo` with a real JUnit test;
- a Compose UI test with one tap flow (`FlowTest`), so acceptance criteria
  that need a tap have a home from the first job. `droid.sh check` runs it
  every round;
- `FactoryShots` and the TestStorage setup, for `UI_TEST_SCREENS`.

Permissions are left to the job that needs them.

Versions are pinned in `android/gradle/libs.versions.toml`. When you refresh
them, check the compileSdk the AndroidX libraries ask for (their AAR
metadata says, and the build fails with the exact level), and bump
`compile_sdk` in the app-planner's defaults to match.

To change the starter app, edit `factory/templates/app/`, then check it on a
scratch folder:
1. `install.sh /tmp/x`
2. `scaffold.py values.json --dest /tmp/x`
3. Fill `config.sh` as the skill does (`PROJECT_DIR="android"`,
   `APPLICATION_ID`, `SCREENS`).
4. `droid.sh build|test|shots|smoke main`, `droid.sh check main 1`, then
   `droid.sh cleanup main`.

### Design prototypes (/design)

The canvas is a claude.ai Artifact made from the Design type. Only the main
session can create, read or change it, through the Artifact tool. Agents
never see it.

The handover is through files:
- `design.md` holds the direction in words and a row per screen, keyed by
  the `factoryScreen` name.
- At job start (factory skill, step 5), the orchestrator `read`s each
  matching artboard (`project/<artboard>`, a self-contained `.dc.html` file)
  into `<job folder>/design/`.
- It adds a `Design:` line to the spec-writer, builder and UX reviewer
  prompts.

The artboards are HTML, so agents read them for layout, copy and colours,
never as code to port. Native rendering differences aren't findings. Drift
in hierarchy, copy or colour is, unless the spec's **Design deviations**
allows it.

Rows go draft → approved → built (at merge). After that the emulator
screenshots are the reference. `/factory-new` can run `/design new` between
shaping and drafting, so the approved screens decide the roadmap order.

## 10. Changing the factory

### Fixes found in an app (UPSTREAM.md)

Factory bugs usually show up while a job runs in an app, for example a
`pipefail` exit on an empty `grep`, demo mode missed right after boot, or a
warm start ignoring new intent extras. When that happens:
- The builder reports it in a `## Factory tooling` section rather than
  working around it.
- The orchestrator fixes it on the app's main branch, as its own
  `factory: <file>: <what>` commit, and logs it in `factory/UPSTREAM.md`.

`install.sh --update` reads the unticked entries:
- **Already ported**: every code line the fix commit added (ignoring
  comments and trivial lines like `fi`) is already in android-factory's copy.
  It ticks the entry and updates the file as usual.
- **Not ported yet**: it keeps the app's copy of those files, so the update
  can't undo the fix, and prints a `diff -u` to port from.

To port a fix, apply the diff in android-factory and commit it there. If the
same bug exists in ios-factory (the trackers, wiki, dashboard and most
skills are shared), port it there too. The next
`--update` in the app ticks the entry by itself. If the port had to change
the code itself (not just comments), tick the entry by hand.

- **Add a review lens** (e.g. `reviewer-perf`): add the agent file, add its key
  to the `reviews` dict in `jobstate.py new`, list it in the factory skill's
  Review step and table, add its file name to `jobTabs` in the dashboard, and
  mention it in the approver's "all reviews PASS" rule.
- **Tune what escalates**: edit the approver's ESCALATE list. For one area of
  one app, a decision with `Status: escalate` is usually better, because no
  file changes.
- **Stack-specific checklists**: the reviewers' "What to look for" lists are
  generic Android. Add your app's hot spots there, such as "location updates
  must go through LocationRepository" or "every Room change needs a
  MigrationTest case".
- **More rounds**: `MAX_RESUMES` in the factory skill.
- **Different models**: the `model:` line in each agent's frontmatter.
