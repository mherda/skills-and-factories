---
name: testflight
description: Ship main to TestFlight safely. Runs the pre-flight checklist (tests, CloudKit schema, privacy, ship notes), uploads with the user's confirmation, then records the build in releases.md, roadmap and docs. Use when the user types /testflight or asks to ship, release or upload a build.
---

# TestFlight

This is the only way factory work leaves the machine. Never upload without the
user's explicit go-ahead in this conversation.

Read `factory/config.sh` for `PROJECT_DIR`, `SCHEME`, `TESTFLIGHT_CMD`,
`WIKI_DIR` and `DATA_MODEL_GLOBS`. `S=<repo>/factory/scripts`.

## 1. What's going out

1. The main checkout must be on `main` and clean outside `factory/`. If not,
   stop and say why.
2. Find the last release tag: `git tag --list 'testflight/*' --sort=-creatordate | head -1`.
   If there's none, use the first commit.
3. Show the user `## Unreleased` from `factory/releases.md` (features, fixes and
   ⚠ ship notes), plus `git log --oneline <last tag>..main` for commits that
   didn't come from the factory.
4. If Unreleased is empty and there are no commits, say there's nothing to
   ship and stop.

## 2. Pre-flight checklist

Run each check and show a ✓/⚠/✗ list:

- **Tests**: `$S/xc.sh test main <repo>/build/factory-main-tests` (in the
  background, since it's slow). ✗ blocks the release.
- **Data model / CloudKit**: `git diff --name-only <last tag>..main` matched
  against `DATA_MODEL_GLOBS`, plus any `@Model` / `@Attribute` changes in the
  diff. If the app syncs with CloudKit, ⚠ "Deploy the CloudKit schema to
  Production in the CloudKit console *before* testers install this build. New
  fields only reach Production when deployed." Ask the user to confirm they've
  done it. Don't continue until they say yes or that it's not needed.
- **Ship notes**: every `⚠` line under Unreleased must be confirmed done by the
  user.
- **Permissions and privacy**: if any `*Info.plist`, `*.entitlements` or
  `PrivacyInfo.xcprivacy` changed since the last tag, list what changed. New
  capabilities may need enabling on the App ID, and new data collection may
  need the App Privacy answers in App Store Connect updated.
- **Export compliance**: check that `ITSAppUsesNonExemptEncryption` is set in
  the app's Info.plist (or project.yml). If it isn't, ⚠ every build will ask in
  App Store Connect.
- **Version**: show `MARKETING_VERSION` (from project.yml or build settings). Ask
  whether to keep it or bump it (patch, minor, custom). If they bump it, change
  the value in the source of truth (project.yml for XcodeGen, otherwise the
  build settings), commit `Bump version to <v>`.
- **Open high-priority bugs**: `tracker.py issues open needs-input`, filtered to
  `priority: high`. Show them as ⚠ so the user knows what testers will still
  hit.

## 3. Confirm and upload

Write the TestFlight "What to Test" notes from Unreleased: plain sentences for
testers, at most about 4,000 characters, features first, then fixes, with no
job ids. Show them.

Ask with AskUserQuestion: "Upload <version> (<build>) to TestFlight?" with the
options Upload (Recommended once all checks pass) and Not now. The build number
is `BUILD_NUMBER=$(date +%Y%m%d%H%M)`.

On Upload, run
`cd <repo>/<PROJECT_DIR> && BUILD_NUMBER=<n> <repo>/<TESTFLIGHT_CMD>` in the
background and wait. On failure, show the relevant error lines. Signing and
auth problems usually mean the API key env vars (`ASC_KEY_ID`,
`ASC_ISSUER_ID`, `ASC_KEY_PATH`) or the Xcode account need setting up. Stop
there.

## 4. Record it

After a successful upload:

1. `releases.md`: rename `## Unreleased` to
   `## <version> (<build>) · <YYYY-MM-DD>`, put the What to Test text under it
   as a `What to test:` paragraph, and add a fresh empty `## Unreleased` above
   it.
2. `roadmap.md`: for each item whose job is in this release, append
   ` · TF <version> (<build>)`.
3. Wiki: in every `<WIKI_DIR>/features/*.md` with `shipped: unreleased`, set
   `shipped: <version> (<build>)`, then run `python3 -I $S/wiki.py index`.
4. Commit
   `git add factory/releases.md factory/roadmap.md <WIKI_DIR> && git commit -m "TestFlight <version> (<build>)"`,
   then `git tag testflight/<version>-<build>`. Don't push unless the user asks.
5. Tell the user: the build appears in TestFlight after processing (usually
   5–15 minutes), the What to Test text to paste into App Store Connect, and
   any ⚠ items still open.
