# iOS Factory for Claude Code

A software factory for iOS apps, made of Claude Code skills, eight subagents,
a few small scripts and plain markdown files. You type `/factory <feature>`.
Agents write a spec, build it on its own branch and simulator, run the tests,
screenshot it in light, dark and large text, review it from four iOS angles,
document it, and merge it to `main`. When they need a decision only you can
make, they stop and leave you a question in one inbox.

It started from [zazencodes' software factory](https://github.com/zazencodes/zazencodes-season-3/tree/main/src/software-factory-claude-code)
and was reworked for iOS: simulators instead of a dev server, XcodeGen-aware
worktrees, App Store / TestFlight review lenses, and a decision log, inbox,
roadmap and release pipeline around it.

```
request ─► spec-writer ─► builder ─► CHECKS ─► [code, privacy, ux, release] ─► approver ─► documenter ─► merge
              │              ▲  │   build·tests·          │ any CHANGES              │ ESCALATE
              │              │  │   screenshots ──FAIL───►┴──► resume builder ◄──────┤
              ▼              │  ▼                                                 ▼
          NEEDS-INPUT ───────┴─ NEEDS-INPUT ─────────────►  factory/issues/ISS-n  ◄── /issues (you answer)
                                                                   │
                                     /factory resume <job> ◄───────┘      merged ─► releases.md ─► /testflight
```

## What you get

| Command | What it does |
| --- | --- |
| `/factory-new [IDEA.md]` | Start a new app from an idea: product brief, decisions (a default stack plus what the idea settles), roadmap, questions in rounds, then a starter app that builds, tests and screenshots, and a seeded wiki |
| `/factory-init` | Onboard a repo: mine existing docs/plans/notes and the Xcode project → roadmap, decisions, issues, product brief, config, CLAUDE.md. Ask about anything unclear, archive the docs whose content moved |
| `/factory <feature>` | Run a new job through the whole loop |
| `/factory next` | Take the next `- [ ]` item from the roadmap |
| `/factory next confirm` | Same, but first go over the spec with you: a short recap, its assumptions as questions, then build / change / not now. Also `/factory ISS-12 confirm`, `/factory confirm <feature>` |
| `/factory ISS-12` | Work an issue (bug or feature) from the tracker |
| `/factory status` | Jobs in flight across all sessions, plus the inbox |
| `/factory resume <job>` | Continue a paused job after you've answered its questions |
| `/factory approve <job>` / `rework <job> <note>` / `abandon <job>` | Decide on an escalated job |
| `/issues` | **Inbox**: what needs your input, open bugs, in-progress work. Answer questions with a picker |
| `/bug <what happened>` | File a bug (with a quick look at the likely code), then fix now / roadmap / just track |
| `/decide <rule>` | Record a standing decision every agent follows (`/decide` lists them) |
| `/roadmap` | Milestones with progress bars: done, in progress, waiting on you, to do |
| `/roadmap add / move / park / import PLAN.md / sync / open` | Shape the roadmap |
| `/design` | Prototype screens as a Claude Design canvas (`new`, `add <screen>`, `revise`, `approve`, `open`). Jobs build to the approved artboards, and the UX reviewer compares screenshots with them |
| `/testflight` | Pre-flight checklist → upload (only after you confirm) → release notes, tag, roadmap |
| `/docs status` | Wiki health: lint, code coverage, stale pages |
| `/docs sync [<commit\|range>]` | Update the wiki for code you changed yourself (stale pages, or a given commit or range) |
| `/docs audit` | Re-check the whole wiki against the code, and fix it on a branch |
| `/docs hooks` | Check or link the git hooks (needed on each fresh clone) |

Plus a **dashboard** (`factory/dashboard.html`) with Board, Roadmap, Inbox,
Decisions and Releases tabs and per-round screenshot galleries.

## The agents

| Agent | Model | Job |
| --- | --- | --- |
| `spec-writer` | opus | Spec with testable acceptance criteria, screens to capture, iOS impact, and the decisions that apply. Asks instead of guessing product questions |
| `builder` | opus | Implements on `factory/<job>` in its own worktree, tests on its own simulator, commits, writes "What to test" |
| `reviewer-code` | sonnet | Swift correctness, concurrency, SwiftUI state, tests, conventions |
| `reviewer-privacy` | opus | Keychain vs defaults, permissions and purpose strings, privacy manifest, entitlements, deep-link input, logging |
| `reviewer-ux` | sonnet | Looks at the screenshots (light / dark / large text): states, HIG, Dynamic Type, VoiceOver, copy |
| `reviewer-release` | opus | Ships safely on top of existing installs? SwiftData/CloudKit schema, mixed versions, widgets, battery, App Review risk. Writes **ship notes** |
| `approver` | opus | Merge on its own, or escalate (data model, entitlements, deps, signing, product calls…) |
| `app-planner` | opus | `/factory-new` only: turns an idea into a product brief, decisions, roadmap and scaffold values, plus questions |
| `doc-miner` | opus | `/factory-init` only: turns existing docs and the project into factory drafts plus questions |
| `documenter` | sonnet | Keeps the wiki true: updates the affected pages on the branch before merge, audits, and seeds the wiki from old notes at init |

## How the pieces fit

- **Product brief** (`factory/product.md`). Who the app is for, the core
  loop, tone, principles, and what it deliberately isn't. The spec-writer uses
  it for small product calls, the UX reviewer judges feel against it, and the
  approver escalates work that drifts into "Not doing".
- **Decisions** (`factory/decisions.md`). Your standing rules, such as "km
  everywhere" or "no analytics SDKs". The spec-writer follows them and cites
  them, the builder never contradicts them, reviewers flag violations, and the
  approver escalates conflicts and anything in an area marked `Status:
  escalate`. When you answer an agent's question, `/issues` asks whether the
  answer is a one-off or should become a decision.
- **Issues** (`factory/issues/ISS-n-*.md`). One tracker for bugs, feature
  requests and agent questions. A job that needs you pauses with
  `stage: needs-input`, and its questions land in an issue with options and a
  recommendation. `/issues` shows them as a multiple-choice picker, records
  your answers, and resumes the job.
- **Roadmap** (`factory/roadmap.md`). Milestones and items with
  `[ ] [~] [?] [x] [-]`. Jobs update their item as they move, and
  `/testflight` stamps the build that shipped it.
- **Releases** (`factory/releases.md`). Every merge adds a "What to test" line
  and any ⚠ ship notes (for example "deploy the CloudKit schema to
  Production") under Unreleased. `/testflight` turns that into the TestFlight
  notes.
- **Wiki** (`docs/wiki/`). Developer knowledge split into **architecture**,
  **feature**, **module** and **guide** pages, with a generated `index.md`.
  Each page's frontmatter lists the code it documents (`code:`), so
  `wiki.py pages-for` gives agents only the pages they need, and the
  documenter knows which pages a merge affects. `wiki.py lint`, `coverage` and
  `stale` catch broken links, undocumented code and outdated pages. Feature
  pages carry a "For users" section and `shipped:`, which `/testflight` stamps.
  It lives in `docs/`, not `factory/`, because docs merge together with the
  code on each job branch.
- **Keeping the wiki honest.** Factory jobs document themselves. For your own
  commits there are two layers:
  - **git hooks** (no AI, milliseconds, also for commits made from Xcode).
    *pre-commit* blocks a commit that touches the wiki and leaves it broken,
    and only warns on code-only commits. *post-commit* lists the pages the
    commit may have made stale.
  - **`/docs sync`** (documenter agent): updates those pages, or stamps them
    `verified:` when they're still right. Staleness comes from git
    timestamps (code newer than page), so nothing extra needs tracking. Run it
    after a burst of manual work, or let the post-commit note remind you.

## Parallel features

Every job gets its own **git worktree**
(`../<repo>-factory/<job-id>/`, branch `factory/<job-id>`), its own
**simulator** (`factory-<repo>-<job-id>`), and its own **DerivedData**, so jobs
never fight over a device or build folder. Open a few terminals in the repo and
run `/factory …` in each. `/factory status` from any of them shows the lot.
Builds are CPU-heavy, so two or three at once is the sweet spot on a laptop.
Job branches never touch `factory/`, so the trackers don't cause merge
conflicts. If `main` moves under a job, the builder merges it in and the checks
re-run before the merge.

## Install into an app repo

```bash
./install.sh ~/projects/my-app      # copies .claude/ + factory/, never overwrites, updates .gitignore
cd ~/projects/my-app && git add -A && git commit -m "Add iOS factory"
claude                              # then: /factory-init
```

**`/factory-init`** does the rest. The `doc-miner` agent reads every doc, plan
and notes file plus the Xcode project and git history, and drafts the
roadmap, decisions, issues, `factory/product.md`, a filled-in `config.sh`,
CLAUDE.md changes (including a Screens section) and a wiki plan, with source
references. The documenter then rebuilds your old tech notes as wiki pages,
checked against the code, with a source map so nothing is dropped.
Anything unclear or contradictory becomes a question, asked four at a time.
Skip the rest whenever you like, and the unanswered ones become issues. After
you review the summary, it applies everything on a `factory/init` branch,
moves fully migrated docs to `docs/archive/` with an index of where each
piece went, replaces migrated sections of living docs with pointers, and
fixes references. Old tech notes are archived once the wiki replaces them.
CLAUDE.md slims down to conventions, commands and a pointer to the wiki. Run `/factory-init --refresh` later to adopt new notes files.

### Starting a new app

```bash
./install.sh ~/projects/habit-loop  # creates the folder and runs git init if needed
cd ~/projects/habit-loop
$EDITOR IDEA.md                     # the idea: a paragraph or a full brief
claude                              # then: /factory-new
```

**`/factory-new`** commits the factory files first, then:
- **It shapes the idea.** The `app-planner` agent critiques the idea and
  suggests specific improvements:
  - coherence gaps;
  - reasons to come back;
  - what sets the app apart;
  - iOS features that fit;
  - scope cuts;
  - risks, each with a way round it.
  
  You answer each suggestion with yes, yes with changes, later, or no.
  Nothing you don't approve gets into the plan. Pass `--as-is` to skip this
  step.
- **Optionally, it prototypes the screens.** It draws the core loop's screens
  as a Claude Design canvas on claude.ai, one iPhone artboard per screen,
  private until you share it.
  - Comment on the canvas or give notes; `/design revise` applies them.
  - When you approve, the screen list and visual direction shape the
    roadmap and the decisions.
- Then the `app-planner` agent drafts `factory/product.md`, `decisions.md`,
  `roadmap.md` (an MVP milestone, later ones, and a parked list) and the
  config.
- The decisions are the factory's default stack plus whatever the idea
  settles. The stack: Swift 6 and SwiftUI, XcodeGen, `@Observable` services,
  SwiftData, Swift Testing, no packages without asking.
- It asks questions four at a time, starting with the ones it can't do
  without: the name, the bundle id, the minimum iOS and the devices.
- After you review, it renders the starter app from
  `factory/templates/app/` (via `scaffold.py`) on a `factory/init` branch:
  - an XcodeGen project in `ios/`;
  - a SwiftUI shell with a home screen and a Settings sheet;
  - the `-factoryScreen` and `-factoryNoPrompts` hooks;
  - a privacy manifest and a Swift Testing target;
  - a CLAUDE.md with Screens and Conventions sections.
- It builds, tests and screenshots the app before committing, and seeds the
  wiki.
- The idea file moves to `docs/archive/`, with the suggestions and your
  verdicts. Then `/factory next` builds the
  first feature.

No idea file? Run `/factory-new` and describe the app when it asks.

### Manual install

1. Copy `.claude/` and `factory/` into your repo root. If you already have a
   `.claude/`, merge the `agents/` and `skills/` folders into it.
2. Add `/factory/jobs/` and `/build/` to `.gitignore`.
3. Edit **`factory/config.sh`**: project folder, scheme, bundle id, generator
   (`xcodegen generate`), simulator model, permissions to pre-grant, simulated
   location, screens to capture, wiki folder and team id. Copy
   `factory/templates/wiki/` to `docs/wiki/` (minus `_templates/`). Comments explain each
   setting.
4. Make sure **`CLAUDE.md`** describes the architecture and conventions, and
   add a **Screens** section (see below). The agents carry nothing app-specific.
   They read it all from there.
5. Seed the roadmap: `/roadmap import PLAN.md`, or edit `factory/roadmap.md`.
6. Commit on `main`, then `/factory next` or `/factory <feature>`.
7. Optional: show the inbox at session start. Add this to `.claude/settings.json`:

   ```json
   { "hooks": { "SessionStart": [ { "hooks": [
     { "type": "command", "command": "python3 -I \"$CLAUDE_PROJECT_DIR/factory/scripts/tracker.py\" inbox --brief" }
   ] } ] } }
   ```

### Design prototypes

`/design new` draws the app's screens on a **Claude Design canvas**: one
390×844 iPhone artboard per screen, in the app's tone, with real copy. It
works in an existing app too, starting from its current screenshots.
`factory/design.md` is the factory's side of it: the link, the visual
direction in words, and one row per screen:

```
| Screen | Artboard        | Status   | Roadmap                 | Notes |
| home   | Main.dc.html    | approved | Home: habit list (home) | …     |
```

Rows go draft → approved → built. Agents can't open the canvas, so when a job
starts, the orchestrator downloads the artboards for its roadmap item into
`<job folder>/design/`:
- the spec-writer writes acceptance criteria against them, and lists any
  **Design deviations**;
- the builder matches layout, copy and colours with native SwiftUI;
- the UX reviewer compares the simulator screenshots with the artboards.

On merge, rows become `built`, and from then on the app's screenshots are
the reference. `/design add <screen>` draws the next screen before the
roadmap gets there. `/design approve` offers the firm rules (for example "one
accent colour") as decisions.

### Screens: how agents see your UI

`simctl` can launch the app, open URLs, change appearance and text size, and
take screenshots, but it can't tap. So each screen the reviewers need must be
reachable directly:

- **Launch arguments** (recommended): a DEBUG-only switch at app start, e.g.
  `-factoryScreen settings` opens Settings with sample data. The builder adds
  cases as features need them. Document the convention in CLAUDE.md:

  ```swift
  #if DEBUG
  // Factory/UI-review hook: -factoryScreen <name> opens a screen directly.
  if let screen = UserDefaults.standard.string(forKey: "factoryScreen") { router.open(debugScreen: screen) }
  #endif
  ```
- **Deep links** (`url:myapp://area/42`) if the app already has them.
- **UI tests** for flows that need taps: set `UI_TEST_SCREENS` to a test class
  that attaches screenshots (`XCTAttachment`, `.keepAlways`). They're exported
  into the round's `shots/` folder.

**Permission alerts.** `SIM_PRIVACY_GRANTS` pre-grants most permissions,
but on current iOS simulators **location can't be granted from `simctl`**: the
"Allow … to use your location?" alert still covers the screen. Give the app a
DEBUG launch argument that skips the request and feeds a fixed location (or
uses the simulated one without asking), and put it in every `SCREENS` entry,
e.g. `"map|-factoryNoPrompts"`. The test run launches the app without those
arguments, and an alert it raises survives app restarts, so `xc.sh check`
shuts the simulator down between tests and screenshots.

The `SCREENS` list in config.sh is captured for every job. The spec adds
job-specific ones to the job's `screens.txt`.

## Dashboard

```bash
python3 -I factory/scripts/serve.py          # add --open to open the browser
```

Then open <http://localhost:8765/dashboard.html>, or use `/roadmap open`.
**Board** shows jobs moving through Spec → Build → Checks → Review →
Approve/Docs/Merge → Needs you → Merged, with check and review chips filling in
live. Click a card to read its spec, build log, checks, reviews, the screenshot
gallery for each round, and the timeline. **Roadmap**, **Inbox**, **Decisions**
and **Releases** render the trackers. The page polls every 3 seconds.

## TestFlight

`/testflight` never uploads without asking. It runs the full test suite on
`main`, checks for data-model/CloudKit changes since the last
`testflight/*` tag (and makes you confirm the Production schema deploy), lists
⚠ ship notes, permission, entitlement and privacy-manifest changes, export
compliance, and open high-priority bugs, and offers a version bump. Then it
uploads via `factory/scripts/testflight.sh` (or your own script, set by
`TESTFLIGHT_CMD`; it must honour `BUILD_NUMBER`). Afterwards it moves
Unreleased into a dated release, writes the What to Test text, stamps the
roadmap, and tags the commit. Signing uses your Xcode account, or an App Store
Connect API key via `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_PATH`.

## Limits and choices

- **Agents can't tap.** Visual review covers what launch arguments, deep links
  and UI tests can reach. Flows only reachable by tapping get judged from code
  until you add a hook or a UI test.
- **Simulator service hangs.** If `xc.sh` reports "simctl create timed out",
  CoreSimulatorService is stuck (usually a device frozen in "Shutting Down").
  `killall -9 com.apple.CoreSimulator.CoreSimulatorService` fixes it, but
  shuts down every simulator. `FACTORY_SIM_UDID=<udid>` pins all jobs to one
  existing simulator as a fallback, at the cost of parallel isolation.
- **One orchestrator per session.** A session that runs `/factory` is busy
  until the job ends or pauses. Use more terminals for more parallel jobs.
- **Nothing is pushed.** Merges are local. `/testflight` is the only thing that
  talks to Apple, and only after you confirm.
- **Checks run once per round, by the orchestrator**, not by each reviewer.
  iOS builds are slow, and four reviewers building at once would fight over
  the simulator. Reviewers read `checks.md` and the screenshots instead.

See [TECH_NOTES.md](TECH_NOTES.md) for how it works inside: file formats, the
job state machine, scripts, and how to change the loop.
