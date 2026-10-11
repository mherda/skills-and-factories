# Mobile Factory for Claude Code

The software factory for a repo that ships **an iOS app and an Android app**,
with or without shared code (a Kotlin Multiplatform `shared/` module, say).
It's [ios-factory](../ios-factory/) and [android-factory](../android-factory/)
in one: one roadmap, one set of decisions, one inbox, one wiki and one
dashboard, with both toolchains underneath.

You type `/factory <feature>`. The spec says which platforms the feature
covers. The builder implements it on each, the checks build, test and
screenshot every platform the branch touches, the reviewers look at both, and
it merges to `main` once. Releases stay per platform: `/testflight` and
`/play`.

```
request ─► spec-writer ─► builder ─► CHECKS (each platform touched) ─► [code, privacy, ux, release] ─► approver ─► documenter ─► merge
              │  Platforms: ios, android     iOS: xcodebuild · simulator shots                                                 │
              │                              Android: Gradle · Lint · emulator shots           releases.md [ios] / [android] ─┴─► /testflight, /play
              ▼
          NEEDS-INPUT ──► factory/issues/ISS-n ◄── /issues (you answer) ──► /factory resume <job>
```

Use a single-platform factory for a repo with one app. Use this one when both
apps live in one repo, which is required as soon as they share code.

## What's different from the single-platform factories

Everything in their READMEs holds: the commands, the agents, the trackers,
the wiki, the dashboard, confirm mode, parallel jobs, factory bug fixes via
`UPSTREAM.md`. On top of that:

- **Platforms per job.** The spec-writer writes a `## Platforms` line
  (`ios, android`, or one). Roadmap items can carry an `ios` or `android` ref;
  untagged items are for every platform in `PLATFORMS`.
