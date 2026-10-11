# Android Factory for Claude Code

A software factory for Android apps, made of Claude Code skills, eight
subagents, a few small scripts and plain markdown files. You type
`/factory <feature>`. Agents write a spec, build it on its own branch and
emulator, run the tests and Lint, screenshot it in light, dark and large
text, review it from four Android angles, document it, and merge it to
`main`. When they need a decision only you can make, they stop and leave you a
question in one inbox.

It's the Android sibling of [ios-factory](../ios-factory/): the same loop,
trackers, wiki and dashboard, with Gradle, emulators, Compose and Google Play
in place of Xcode, simulators, SwiftUI and TestFlight.

```
request ─► spec-writer ─► builder ─► CHECKS ─► [code, privacy, ux, release] ─► approver ─► documenter ─► merge
              │              ▲  │   build·tests·          │ any CHANGES              │ ESCALATE
              │              │  │   lint·screenshots      │                          │
              │              │  │        └──FAIL─────────►┴──► resume builder ◄──────┤
              ▼              │  ▼                                                 ▼
          NEEDS-INPUT ───────┴─ NEEDS-INPUT ─────────────►  factory/issues/ISS-n  ◄── /issues (you answer)
                                                                   │
                                     /factory resume <job> ◄───────┘      merged ─► releases.md ─► /play
```

## What you get

| Command | What it does |
| --- | --- |
| `/factory-new [IDEA.md]` | Start a new app from an idea: product brief, decisions (a default stack plus what the idea settles), roadmap, questions in rounds, then a starter app that builds, tests and screenshots, and a seeded wiki |
| `/factory-init` | Onboard a repo: mine existing docs/plans/notes and the Gradle project → roadmap, decisions, issues, product brief, config, CLAUDE.md. Ask about anything unclear, archive the docs whose content moved |
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
| `/play` | Pre-flight checklist (incl. a release-build smoke test) → upload to the internal testing track (only after you confirm) → release notes, tag, roadmap |
| `/docs status` | Wiki health: lint, code coverage, stale pages |
| `/docs sync [<commit\|range>]` | Update the wiki for code you changed yourself (stale pages, or a given commit or range) |
| `/docs audit` | Re-check the whole wiki against the code, and fix it on a branch |
| `/docs hooks` | Check or link the git hooks (needed on each fresh clone) |

Plus a **dashboard** (`factory/dashboard.html`) with Board, Roadmap, Inbox,
Decisions and Releases tabs and per-round screenshot galleries.

## The agents

| Agent | Model | Job |
| --- | --- | --- |
| `spec-writer` | opus | Spec with testable acceptance criteria, screens to capture, Android impact, and the decisions that apply. Asks instead of guessing product questions |
| `builder` | opus | Implements on `factory/<job>` in its own worktree, tests on its own emulator, commits, writes "What to test" |
| `reviewer-code` | sonnet | Kotlin correctness, coroutines, Compose state, lifecycle, tests, conventions |
| `reviewer-privacy` | opus | Storage and the Keystore, permissions, exported components and intents, deep-link input, backup rules, network, logging, Data safety |
| `reviewer-ux` | sonnet | Looks at the screenshots (light / dark / large text): states, Material 3, edge to edge, back behaviour, TalkBack, touch targets, copy |
| `reviewer-release` | opus | Ships safely on top of existing installs? Room migrations, R8 in release builds, process death, API levels, background work, Play policy. Writes **ship notes** |
| `approver` | opus | Merge on its own, or escalate (data model, manifest, SDK levels, deps, signing, product calls…) |
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
  `[ ] [~] [?] [x] [-]`. Jobs update their item as they move, and `/play`
  stamps the build that shipped it.
- **Releases** (`factory/releases.md`). Every merge adds a "What to test" line
  and any ⚠ ship notes (for example "update the Data safety form") under
  Unreleased. `/play` turns that into the release notes for testers.
