# iOS Factory: Tech Notes

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
    testflight/SKILL.md  checklist → confirm → upload → record
    docs/SKILL.md        docs-only audit job
    factory-init/SKILL.md  onboarding: doc-miner → questions in rounds → apply on a branch → archive
  agents/                one file per agent (frontmatter: tools + model)
factory/
  config.sh              per-app settings, sourced by the shell scripts
  product.md             committed: product brief (what, who, tone, principles, not doing)
  roadmap.md             committed tracker
  decisions.md           committed tracker
  releases.md            committed tracker
  issues/                committed tracker, one file per issue (+ _TEMPLATE.md)
  jobs/                  gitignored runtime state, one folder per job
  dashboard.html         read-only view of all of the above
  templates/wiki/        seed for docs/wiki: index.md, glossary.md, _templates/ per page type
docs/wiki/               (in the app repo) the project wiki, kept by the documenter
  scripts/
    jobstate.py          the only writer of job.json
    tracker.py           read-side of roadmap / issues / decisions; id claiming
    wiki.py              wiki: pages-for (paths/--diff/--commit/--range/--staged), coverage, stale, lint, index, verify
  hooks/
    pre-commit           wiki lint: blocks wiki-touching commits on errors, warns otherwise
    post-commit          lists wiki pages a commit may have made stale (silent on factory/* and merges)
    xc.sh                build / test / run / screenshot per job
    test_summary.py      xcresult + log → markdown
    sensitive_paths.py   changed files that need iOS-specific care
    testflight.sh        archive + upload (honours BUILD_NUMBER)
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
| `round-N/checks.md`, `round-N/shots/` | `xc.sh check` |
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
  "simulator": "factory-explore-claim-004-widget-refresh",
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
`TF <version> (<build>)`, or anything else (shown as a plain chip).

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

### xc.sh

Everything iOS-specific about building lives here. Agents call it instead of
`xcodebuild`, so they never pick a destination, DerivedData or simulator
themselves.

- **Simulator per job**: `simctl create factory-<repo>-<job> "<SIM_DEVICE_TYPE>"`
  on the newest runtime, booted on first use. The status bar is pinned to 9:41
  with full battery, so screenshots stay comparable between rounds. The
  simulated location is set from config.
- **DerivedData per job**:
  `~/Library/Developer/ios-factory/<repo>/<job>`, outside the worktree, so
  it never shows up in `git status`.
- **`setup`** copies `COPY_INTO_WORKTREE` files (gitignored secrets or
  plists) from the main checkout, then runs `SETUP_CMD` (e.g. XcodeGen).
  `build` and `check` re-run setup each time, because a builder adding a file
  means the generated project changed.
- **`test`** writes `tests.xcresult`, `xcodebuild-test.log` and
  `test-summary.md` (result, counts, failures, compiler errors and warnings
  via `test_summary.py`). It skips the `UI_TEST_SCREENS` class, which `shots`
  runs separately.
- **`shots`** installs the app, grants `SIM_PRIVACY_GRANTS`, and then, for each
  variant (light, dark, large-text = `accessibility-large`), launches each
  screen (launch args or `url:` deep link), waits `SCREEN_WAIT`, and
  screenshots. If `UI_TEST_SCREENS` is set, it runs that class per variant and
  exports its attachments with `xcresulttool export attachments`.
- **`check`** = setup + test + shots + `sensitive_paths.py` → `checks.md`.
  Run by the orchestrator in the background. It can take several minutes.
- **`main`** as a job id means "the main checkout". `/testflight` uses it for
  the pre-release test run.

### sensitive_paths.py

Groups changed files (`main...HEAD`) by why they need care: entitlements,
Info.plist, privacy manifest, project/build settings, dependencies, data model
(globs from config, plus any Swift diff line touching `@Model`, `@Attribute`
or `@Relationship`), release tooling, and factory files (which job branches
must never touch). Reviewers and the approver read this section of
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
| Generated `.xcodeproj` | generated inside each worktree |
| Simulator | one per job, named after the job |
| DerivedData / SPM checkouts | one folder per job |
| `job.json` | one per job, one writer |
| Job numbers / issue numbers | atomic `mkdir` / exclusive create |
| roadmap.md, issues | single-line Edits that fail if the line changed underneath |
| `main` | merges only from a clean main checkout, conflicts pre-checked with `git merge-tree` |
| Reviewers inside one job | read the round's `checks.md` and shots, never build |

What isn't isolated: CPU and RAM (xcodebuild is heavy), and iCloud on the
simulators (each new simulator is signed out, which is usually what you want
for tests).

## 6. The question → answer → resume loop

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
- **Ship notes**: reviewer-release writes manual steps (CloudKit Production
  deploy, App ID capabilities), the approver copies them into `decision.md`,
  and the merge copies them into `releases.md` as `⚠` lines. `/testflight` won't
  upload until you confirm each one.
- **`/testflight`** turns Unreleased into
  `## <version> (<build>) · <date>` with What to Test text, sets `shipped:`
  on the wiki's unreleased feature pages, adds `TF …` refs to roadmap items,
  and tags `testflight/<version>-<build>`. The next release's diff starts
  from that tag.

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

`/testflight` turns `shipped: unreleased` into the build, so a feature page
says when it reached testers.

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

## 10. Changing the factory

- **Add a review lens** (e.g. `reviewer-perf`): add the agent file, add its key
  to the `reviews` dict in `jobstate.py new`, list it in the factory skill's
  Review step and table, add its file name to `jobTabs` in the dashboard, and
  mention it in the approver's "all reviews PASS" rule.
- **Tune what escalates**: edit the approver's ESCALATE list. For one area of
  one app, a decision with `Status: escalate` is usually better, because no
  file changes.
- **Stack-specific checklists**: the reviewers' "What to look for" lists are
  generic iOS. Add your app's hot spots there, such as "location updates must
  go through LocationService" or "every SwiftData model change needs a
  VersionedSchema".
- **More rounds**: `MAX_RESUMES` in the factory skill.
- **Different models**: the `model:` line in each agent's frontmatter.