- **Checks follow the change, not just the plan.** `platforms.sh check`
  covers the platforms the spec names **plus** every platform whose paths the
  branch changed (`IOS_PATHS`, `ANDROID_PATHS`). A change under `SHARED_PATHS`
  checks every platform, so a shared-code change made for one app can't break
  the other unseen. Platforms run one after the other (a shared Gradle build
  can't be built twice at once), and the round's `checks.md` has a section
  per platform plus one "Sensitive paths" list.
- **Screenshots from both**, in one gallery: `ios-<screen>-<variant>.png` and
  `android-<screen>-<variant>.png`. One `SCREENS` entry like
  `settings|screen:settings` opens the screen on both through each app's
  debug hook (`-factoryScreen settings -factoryNoPrompts` on iOS, the
  `factoryScreen` / `factoryNoPrompts` intent extras on Android).
  Platform-only screens go in `IOS_SCREENS` / `ANDROID_SCREENS`.
- **Reviewers cover both**, with each platform's checklist plus a
  cross-platform one: same behaviour and copy on both, each in its own
  idiom; logic both need lives in shared code; the same data gets the same
  protection on both.
- **Releases per platform from one file.** Merged lines in `releases.md` are
  tagged with the apps they change (`[ios]`, `[android]`, `[ios, android]`),
  ship notes with their platform. `/testflight` ships the ios lines, `/play`
  the android ones; a line for both stays under Unreleased until the second
  platform ships it. Feature pages say `shipped: ios 1.2 (…), android
  unreleased`.
- **One design, two artboards per screen.** `/design` draws each screen as an
  iPhone artboard and an Android artboard side by side, from one visual
  direction.
- **`/factory-new`** asks which platforms, and scaffolds the iOS app
  (XcodeGen, SwiftUI) and/or the Android app (Gradle, Compose), each with the
  screenshot hooks and tests. The two starter apps are independent: a shared
  module is a question for the app, not a default.

## Commands

| Command | What it does |
| --- | --- |
| `/factory-new [IDEA.md]` | New app from an idea, for iOS, Android or both |
| `/factory-init` | Onboard a repo (one app or both), or migrate one from ios-factory / android-factory |
| `/factory <feature>`, `next`, `ISS-12`, `confirm`, `status`, `resume`, `approve`, `rework`, `abandon` | The job loop, as in the single-platform factories |
| `/issues`, `/bug`, `/decide`, `/roadmap`, `/docs`, `/design` | The same as in the single-platform factories |
| `/testflight` | Ship the iOS app's unreleased work to TestFlight |
| `/play` | Ship the Android app's unreleased work to Google Play's internal track (with a release-build smoke test) |

## Scripts

| Script | What it does |
| --- | --- |
| `platforms.sh list\|setup\|check\|cleanup <job>` | Which platforms a job covers and why; runs each platform's steps and merges the checks. The orchestrator uses it |
| `xc.sh` | iOS: build, test, run, screenshot on the job's own simulator (as in ios-factory) |
| `droid.sh` | Android: build, test, Lint, run, screenshot, release smoke test on the job's own emulator (as in android-factory) |
| `testflight.sh`, `play.sh` | Archive/upload to TestFlight; signed bundle/upload to Play |
| `sensitive_paths.py` | Changed files that need care, for both platforms (entitlements, Info.plist, manifest, Gradle, R8, data models…) |
| `scaffold.py` | Renders the starter app(s) for the chosen platforms |
| `jobstate.py`, `tracker.py`, `wiki.py`, `serve.py` | Shared with the other factories |

`xc.sh` and `droid.sh` are the single-platform scripts with a short block at
the top that maps the `IOS_*` / `ANDROID_*` settings onto their usual names,
plus platform-prefixed screenshots and a per-platform `check`. Keep them that
way, so a fix ports between the three factories.

## Requirements

Both toolchains for the platforms you ship: Xcode and (for XcodeGen projects)
XcodeGen for iOS; a JDK 17+, the Android SDK and an AVD for Android. Python 3
and git. See the single-platform READMEs for the details of each.

## Install into an app repo

```bash
./install.sh ~/projects/my-app      # copies .claude/ + factory/, never overwrites, updates .gitignore
cd ~/projects/my-app && git add -A && git commit -m "Add mobile factory"
claude                              # then: /factory-init  (or /factory-new for a new app)
```

### Moving a repo over from ios-factory or android-factory

```bash
./install.sh --update ~/projects/board-warriors   # swaps factory-owned files, keeps trackers
cd ~/projects/board-warriors && git diff --stat && git add -A && git commit -m "Switch to the mobile factory"
claude                                            # then: /factory-init  (it offers the migration)
```

`--update` replaces the agents, skills, scripts, templates and dashboard and
leaves the roadmap, decisions, issues, releases, product brief and wiki
alone. It warns that `factory/config.sh` is still in the old format.
`/factory-init` then migrates it: the old settings move to their `IOS_*` or
`ANDROID_*` names, `PLATFORMS` and the path globs are filled in from the
repo, existing release lines and feature pages get their platform tag, and
CLAUDE.md gains the other platform's commands and Screens. Your history and
open work carry over. Until the Android app exists, `PLATFORMS=(ios)` and the
Android work is roadmap items.

## Configuration

`factory/config.sh` has three parts. Comments explain each setting.

- **Shared**: `PLATFORMS`, the path globs that say which changes belong to
  which platform (`IOS_PATHS`, `ANDROID_PATHS`, `SHARED_PATHS`), the screens
  both apps capture (`SCREENS`), the screenshot variants, and the wiki.
- **iOS** (`IOS_PROJECT_DIR`, `SCHEME`, `BUNDLE_ID`, `SIM_DEVICE_TYPE`,
  `TESTFLIGHT_CMD`, …): the ios-factory settings, some with an `IOS_` prefix.
- **Android** (`ANDROID_PROJECT_DIR`, `APP_MODULE`, `APPLICATION_ID`,
  `AVD_NAME`, `LINT_TASK`, `PLAY_CMD`, …): the android-factory settings, some
  with an `ANDROID_` prefix.

With Gradle at the repo root (typical for Kotlin Multiplatform):
`ANDROID_PROJECT_DIR="."`, `APP_MODULE=":androidApp"`,
`ANDROID_PATHS=("androidApp/*")`, and
`SHARED_PATHS=("shared/*" "build.gradle.kts" "settings.gradle.kts" "gradle/*")`.

## Limits and choices

- **Checks take the sum of both platforms.** An iOS round and an Android round
  one after the other is roughly 5–10 minutes on a laptop, more on first
  boots. Jobs that touch one platform only check that one.
- **Shared code is checked through the apps.** `platforms.sh` builds and
  tests each app; the shared module's own tests run when the apps' builds or
  test tasks include them. Add them to the builder's routine in CLAUDE.md if
  they don't (for example `./gradlew :shared:allTests`).
- **No shared-module template.** `/factory-new` scaffolds independent native
  apps. Adding a Kotlin Multiplatform module is a job like any other, with
  its own decision.
- Everything in the single-platform factories' "Limits and choices" applies
  per platform.

See [TECH_NOTES.md](TECH_NOTES.md) for how it works inside.
