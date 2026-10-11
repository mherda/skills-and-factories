# Android factory configuration. Sourced by factory/scripts/*.sh.
# Every path is relative to the repo root unless it says otherwise.
# Edit this once when you install the factory; agents never edit it.

# --- Project -----------------------------------------------------------------

# Folder that holds settings.gradle(.kts) and gradlew. "." when it sits at the
# repo root.
PROJECT_DIR="."

# Command run inside PROJECT_DIR of every fresh worktree before the first build,
# e.g. a code generator. Usually "" (Gradle needs nothing extra).
SETUP_CMD=""

# The application module, as Gradle names it.
APP_MODULE=":app"

# The build variant jobs build, test and screenshot: "debug", or with product
# flavors e.g. "devDebug". /play builds the matching release variant.
VARIANT="debug"

# The release applicationId (what Play knows the app as). The installed debug
# package, which may carry an applicationIdSuffix, is read from the built APK.
APPLICATION_ID="com.example.myapp"

# Gitignored files the build needs that a fresh worktree won't have, e.g.
# (local.properties app/google-services.json secrets.properties). Copied from
# the main checkout into each new worktree.
COPY_INTO_WORKTREE=()

# --- Emulator ------------------------------------------------------------------

# An existing AVD (`emulator -list-avds`; create one in Android Studio's Device
# Manager). Each job boots its own read-only, headless copy of it on its own
# port, so parallel jobs never share a device and the AVD itself never changes.
# "" picks the first AVD.
AVD_NAME=""

# Runtime permissions granted after install (`pm grant`), so screenshots don't
# stop at a system dialog. Short names get the android.permission. prefix:
# e.g. "ACCESS_FINE_LOCATION POST_NOTIFICATIONS CAMERA".
PERMISSION_GRANTS=""

# Emulated location "lat,lon", or "" to leave it alone.
EMU_LOCATION=""

# --- Screenshots -----------------------------------------------------------------

# Screens captured for every review round, one per entry: "name|how".
#   "how" empty          → just launch the app
#   "how" = "url:<url>"  → launch, then open a deep link
#   anything else        → `am start` intent extras, e.g.
#                          "--es factoryScreen settings --ez factoryNoPrompts true"
#                          (see README, Screens)
# A job can add its own in <job folder>/screens.txt, same format, one per line.
SCREENS=("launch|")

# Seconds to wait after launch / deep link before taking the screenshot.
SCREEN_WAIT=3

# Variants of every screen: light, dark, large-text (font scale below).
SCREEN_VARIANTS=(light dark large-text)

# Font scale for the large-text variant. 2.0 is the largest system setting.
LARGE_TEXT_SCALE="2.0"

# Optional: a UI-test class whose tests save screenshots with
# FactoryShots.save("name") (TestStorage), e.g. "com.example.myapp.FactoryScreens".
# When set, it runs in each variant and its PNGs are copied in too.
UI_TEST_SCREENS=""

# Android Lint task run in every check round ("" to skip). Lint errors fail
# the round, the same as a failing test.
LINT_TASK=":app:lintDebug"

# --- Docs ------------------------------------------------------------------------

# The project wiki: developer knowledge split into architecture, feature,
# module and guide pages (see factory/templates/wiki/). /factory-init creates
# it. The documenter keeps it in step with every merge and may only touch
# DOC_PATHS (files or folders).
WIKI_DIR="docs/wiki"
DOC_PATHS=("$WIKI_DIR" "README.md")

# --- Release ---------------------------------------------------------------------

# Google Play track /play uploads to.
PLAY_TRACK="internal"
# Script (relative to the repo root, run with PROJECT_DIR as its working
# directory) that builds the signed release bundle and uploads it. It must
# honour the VERSION_CODE environment variable. The bundled one does.
PLAY_CMD="factory/scripts/play.sh"
# Files whose change means "check the database migration before shipping".
# Globs, matched against changed paths (Room's exported schemas, entities).
DATA_MODEL_GLOBS=("*/schemas/*" "*/data/*")