- **Wiki** (`docs/wiki/`). Developer knowledge split into **architecture**,
  **feature**, **module** and **guide** pages, with a generated `index.md`.
  Each page's frontmatter lists the code it documents (`code:`), so
  `wiki.py pages-for` gives agents only the pages they need, and the
  documenter knows which pages a merge affects. `wiki.py lint`, `coverage` and
  `stale` catch broken links, undocumented code and outdated pages. Feature
  pages carry a "For users" section and `shipped:`, which `/play` stamps.
  It lives in `docs/`, not `factory/`, because docs merge together with the
  code on each job branch.
- **Keeping the wiki honest.** Factory jobs document themselves. For your own
  commits there are two layers:
  - **git hooks** (no AI, milliseconds, also for commits made from Android
    Studio). *pre-commit* blocks a commit that touches the wiki and leaves it
    broken, and only warns on code-only commits. *post-commit* lists the pages
    the commit may have made stale.
  - **`/docs sync`** (documenter agent): updates those pages, or stamps them
    `verified:` when they're still right. Staleness comes from git
    timestamps (code newer than page), so nothing extra needs tracking. Run it
    after a burst of manual work, or let the post-commit note remind you.

## Parallel features

Every job gets its own **git worktree** (`../<repo>-factory/<job-id>/`, branch
`factory/<job-id>`, with its own Gradle `build/` folders) and its own
**emulator**: a headless, read-only copy of your AVD on its own port. Read-only
means several copies of one AVD run at once, each boots clean, and the AVD you
use in Android Studio never changes. Open a few terminals in the repo and run
`/factory …` in each. `/factory status` from any of them shows the lot. Each
emulator holds 2–3 GB of RAM and Gradle is CPU-heavy, so two or three jobs at
once is the sweet spot on a laptop. Job branches never touch `factory/`, so
the trackers don't cause merge conflicts. If `main` moves under a job, the
builder merges it in and the checks re-run before the merge.

## Requirements

- A JDK 17 or newer, and the Android SDK (`$ANDROID_HOME`, default
  `~/Library/Android/sdk`) with `platform-tools` and `emulator`. Android
  Studio installs both.
- At least one AVD (Android Studio → Device Manager). Set `AVD_NAME` in
  `factory/config.sh` if you have several.
- Python 3 (standard library only) and git.
- For `/play`: your upload keystore, and optionally `fastlane` plus a Play
  Console service account key for automatic uploads.

## Install into an app repo

```bash
./install.sh ~/projects/my-app      # copies .claude/ + factory/, never overwrites, updates .gitignore
cd ~/projects/my-app && git add -A && git commit -m "Add Android factory"
claude                              # then: /factory-init
```

**`/factory-init`** does the rest. The `doc-miner` agent reads every doc, plan
and notes file plus the Gradle project, manifest and git history, and drafts
the roadmap, decisions, issues, `factory/product.md`, a filled-in `config.sh`,
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
  - Android features that fit;
  - scope cuts;
  - risks, each with a way round it.
  
  You answer each suggestion with yes, yes with changes, later, or no.
  Nothing you don't approve gets into the plan. Pass `--as-is` to skip this
  step.
- **Optionally, it prototypes the screens.** It draws the core loop's screens
  as a Claude Design canvas on claude.ai, one Android phone artboard per
  screen, in Material 3, private until you share it.
  - Comment on the canvas or give notes; `/design revise` applies them.
  - When you approve, the screen list and visual direction shape the
    roadmap and the decisions.
- Then the `app-planner` agent drafts `factory/product.md`, `decisions.md`,
  `roadmap.md` (an MVP milestone, later ones, and a parked list) and the
  config.
- The decisions are the factory's default stack plus whatever the idea
  settles. The stack: Kotlin, Jetpack Compose and Material 3 in a single
  activity, a Gradle version catalog, a ViewModel per screen with
  `StateFlow`, Room and DataStore, JUnit and Compose UI tests, AndroidX
  libraries when needed and nothing else without asking.
- It asks questions four at a time, starting with the ones it can't do
  without: the name, the applicationId and the minimum Android version.
