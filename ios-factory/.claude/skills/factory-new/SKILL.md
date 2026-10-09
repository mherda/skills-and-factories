---
name: factory-new
description: Start a new iOS app from an idea. Reads an idea file (or the user's description), suggests improvements for the user to approve, optionally prototypes the key screens as a Claude Design canvas, drafts the product brief, decisions (the factory's default stack plus what the idea settles) and a roadmap, asks the user questions in rounds, renders a buildable starter app (XcodeGen, SwiftUI shell, screenshot hooks, tests), seeds the wiki, checks it builds, tests and screenshots, and commits it all on a branch. Use when the user types /factory-new [file] [--as-is], or asks to start, create or bootstrap a new app with the factory.
---

# Factory new

Turns an idea into a repo the factory can work in: a plan, settled
choices and an app that builds. After it, `/factory next` starts the first
feature. Its sibling `/factory-init` onboards an app that already exists.

`S=<repo>/factory/scripts`.

## 0. Preconditions

- The factory is installed (`factory/`, `.claude/skills/factory/`). If not,
  tell the user to run `<path to ios-factory>/install.sh <folder>`. That works
  on a new or empty folder, and runs `git init` there.
- **No app yet.** If the repo has a `*.xcodeproj`, `project.yml`,
  `Project.swift`, `Package.swift` or Swift sources outside `factory/`, stop
  and point to `/factory-init`.
- **The idea.** Use the file the user named. Otherwise use the first of
  `IDEA.md`, `idea.md`, `IDEA.txt` or `README.md` at the root that describes
  an app. If there's none, ask the user to describe the app in a few
  sentences, and write their answer verbatim to `IDEA.md`.
- **Git.**
  - If the repo has no commits yet, the factory files are the only content.
    Ask: "Commit the factory files as the first commit?" (Recommended) /
    "Cancel". On yes, commit everything except the idea file as
    `Install iOS factory`.
  - Otherwise the working tree must be clean, apart from an untracked idea
    file.
- **XcodeGen.** If `command -v xcodegen` fails, offer `brew install xcodegen`
  and wait for it. The build can't run without it.
- If `factory/init/` exists from an earlier run, offer to resume from its
  drafts or start over.

## 1. Shape the idea

Skip this step with `--as-is`, or if the user says they want the idea
planned as written.

`mkdir -p factory/init` and spawn `app-planner` with
`Mode: shape. Repo: <repo>. Factory: <repo>/factory/. Idea: <repo>/<idea file>. Write to <repo>/factory/init/.`
It writes `suggestions.md`.

Show its opening paragraph, then each suggestion in one or two lines: the
id, the title, the kind, the cost and the gist. Then ask, with
AskUserQuestion, up to four suggestions per call. Each question is a
suggestion's title and gist, with the options "Yes" / "Yes, changed" /
"Later" / "No".
- **Yes**: approved as written.
- **Yes, changed**: ask what to change, in the user's own words, and record
  it.
- **Later**: approved, but parked. It goes in the roadmap's `## Later`
  section, not in the MVP.
- **No**: rejected.
The user can also say "all yes" or "none" at any point.

Record each decision under its suggestion in `suggestions.md`, as
`Verdict: yes | yes, changed: <note> | later | no`. Then show the result in
one line, for example "Approved S1, S2, S4 (S4 changed), parked S6,
rejected S3, S5", and confirm before drafting. **Nothing goes into the plan
that the user hasn't approved.**

The idea file itself stays as the user wrote it. The approved suggestions
live in `suggestions.md`, which is archived next to it.

## 1a. Prototype the screens (optional)

Ask: "Prototype the key screens before planning?", with these options:
- "Yes" (Recommended), described as "a Claude Design canvas on claude.ai, one
  phone screen per artboard; you can comment on it and approve";
- "Later", described as "plan now, run /design new any time";
- "No".

On **Yes**, run the `/design` skill's **new** flow, with
`factory/init/design.md` as its design.md (copy the template from
`factory/design.md` first). Its brief is the idea plus the approved
suggestions. Then loop:
1. Give the user the link.
2. Ask: "Approve all" / "Revise" (a note, or comments left on the canvas) /
   "Approve some" / "Stop here (keep as draft)".
3. On Revise, run `/design revise` and ask again.

On approve, run `/design approve`, but hold back its decision offers: they
go to the planner instead. Agreed design rules become decisions in step 1b.
The screen list and the direction now shape the plan.

## 1b. Plan

Spawn `app-planner` with
`Mode: draft. Repo: <repo>. Factory: <repo>/factory/. Idea: <repo>/<idea file>. Approved suggestions: <ids, with changes and "later" flags>. Rejected: <ids>. Write drafts to <repo>/factory/init/.`
(with `--as-is`: `Approved suggestions: none (as-is)`). If step 1a ran, add
`Design: <repo>/factory/init/design.md (<approved | draft>). Design rules the user agreed: <list>.`
It writes these
drafts:
- `product.md`, `decisions.md`, `roadmap.md`, `releases.md`, `config.sh`;
- `scaffold.json` and `questions.md`;
- `summary.md`;
- sometimes `issues/`.

Show the user `summary.md`, compactly: the app in two sentences, the
scaffold values, the counts, and the risks.

## 2. Ask, in rounds

Go through `questions.md` with AskUserQuestion, **up to four questions per
call**, `Required: yes` first, then the most consequential. For each one:
- a header of `Q<n>` plus the topic, and the question;
- the options, with "(Recommended)" on the first;
- "Other" for free text (a name, a bundle id).

