# iOS factory configuration. Sourced by factory/scripts/*.sh.
# Every path is relative to the repo root unless it says otherwise.
# Edit this once when you install the factory; agents never edit it.

# --- Project -----------------------------------------------------------------

# Folder that holds the .xcodeproj / .xcworkspace (and project.yml if you use
# XcodeGen). "." when it sits at the repo root.
PROJECT_DIR="."

# Command run inside PROJECT_DIR of every fresh worktree before the first build.
# XcodeGen: "xcodegen generate". Tuist: "tuist generate --no-open". Plain
# committed .xcodeproj: "" (nothing to do).
SETUP_CMD=""

# How xcodebuild finds the project, relative to PROJECT_DIR.
XCODE_CONTAINER=(-project MyApp.xcodeproj)       # or (-workspace MyApp.xcworkspace)
SCHEME="MyApp"
BUNDLE_ID="com.example.MyApp"

# Gitignored files the build needs that a fresh worktree won't have, e.g.
# (Config/Secrets.xcconfig MyApp/GoogleService-Info.plist). Copied from the main
# checkout into each new worktree.
COPY_INTO_WORKTREE=()

# --- Simulator -----------------------------------------------------------------

# Each job gets its own simulator, created from this device type on the newest
# installed runtime, so parallel jobs never share a device.
SIM_DEVICE_TYPE="iPhone 17 Pro"

# Permissions granted after install so screenshots don't stop at a system alert.
# Names from `xcrun simctl privacy`: motion, photos, contacts, calendar,
# microphone, ... Location grants are accepted but NOT honoured on current
# simulators, so add a DEBUG launch argument that skips the location prompt
# (see README, Screens) and include it in SCREENS.
SIM_PRIVACY_GRANTS=""

# Simulated location "lat,lon", or "" to leave it alone.
SIM_LOCATION=""

# --- Screenshots -----------------------------------------------------------------

# Screens captured for every review round, one per entry: "name|how".
#   "how" empty          → just launch the app
#   "how" = "url:<url>"  → launch, then open a deep link
#   anything else        → passed to the app as launch arguments,
#                          e.g. "-factoryScreen settings" (see README, Screens)
# A job can add its own in <job folder>/screens.txt, same format, one per line.
SCREENS=("launch|")

# Seconds to wait after launch / deep link before taking the screenshot.
SCREEN_WAIT=4

# Variants of every screen: light, dark, large-text (accessibility-large).
SCREEN_VARIANTS=(light dark large-text)

# Optional: a UI-test class whose tests attach screenshots
# (XCTAttachment, lifetime .keepAlways), e.g. "MyAppUITests/FactoryScreens".
# When set, it runs in each variant and its attachments are exported too.
UI_TEST_SCREENS=""

# --- Docs ------------------------------------------------------------------------

# The project wiki: developer knowledge split into architecture, feature,
# module and guide pages (see factory/templates/wiki/). /factory-init creates
# it. The documenter keeps it in step with every merge and may only touch
# DOC_PATHS (files or folders).
WIKI_DIR="docs/wiki"
DOC_PATHS=("$WIKI_DIR" "README.md")

# --- Release ---------------------------------------------------------------------

TEAM_ID=""                                # Apple Developer team id
# Script (relative to the repo root, run with PROJECT_DIR as its working
# directory) that archives and uploads to TestFlight. It must honour the
# BUILD_NUMBER environment variable. The bundled one does.
TESTFLIGHT_CMD="factory/scripts/testflight.sh"
# Files whose change means "check CloudKit / data migration before shipping".
# Globs, matched against changed paths.
DATA_MODEL_GLOBS=("*/Models/*" "*.xcdatamodeld/*")
