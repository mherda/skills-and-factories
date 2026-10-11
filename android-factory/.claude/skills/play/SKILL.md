---
name: play
description: Ship main to Google Play's internal testing track safely. Runs the pre-flight checklist (tests, release-build smoke test, Room migrations, permissions and Data safety, target API, ship notes), uploads with the user's confirmation, then records the build in releases.md, roadmap and docs. Use when the user types /play or asks to ship, release or upload a build.
---

# Play

This is the only way factory work leaves the machine. Never upload without the
user's explicit go-ahead in this conversation.

Read `factory/config.sh` for `PROJECT_DIR`, `APP_MODULE`, `VARIANT`,
`APPLICATION_ID`, `PLAY_TRACK`, `PLAY_CMD`, `WIKI_DIR` and
`DATA_MODEL_GLOBS`. `S=<repo>/factory/scripts`.

## 1. What's going out

1. The main checkout must be on `main` and clean outside `factory/`. If not,
   stop and say why.
2. Find the last release tag: `git tag --list 'play/*' --sort=-creatordate | head -1`.
   If there's none, use the first commit.
3. Show the user `## Unreleased` from `factory/releases.md` (features, fixes and
   ⚠ ship notes), plus `git log --oneline <last tag>..main` for commits that
   didn't come from the factory.
4. If Unreleased is empty and there are no commits, say there's nothing to
   ship and stop.

## 2. Pre-flight checklist

Run each check and show a ✓/⚠/✗ list:

- **Tests**: `$S/droid.sh test main <repo>/build/factory-main-tests` (in the
  background, since it's slow). ✗ blocks the release.
- **Release build**: `$S/droid.sh smoke main <repo>/build/factory-main-smoke`
  (in the background). It builds the release variant with R8, installs it on
  the emulator, launches it and checks it didn't crash. ✗ blocks the release:
  usually a missing keep rule in `proguard-rules.pro`. Look at
  `release-launch.png` too. Then `$S/droid.sh cleanup main`.
- **Database**: `git diff --name-only <last tag>..main` matched against
  `DATA_MODEL_GLOBS`, plus any Room annotation changes in the diff. If the
  schema changed, check that the database version went up, that a
  `Migration` (or `AutoMigration`) covers every step from the last shipped
  version, and that a migration test exists. ✗ if a migration is missing:
  testers' data would be lost or the app would crash on update.
- **Ship notes**: every `⚠` line under Unreleased must be confirmed done by the
  user.
- **Permissions and Data safety**: if any `AndroidManifest.xml` changed since
  the last tag, list the permissions, exported components and intent filters
  that changed. New data collection or sharing means the Data safety form in
  Play Console must be updated before review. Restricted permissions
  (background location, exact alarms, all-files access, SMS, call log) need
  their declaration form filled in. Ask the user to confirm.
- **Target API**: show `targetSdk`. Google Play requires new apps and
  updates to target a recent API level (about a year behind the newest
  Android). ⚠ if it looks behind, and say that Play Console's policy status
  page has the current deadline.
- **Version**: show `versionName` (from the app module's
  `build.gradle(.kts)`). Ask whether to keep it or bump it (patch, minor,
  custom). If they bump it, change it there and commit `Bump version to <v>`.
  The version code is set per upload (below), never in the file.
- **Open high-priority bugs**: `tracker.py issues open needs-input`, filtered to
  `priority: high`. Show them as ⚠ so the user knows what testers will still
  hit.
- **Signing and upload**: the upload key env vars (`ANDROID_KEYSTORE_PATH`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`)
  must be set: ✗ without them. Automatic upload also needs `fastlane` and
  `PLAY_JSON_KEY` (a Play Console service account key); ⚠ without them, the
  bundle is built and the user uploads it by hand. If the app has never been
  uploaded (no `play/*` tag and the user hasn't said otherwise), say that the
  first upload must be done by hand in Play Console, which creates the app.

## 3. Confirm and upload

Write the release notes ("What's new" for testers) from Unreleased: plain
sentences, at most 500 characters (Play's limit per language), features
first, then fixes, with no job ids. Show them.

The version code is the minutes since 2020-01-01, which only goes up and fits
Play's limit: `VERSION_CODE=$(( ($(date +%s) - 1577836800) / 60 ))`.

Ask with AskUserQuestion: "Upload <versionName> (<version code>) to the
<PLAY_TRACK> track?" with the options Upload (Recommended once all checks
pass) and Not now.

On Upload, run
`cd <repo>/<PROJECT_DIR> && VERSION_CODE=<n> <repo>/<PLAY_CMD>` in the
background and wait.
- Exit 0: uploaded.
- Exit 3: built but not uploaded (no fastlane or `PLAY_JSON_KEY`). Give the
  user the `.aab` path and the steps: Play Console → the app → Test and
  release → Internal testing → Create new release → upload the bundle, paste
  the notes, save and roll out. Ask them to say when it's done, then record
  it as below.
- Anything else: show the relevant error lines. Signing problems mean the
  keystore env vars are wrong. "Package not found" from the API means the
  app doesn't exist in Play Console yet, so the first upload has to be by
  hand. A rejected version code means it isn't higher than the last one.
  Stop there.

## 4. Record it

After a successful upload:

1. `releases.md`: rename `## Unreleased` to
   `## <versionName> (<version code>) · <YYYY-MM-DD>`, put the release notes
   under it as a `What to test:` paragraph, and add a fresh empty
   `## Unreleased` above it.
2. `roadmap.md`: for each item whose job is in this release, append
   ` · Play <versionName> (<version code>)`.
3. Wiki: in every `<WIKI_DIR>/features/*.md` with `shipped: unreleased`, set
   `shipped: <versionName> (<version code>)`, then run
   `python3 -I $S/wiki.py index`.
4. Commit
   `git add factory/releases.md factory/roadmap.md <WIKI_DIR> && git commit -m "Play <versionName> (<version code>)"`,
   then `git tag play/<versionName>-<version code>`. Don't push unless the
   user asks.
5. Tell the user: internal testers get the build within minutes once Play
   has processed it, the release notes (if they uploaded by hand, these are
   already in), and any ⚠ items still open.