- Before the first round, say how many questions there are. Say that the
  required ones decide the project's names. Optional ones the user skips keep
  the recommended default, or become issues if there's no sensible default.
- After each round, apply the answers to the drafts right away. A scaffold
  answer updates `scaffold.json` **and** the matching values in `config.sh`
  (`XCODE_CONTAINER`, `SCHEME`, `BUNDLE_ID`, `TEAM_ID`, `DATA_MODEL_GLOBS`).
  Record each answer under its question as `Answer: …`.
- An answer that settles a choice becomes a decision with `Source: user`.
  If it overrides a factory default, edit that decision rather than adding a
  contradicting one.
- After every two rounds, ask whether to continue or stop and keep the
  defaults.
- Check the scaffold values with
  `python3 -I $S/scaffold.py factory/init/scaffold.json --dry-run`. It names
  any value that's invalid. Ask again for those.

## 3. Review

Show the final picture before writing anything:
- `product.md`, in full (it's short);
- the decisions, one line each (id, title, source), with factory defaults
  and the idea's choices in separate groups;
- the roadmap, rendered with
  `FACTORY_DIR=factory/init python3 -I $S/tracker.py roadmap`;
- the files the scaffold will create (the `--dry-run` output), plus the app
  name, bundle id, iOS minimum and devices;
- `TEAM_ID`: if it's empty, say that building and testing on the simulator
  work, but a device and `/testflight` need it.

Ask: "Apply" (Recommended) / "Change something" / "Cancel". Cancel deletes
`factory/init/` and stops.

## 4. Apply on a branch

1. `git switch -c factory/init`.
2. Move the drafts into place:
   - `factory/product.md`, `factory/decisions.md`, `factory/roadmap.md`,
     `factory/releases.md`, `factory/config.sh` and `factory/issues/ISS-*.md`.
   - Keep the format comment blocks at the top of roadmap.md and
     decisions.md.
   - Add the scaffold to the top of M1 as done: `- [x] App scaffold (/factory-new)`.
   - `factory/design.md`, if step 1a ran. Its link stays the same, since the
     canvas lives on claude.ai.
3. Render the app: `python3 -I $S/scaffold.py factory/init/scaffold.json --dest .`.
4. Fill in CLAUDE.md. Replace its two `/factory-new` comments: one with
   the app in two or three sentences from product.md, the other with the
   conventions from decisions.md, one line each with its D-id. If the user
   asked for a translation guide, add a pointer to it.
5. Check it builds:
   - `$S/xc.sh setup main`, then `$S/xc.sh build main`.
   - Then, in the background, `$S/xc.sh test main build/new-app` and
     `$S/xc.sh shots main build/new-app/shots`.
   - Look at `home-light.png` and `settings-light.png`. They should show the
     shell with no system alert.
   - If the build fails, fix the cause, which is usually a scaffold value
     such as a bundle id that clashes with a reserved one. Don't hand back an
     app that doesn't build.
6. Seed the wiki. Spawn `documenter` with
   `Job id: init. Job folder: <repo>/factory/init/. Worktree: <repo>. Branch: none (don't commit). Factory: <repo>/factory/. Mode: seed. Sources: the starter app in ios/, factory/product.md and factory/decisions.md. Target: <repo>/docs/wiki/. Write docs.md to <repo>/factory/init/docs.md.`
   Ask for these pages:
   - `architecture/overview.md` (the targets, the app structure, and where
     each kind of code goes as the app grows);
   - `modules/app-shell.md` (App, ContentView, FactoryLaunch, AppInfo);
   - `guides/build-and-run.md` (XcodeGen, xc.sh, screenshots, simulators);
   - a translation guide, if the user asked for one;
   - the glossary, seeded from product.md's domain words.
   
   Then run `python3 -I $S/wiki.py index`, then `wiki.py lint`, and fix any
   errors.
7. Archive the idea: `git mv` (or `mv`, if it's untracked) to
   `docs/archive/IDEA.md`, and move `factory/init/suggestions.md` to
   `docs/archive/IDEA-suggestions.md`, with its verdicts. Then write
   `docs/archive/README.md` with a table from the idea's sections and each
   approved suggestion to where it went (product.md, decisions D-…,
   roadmap milestones, issues), as `/factory-init` does. If the idea was
   `README.md`, leave a short README in its place: the app name, one line,
   and pointers to `factory/product.md` and `docs/wiki/index.md`.
8. Delete `factory/init/`.
9. Validate:
   - `tracker.py roadmap`, `tracker.py decisions` and `tracker.py issues`
     all parse;
   - `bash -n factory/config.sh` passes;
   - `git status --porcelain` shows nothing that `.gitignore` should have
     caught, such as `ios/*.xcodeproj` or `build/`.
10. Commit `New app: <display name> (product brief, decisions, roadmap, starter app, wiki)`.
    Then ask whether to merge `factory/init` into `main` now, and merge with
    `--no-ff` on yes. Never push. If the user wants a GitHub remote, show the
    `gh repo create` command for them to run.

## 5. Hand-off

Tell the user:
- what landed: decisions, milestones and items, wiki pages and issues;
- the two screenshots (paths);
- that `TEAM_ID` is needed before a device build or `/testflight`, if it's
  still empty.

The next step is `/factory next`, which picks the first M1 item. Mention that
`/roadmap` shows the plan, and that `python3 -I factory/scripts/serve.py`
opens the dashboard.
