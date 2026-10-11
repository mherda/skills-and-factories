# Mobile factory configuration (iOS + Android in one repo). Sourced by
# factory/scripts/*.sh. Every path is relative to the repo root unless it says
# otherwise. Edit this once when you install the factory; agents never edit it.
#
# xc.sh reads the IOS_* settings, droid.sh the ANDROID_* ones, and both read
# the shared ones. platforms.sh decides which platforms a job's checks cover.

# --- Platforms ---------------------------------------------------------------

# The platforms this repo ships: (ios android), (ios) or (android).
PLATFORMS=(ios android)

# Which changed paths belong to which platform. A job's checks cover every
# platform its branch touches, plus the ones its spec names. A change under
# SHARED_PATHS (shared code, the root Gradle build) checks every platform.
# Globs, matched against paths relative to the repo root.
IOS_PATHS=("ios/*")
ANDROID_PATHS=("android/*")
SHARED_PATHS=("shared/*")

# --- Screenshots (both platforms) ----------------------------------------------

# Screens captured for every review round, one per entry: "name|how".
#   "how" empty              → just launch the app
#   "how" = "screen:<name>"  → open that screen through the factory hook, with
#                              permission prompts skipped (iOS: -factoryScreen
#                              <name> -factoryNoPrompts; Android: the
#                              factoryScreen / factoryNoPrompts intent extras)
#   "how" = "url:<url>"      → launch, then open a deep link
# Screens only one platform has, or that need platform-specific launch
# arguments, go in IOS_SCREENS / ANDROID_SCREENS below. A job can add its own
# in <job folder>/screens.txt, same format, one per line; prefix a line with
# "ios:" or "android:" to limit it to one platform.
SCREENS=("launch|")

# Seconds to wait after launch / deep link before taking the screenshot.
SCREEN_WAIT=4

# Variants of every screen: light, dark, large-text.
SCREEN_VARIANTS=(light dark large-text)

# --- iOS ---------------------------------------------------------------------------

# Folder that holds the .xcodeproj / .xcworkspace (and project.yml if you use
# XcodeGen).
IOS_PROJECT_DIR="ios"

# Command run inside IOS_PROJECT_DIR of every fresh worktree before a build.
# XcodeGen: "xcodegen generate". Plain committed .xcodeproj: "".
IOS_SETUP_CMD=""

# How xcodebuild finds the project, relative to IOS_PROJECT_DIR.
XCODE_CONTAINER=(-project MyApp.xcodeproj)       # or (-workspace MyApp.xcworkspace)
SCHEME="MyApp"
BUNDLE_ID="com.example.MyApp"

# Gitignored files the iOS build needs that a fresh worktree won't have.
IOS_COPY_INTO_WORKTREE=()

# Each job gets its own simulator of this type on the newest runtime.
SIM_DEVICE_TYPE="iPhone 17 Pro"

# Permissions granted after install (names from `xcrun simctl privacy`).
# Location isn't honoured on current simulators: use -factoryNoPrompts.
SIM_PRIVACY_GRANTS=""

# Simulated location "lat,lon", or "".
SIM_LOCATION=""

# iOS-only screens, raw launch arguments allowed ("name|-factoryScreen x -factoryClearSave").
IOS_SCREENS=()

# Optional: a UI-test class whose tests attach screenshots, e.g. "MyAppUITests/FactoryScreens".
IOS_UI_TEST_SCREENS=""

TEAM_ID=""                                # Apple Developer team id
# Archives and uploads to TestFlight; run with IOS_PROJECT_DIR as its working
# directory. Must honour BUILD_NUMBER. The bundled one does.
TESTFLIGHT_CMD="factory/scripts/testflight.sh"
# Changed files that mean "check the data migration / CloudKit schema".
IOS_DATA_MODEL_GLOBS=("*/Models/*" "*.xcdatamodeld/*")

# --- Android -----------------------------------------------------------------------

# Folder that holds settings.gradle(.kts) and gradlew ("." at the repo root).
ANDROID_PROJECT_DIR="android"

# Command run inside ANDROID_PROJECT_DIR of every fresh worktree before a build.
ANDROID_SETUP_CMD=""

# The application module as Gradle names it, and the variant jobs build
# ("debug", or with flavors e.g. "devDebug"). /play builds the matching release.
APP_MODULE=":app"
VARIANT="debug"

# The release applicationId (what Play knows the app as).
APPLICATION_ID="com.example.myapp"

# Gitignored files the Android build needs, e.g. (local.properties).
ANDROID_COPY_INTO_WORKTREE=()

# An existing AVD; each job boots its own read-only, headless copy. "" = the first one.
AVD_NAME=""

# Runtime permissions granted after install, e.g. "ACCESS_FINE_LOCATION POST_NOTIFICATIONS".
PERMISSION_GRANTS=""

# Emulated location "lat,lon", or "".
EMU_LOCATION=""

# Android-only screens, raw intent extras allowed ("name|--es factoryScreen x").
ANDROID_SCREENS=()

# Font scale for the large-text variant. 2.0 is the largest system setting.
LARGE_TEXT_SCALE="2.0"

# Optional: a UI-test class whose tests call FactoryShots.save("name").
ANDROID_UI_TEST_SCREENS=""

# Android Lint task run in every check round ("" to skip). Errors fail the round.
LINT_TASK=":app:lintDebug"

# Google Play track and the script that builds the signed bundle and uploads
# it; run with ANDROID_PROJECT_DIR as its working directory. Must honour
# VERSION_CODE. The bundled one does.
PLAY_TRACK="internal"
PLAY_CMD="factory/scripts/play.sh"
# Changed files that mean "check the database migration".
ANDROID_DATA_MODEL_GLOBS=("*/schemas/*" "*/data/*")

# --- Docs ----------------------------------------------------------------------------

# The project wiki (one for both platforms). The documenter may only touch DOC_PATHS.
WIKI_DIR="docs/wiki"
DOC_PATHS=("$WIKI_DIR" "README.md")
