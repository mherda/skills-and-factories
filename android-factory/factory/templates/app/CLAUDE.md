# {{DISPLAY_NAME}}

<!-- /factory-new: replace with two or three sentences from factory/product.md:
what the app is and who it's for. -->

Native Kotlin / Jetpack Compose (Material 3), minSdk {{MIN_SDK}}, targetSdk
{{TARGET_SDK}}. Package `{{APPLICATION_ID}}`.

## Factory
- Plan and status: `factory/roadmap.md`. Settled choices: `factory/decisions.md`
  (read before changing anything; never contradict it without asking).
  Bugs and open questions: `factory/issues/`. Product brief: `factory/product.md`.
  Shipped builds: `factory/releases.md`.
- How the code works: `docs/wiki/` (start at `docs/wiki/index.md`).
- Build, test, run and screenshot through `factory/scripts/droid.sh`
  (`droid.sh build|test|run|shots <job>`), not raw `./gradlew` or `adb`, so
  jobs get their own emulator. Play uploads go through `/play`.

## Commands
```sh
factory/scripts/droid.sh build main
factory/scripts/droid.sh test main build/test
cd android && ./gradlew :app:testDebugUnitTest    # unit tests only, no emulator
```
Dependency and plugin versions live only in `android/gradle/libs.versions.toml`.

## Conventions
<!-- /factory-new: the conventions from factory/decisions.md, one line each with
its D-id, e.g. "- One ViewModel per screen, exposing StateFlow (D-004)." -->
- Single activity (`MainActivity`), all UI in Compose. Strings in
  `res/values/strings.xml`, never hard-coded in composables.
- Tests: JUnit in `android/app/src/test/` (local, no emulator). Behaviour that
  needs a tap ("tap X, then Y happens") gets a Compose UI test in
  `android/app/src/androidTest/`, launched with `factoryNoPrompts`.
- A permission request checks `FactoryLaunch.noPrompts` first, and the
  permission is declared in `AndroidManifest.xml`.
- Release builds are shrunk by R8: code that uses reflection or serialization
  needs keep rules in `app/proguard-rules.pro`.

## Screens
Debug-only intent extras read in `FactoryLaunch.kt`, handled in
`ui/AppRoot.kt`. Every new screen worth a screenshot gets a case there, a row
here and an entry in `SCREENS` in `factory/config.sh`. A hook that writes or
clears stored data runs in `MainActivity.onCreate`, before `setContent`.

| `am start` extras | Effect |
|---|---|
| (none) | Home |
| `--es factoryScreen settings` | Settings |
| `--ez factoryNoPrompts true` | Skip permission requests |
