# Mobile Factory: Tech Notes

How the mobile factory works inside, for when you want to change it. The job
loop, `job.json`, the trackers, the question → answer → resume loop, the wiki
and the onboarding flow are the same as in the single-platform factories:
[ios-factory/TECH_NOTES.md](../ios-factory/TECH_NOTES.md) and
[android-factory/TECH_NOTES.md](../android-factory/TECH_NOTES.md) (which also
explain `xc.sh` and `droid.sh` in depth). This file covers what's different.

## 1. The moving parts

```
.claude/
  skills/   factory, issues, bug, decide, roadmap, docs, design, factory-init,
            factory-new, testflight (iOS), play (Android)
  agents/   one file per agent; each covers both platforms
factory/
  config.sh            shared settings + IOS_* + ANDROID_* (see §2)
  product.md, roadmap.md, decisions.md, releases.md, design.md, issues/, UPSTREAM.md
  jobs/                gitignored runtime state, one folder per job
  dashboard.html
  templates/app/       CLAUDE.md and gitignore.append (both platforms, "only:" markers),
                       ios/ (XcodeGen + SwiftUI), android/ (Gradle + Compose)
  templates/wiki/
  scripts/
    platforms.sh       which platforms a job covers; setup / check / cleanup across them
    xc.sh              iOS: per job simulator + DerivedData (ios-factory's, with a config map)
    droid.sh           Android: per job emulator (android-factory's, with a config map)
    test_summary_ios.py      xcresult + log → markdown
    test_summary_android.py  JUnit XML + Gradle log → markdown; Lint XML → markdown
    sensitive_paths.py both platforms' rule sets in one list
    testflight.sh, play.sh
    scaffold.py        renders templates/app/ for the chosen platforms
    jobstate.py, tracker.py, wiki.py, serve.py
  hooks/               pre-commit, post-commit (wiki checks)
```

## 2. Config and the platform scripts

`config.sh` keeps the single-platform settings, with a prefix where both
platforms use the same name: `IOS_PROJECT_DIR` / `ANDROID_PROJECT_DIR`,
`IOS_SETUP_CMD`, `IOS_COPY_INTO_WORKTREE`, `IOS_SCREENS`,
`IOS_UI_TEST_SCREENS`, `IOS_DATA_MODEL_GLOBS`, and the Android equivalents.
Settings only one platform has (`SCHEME`, `AVD_NAME`, `LINT_TASK`, …) keep
their names.

`xc.sh` and `droid.sh` start with a small block that maps their platform's
settings onto the unprefixed names (`PROJECT_DIR="$IOS_PROJECT_DIR"`, …) and
sets `PLATFORM`. Below that block they're the single-platform scripts, except:

- **Screens.** `SCREENS` (shared) plus `IOS_SCREENS` / `ANDROID_SCREENS`.
  `how` may be `screen:<name>`, which each script turns into its app's hook
  (`-factoryScreen <name> -factoryNoPrompts` / `--es factoryScreen <name>
  --ez factoryNoPrompts true`). Lines in a job's `screens.txt` with an
  `ios:` or `android:` prefix only apply to that platform.
- **Screenshot names** are prefixed with the platform (`ios-home-light.png`,
  `ui-android-dark/`), so both platforms share one `shots/` folder and the
  dashboard's gallery shows them side by side.
- **`check`** writes `round-N/<platform>/checks.md` (headings one level down)
  and its test artefacts in `round-N/<platform>/`, screenshots in
  `round-N/shots/`. It doesn't list sensitive paths; `platforms.sh` does that
  once.

Keeping the scripts this close to their originals is deliberate: a fix in one
factory's `xc.sh` or `droid.sh` applies to the other's with the same diff.

## 3. Which platforms a job covers

`platforms.sh` decides, at every check round:

1. The platforms the spec names. The orchestrator copies the spec's
   `## Platforms` line into `job.json` (`platforms: ["ios", "android"]`).
2. Every platform whose `IOS_PATHS` / `ANDROID_PATHS` match a file the branch
   changed (`git diff main...HEAD`).
3. Every platform, if a changed file matches `SHARED_PATHS`.
4. If none of that gives anything (a branch with no platform files yet and
   no spec platforms), every platform.

`platforms.sh list <job>` prints each covered platform with its reason, and
`checks.md` shows the same under "Platforms checked". Because (2) and (3) come
from the diff, a builder who touches the other app or shared code gets that
platform checked even if the spec didn't plan it, and the approver escalates
work on a platform the spec didn't name.

Checks run one platform at a time. In a Kotlin Multiplatform repo both apps
can build through the same Gradle project, and two Gradle builds in one
project dir block on each other's locks; Xcode and Gradle together would also
fight for CPU. The round's verdict is PASS only if every covered platform
passes.

## 4. Releases from one file

`releases.md` is shared and the platforms ship separately, so lines carry
tags:

```
## Unreleased
- [ios, android] Streaks · job 005: complete a habit two days running
  - ⚠ [Android] Update the Data safety form
- [ios] Lock-screen widget · job 006: add the widget, tap a habit

## iOS 1.2 (202610151200) · 2026-10-15
What to test: …
```

The merge step tags each line with the platforms the final round checked
(the apps the merge changed, shared code included). `/testflight` takes the
`[ios]` lines and copies the `[ios, android]` ones, which stay under
Unreleased retagged `[android]` with only their Android ship notes. `/play`
does the mirror image. Tags are per platform: `testflight/<version>-<build>`
and `play/<version>-<code>`, and each skill diffs from its own last tag,
limited to its platform's paths plus shared paths.

Feature pages in the wiki list each platform: `shipped: ios unreleased,
android unreleased`. Each release replaces its own platform's `unreleased`.

## 5. Templates

`scaffold.py` renders `templates/app/` for `platforms` in `values.json`:
`ios/` and `android/` are skipped unless chosen, and lines in CLAUDE.md (and
any other file) ending in `<!-- only:ios -->`, `# only:android`, etc. are kept
only when that platform (or, for `only:iphone` / `only:universal`, that iOS
device family) applies. Placeholders are the union of both factories':
`{{APP}}`, `{{DISPLAY_NAME}}`, `{{BUNDLE_ID}}`, `{{TEAM_ID}}`, `{{IOS_MIN}}`,
`{{DEVICE_FAMILY}}`, `{{APPLICATION_ID}}`, `{{MIN_SDK}}`, `{{COMPILE_SDK}}`,
`{{TARGET_SDK}}`; `__APP__` and `__PKG__` in paths.

To check the templates on a scratch folder: `install.sh /tmp/x`,
`scaffold.py values.json --dest /tmp/x`, fill `config.sh` as the skill does,
commit, then `platforms.sh check main 1` and `platforms.sh cleanup main`.

## 6. Changing the factory

- **A fix that applies to all three factories** (trackers, wiki, dashboard,
  the loop): port it to ios-factory and android-factory too. Most files under
  `factory/scripts/` other than the platform scripts are identical in all
  three, apart from `jobstate.py` (the `platforms` field), `wiki.py`
  (`SOURCE_EXT`) and the dashboard title.
- **A platform script fix**: apply the same diff to the single-platform
  factory's copy, skipping the config map block.
- **Agents**: each has shared rules plus "iOS" and "Android" sections. Keep a
  rule in the shared part if it holds for both.
- **Another platform** (watchOS, Wear OS, web): a script with the same
  commands and config-map pattern, a case in `platforms.sh`'s `script_for`,
  its paths in config, and a section in each agent.