- After you review, it renders the starter app from
  `factory/templates/app/` (via `scaffold.py`) on a `factory/init` branch:
  - a Gradle project in `android/` (Kotlin DSL, version catalog, wrapper);
  - a Compose shell with a home screen and a Settings screen;
  - the `factoryScreen` and `factoryNoPrompts` debug intent extras;
  - backup rules, R8 for release builds, signing from the environment;
  - a JUnit test, a Compose UI test and a screenshot helper;
  - a CLAUDE.md with Screens and Conventions sections.
- It builds, tests and screenshots the app before committing, and seeds the
  wiki.
- The idea file moves to `docs/archive/`, with the suggestions and your
  verdicts. Then `/factory next` builds the first feature.

No idea file? Run `/factory-new` and describe the app when it asks.

### Manual install

1. Copy `.claude/` and `factory/` into your repo root. If you already have a
   `.claude/`, merge the `agents/` and `skills/` folders into it.
2. Add `/factory/jobs/` and `/build/` to `.gitignore`.
3. Edit **`factory/config.sh`**: project folder, app module, variant,
   applicationId, gitignored files to copy into worktrees (usually
   `local.properties`), the AVD, permissions to pre-grant, emulated location,
   screens to capture, the Lint task and the wiki folder. Copy
   `factory/templates/wiki/` to `docs/wiki/` (minus `_templates/`). Comments
   explain each setting.
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
412×915 Android phone artboard per screen, in Material 3 and the app's tone,
with real copy. It works in an existing app too, starting from its current
screenshots. `factory/design.md` is the factory's side of it: the link, the
visual direction in words (as Material colour roles), and one row per screen:

```
| Screen | Artboard        | Status   | Roadmap                 | Notes |
| home   | Main.dc.html    | approved | Home: habit list (home) | …     |
```

Rows go draft → approved → built. Agents can't open the canvas, so when a job
starts, the orchestrator downloads the artboards for its roadmap item into
`<job folder>/design/`:
- the spec-writer writes acceptance criteria against them, and lists any
  **Design deviations**;
- the builder matches layout, copy and colours with Compose Material 3
  components;
- the UX reviewer compares the emulator screenshots with the artboards.

