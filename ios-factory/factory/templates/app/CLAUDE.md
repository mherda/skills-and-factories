# {{DISPLAY_NAME}}

<!-- /factory-new: replace with two or three sentences from factory/product.md:
what the app is and who it's for. -->

Native Swift 6 / SwiftUI, iOS {{IOS_MIN}}+.

## Factory
- Plan and status: `factory/roadmap.md`. Settled choices: `factory/decisions.md`
  (read before changing anything; never contradict it without asking).
  Bugs and open questions: `factory/issues/`. Product brief: `factory/product.md`.
  Shipped builds: `factory/releases.md`.
- How the code works: `docs/wiki/` (start at `docs/wiki/index.md`).
- Build, test, run and screenshot through `factory/scripts/xc.sh`
  (`xc.sh build|test|run|shots <job>`), not raw `xcodebuild`, so jobs get their
  own simulator and DerivedData. TestFlight goes through `/testflight`.

## Commands
```sh
cd ios && xcodegen generate     # after adding, removing or renaming any file
factory/scripts/xc.sh build main
factory/scripts/xc.sh test main build/test
```
The `.xcodeproj` is generated and gitignored. Edit `ios/project.yml`, never
`Info.plist` or `.entitlements`. A stale project gives phantom
"Cannot find type" errors.

## Conventions
<!-- /factory-new: the conventions from factory/decisions.md, one line each with
its D-id, e.g. "- Services are `@MainActor @Observable final class` (D-004)." -->
- Strict concurrency is on: framework callbacks on background queues must hop
  to main explicitly.
- Tests: Swift Testing in `ios/{{APP}}Tests/`.
- A permission request checks `FactoryLaunch.noPrompts` first, and its purpose
  string goes in `ios/project.yml`.

## Screens
Debug-only hooks in `App/FactoryLaunch.swift`, handled in
`Views/ContentView.swift`. Every new screen worth a screenshot gets a case
there, a row here and an entry in `SCREENS` in `factory/config.sh`.

| Launch argument | Effect |
|---|---|
| (none) | Home |
| `-factoryScreen settings` | Settings sheet |
| `-factoryNoPrompts` | Skip permission requests |
