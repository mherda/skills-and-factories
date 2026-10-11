# {{DISPLAY_NAME}}

<!-- /factory-new: replace with two or three sentences from factory/product.md:
what the app is and who it's for. -->

- iOS: native Swift 6 / SwiftUI, iOS {{IOS_MIN}}+, in `ios/`. <!-- only:ios -->
- Android: native Kotlin / Jetpack Compose (Material 3), minSdk {{MIN_SDK}}, targetSdk {{TARGET_SDK}}, in `android/` (package `{{APPLICATION_ID}}`). <!-- only:android -->

## Factory
- Plan and status: `factory/roadmap.md`. Settled choices: `factory/decisions.md`
  (read before changing anything; never contradict it without asking).
  Bugs and open questions: `factory/issues/`. Product brief: `factory/product.md`.
  Shipped builds: `factory/releases.md`.
- How the code works: `docs/wiki/` (start at `docs/wiki/index.md`).
- Build, test, run and screenshot through the factory scripts, not raw tools,
  so jobs get their own devices (`build|test|run|shots <job>`):
  - iOS: `factory/scripts/xc.sh` (simulator). Releases: `/testflight`. <!-- only:ios -->
  - Android: `factory/scripts/droid.sh` (emulator). Releases: `/play`. <!-- only:android -->

## Commands
```sh
cd ios && xcodegen generate     # after adding, removing or renaming any iOS file # only:ios
factory/scripts/xc.sh build main # only:ios
factory/scripts/xc.sh test main build/test-ios # only:ios
factory/scripts/droid.sh build main # only:android
factory/scripts/droid.sh test main build/test-android # only:android
cd android && ./gradlew :app:testDebugUnitTest    # Android unit tests only, no emulator # only:android
```
The `.xcodeproj` is generated and gitignored: edit `ios/project.yml`, never <!-- only:ios -->
`Info.plist` or `.entitlements`. A stale project gives phantom "Cannot find type" errors. <!-- only:ios -->
Android dependency and plugin versions live only in `android/gradle/libs.versions.toml`. <!-- only:android -->

## Conventions
<!-- /factory-new: the conventions from factory/decisions.md, one line each with
its D-id, e.g. "- Services are `@MainActor @Observable final class` (D-004)." -->
- A feature that exists on both platforms behaves the same on both, unless a
  decision or the spec says otherwise. Copy matches word for word.
- iOS: strict concurrency is on; framework callbacks on background queues hop to main explicitly. <!-- only:ios -->
- iOS tests: Swift Testing in `ios/{{APP}}Tests/`; taps get an XCUITest in `ios/{{APP}}UITests/`, launched with `-factoryNoPrompts`. <!-- only:ios -->
- Android: single activity, all UI in Compose, strings in `res/values/strings.xml`. <!-- only:android -->
- Android tests: JUnit in `android/app/src/test/`; taps get a Compose UI test in `android/app/src/androidTest/`, launched with `factoryNoPrompts`. <!-- only:android -->
- Android release builds are shrunk by R8: reflection or serialization needs keep rules in `app/proguard-rules.pro`. <!-- only:android -->
- A permission request checks `FactoryLaunch.noPrompts` first.
- iOS purpose strings go in `ios/project.yml`. <!-- only:ios -->
- Android permissions are declared in `AndroidManifest.xml` and requested at runtime. <!-- only:android -->

## Screens
Debug-only hooks open any screen directly, so the factory can screenshot it.
Every new screen worth a screenshot gets a case on each platform that has it,
a row here, and an entry in `SCREENS` in `factory/config.sh` (`name|screen:<name>`
covers both platforms). A hook that writes or clears stored data runs before
the first view reads it.
- iOS: `ios/{{APP}}/App/FactoryLaunch.swift`, handled in `Views/ContentView.swift`. Flags with no value are read from `ProcessInfo.processInfo.arguments`. <!-- only:ios -->
- Android: `FactoryLaunch.kt`, handled in `ui/AppRoot.kt`; data hooks run in `MainActivity.onCreate` before `setContent`. <!-- only:android -->

| Screen | iOS launch argument | Android `am start` extras |
|---|---|---|
| Home | (none) | (none) |
| Settings | `-factoryScreen settings` | `--es factoryScreen settings` |
| Skip permission prompts | `-factoryNoPrompts` | `--ez factoryNoPrompts true` |