On merge, rows become `built`, and from then on the app's screenshots are
the reference. `/design add <screen>` draws the next screen before the
roadmap gets there. `/design approve` offers the firm rules (for example "one
accent colour") as decisions.

### Screens: how agents see your UI

`droid.sh` launches the app with intent extras, opens deep links, switches
dark theme and font scale, and takes screenshots. Each screen the reviewers
need must be reachable directly:

- **Intent extras** (recommended): debug-only, read once by the launcher
  activity, e.g. `--es factoryScreen settings` opens Settings with sample
  data. The builder adds cases as features need them. Document the
  convention in CLAUDE.md:

  ```kotlin
  // Factory/UI-review hook, debug builds only:
  //   adb shell am start -n <app id>/.MainActivity --es factoryScreen settings --ez factoryNoPrompts true
  if (BuildConfig.DEBUG) {
      screen = intent.getStringExtra("factoryScreen")
      noPrompts = intent.getBooleanExtra("factoryNoPrompts", false)
  }
  ```
  `droid.sh` cold-starts the app for every screen (`am start -S`), so the
  extras always reach `onCreate`. A hook that writes or clears stored data
  runs there too, before `setContent`.
- **Deep links** (`url:myapp://area/42`) if the app already has them.
- **UI tests** for flows that need taps. Acceptance criteria like "tap X,
  then Y happens" are proven by a Compose UI test the builder writes in
  `src/androidTest`; it runs on the job's emulator in every round's
  `droid.sh check`. Apps from `/factory-new` have one from the start. In an
  app without instrumented tests, the builder lists those criteria under
  "Not verified (needs a tap)" and the approver treats them as a known gap.
  For screenshots of screens only reachable by taps, set `UI_TEST_SCREENS`
  to a test class that calls `FactoryShots.save("name")`. Its PNGs land in
  the round's `shots/` folder.

**Permission dialogs.** `PERMISSION_GRANTS` pre-grants runtime permissions
with `pm grant` after every install, location included, so a granted request
returns at once without a dialog. `factoryNoPrompts` is still there for the
app's own rationale screens and pre-permission prompts: every permission
request checks it first.

The `SCREENS` list in config.sh is captured for every job. The spec adds
job-specific ones to the job's `screens.txt`. Screenshots show a fixed status
bar (12:00, full battery and signal, no notification icons) so rounds compare
cleanly.

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

## Google Play

`/play` never uploads without asking. It runs the full test suite on `main`,
then **builds the release variant (shrunk by R8), installs it on the emulator
and checks it launches**, because a missing keep rule only crashes release
builds. It checks Room schema changes since the last `play/*` tag for a
migration, lists ⚠ ship notes, manifest changes that need the Data safety form
or a permission declaration updated, the target API level, and open
high-priority bugs, and offers a version name bump. The version code is set
per upload (minutes since 2020, so it only goes up).

Then it builds the signed bundle and uploads it to the internal track via
`factory/scripts/play.sh` (or your own script, set by `PLAY_CMD`; it must
honour `VERSION_CODE`). Afterwards it moves Unreleased into a dated release,
writes the release notes, stamps the roadmap, and tags the commit.

- **Signing** uses your upload key from the environment: `ANDROID_KEYSTORE_PATH`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Keep
  the keystore outside the repo. Play App Signing holds the app signing key.
- **Uploading** uses fastlane with a Play Console service account key
  (`PLAY_JSON_KEY`). Without them, `/play` builds the bundle and walks you
  through uploading it by hand.
- **The first upload of a new app is always by hand**: Play's API only works
  once the app exists in Play Console.

## When the factory itself has a bug

Jobs sometimes trace a failure to the factory's own scripts rather than your
app. The orchestrator asks you, fixes it on the app's main branch as a
separate commit, and logs it in `factory/UPSTREAM.md`. The job then carries
on. Port the fix to android-factory when it suits you. Until you do,
`install.sh --update` keeps the app's fixed copy (instead of reinstalling
the bug) and prints the diff to port. It ticks the entry once android-factory
has the fix.

## Limits and choices

- **Screens are reached by intent extras, deep links and UI tests.** adb can
  tap by coordinates, but the factory doesn't rely on it: a tap that matters
  is proven by a UI test that repeats every round. Without instrumented
  tests, behaviour behind a tap is judged from code and reported as not
  verified.
- **Emulator start-ups queue.** Two copies of one AVD booting at the same
  moment corrupt each other's disk images, so `droid.sh` starts one
  emulator at a time (about a minute each). Once booted, a job's emulator
  stays up between rounds until the job merges or is abandoned.
  `droid.sh cleanup <job>` stops one by hand. `FACTORY_ANDROID_SERIAL=<serial>`
  pins all jobs to one running device as a fallback, at the cost of parallel
  isolation.
- **Ports 5580–5680.** Job emulators use those, leaving 5554–5578 for the ones
  you start yourself. Claims live in `~/.android-factory/`.
- **One orchestrator per session.** A session that runs `/factory` is busy
  until the job ends or pauses. Use more terminals for more parallel jobs.
- **Nothing is pushed.** Merges are local. `/play` is the only thing that
  talks to Google, and only after you confirm.
- **Checks run once per round, by the orchestrator**, not by each reviewer.
  Gradle builds and emulators are heavy, and four reviewers building at once
  would fight over the device. Reviewers read `checks.md` and the
  screenshots instead.
- **One platform per repo.** android-factory and ios-factory install the same
  file names (`factory/`, `.claude/skills/factory/`), so a repo uses one of
  them. A repo with both apps uses [mobile-factory](../mobile-factory/).

See [TECH_NOTES.md](TECH_NOTES.md) for how it works inside: file formats, the
job state machine, scripts, and how to change the loop.
