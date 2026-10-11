#!/usr/bin/env bash
# Build, test, run and screenshot one factory job's worktree on its own
# emulator. Agents and the orchestrator use this instead of raw ./gradlew and
# adb so parallel jobs never share a device.
#
#   droid.sh setup <job>                 copy gitignored files in, run SETUP_CMD
#   droid.sh build <job>                 compile app + unit and UI tests (fast check while coding)
#   droid.sh test  <job> <out-dir> [gradle tasks and args]
#                                        run tests → <out-dir>/junit/ + test-summary.md
#   droid.sh run   <job> [am start extras]  install and launch the app on the job's emulator
#   droid.sh url   <job> <deep link>     open a deep link in the app
#   droid.sh screenshot <job> <file.png> screenshot the job's emulator
#   droid.sh shots <job> <out-dir>       capture every configured screen × variant
#   droid.sh check <job> <round>         setup + test + lint + shots → round-<N>/android/checks.md
#                                        (platforms.sh check merges it into round-<N>/checks.md)
#   droid.sh smoke <job> <out-dir>       release build (R8) → install → launch → crash check
#   droid.sh emu   <job>                 print the job's emulator serial (starting it)
#   droid.sh cleanup <job>               stop the job's emulator and forget its port
#
# <job> is a job id, or "main" for the main checkout (used by /play).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../config.sh
source "$REPO/factory/config.sh"
# The mobile factory's config holds both platforms: map the Android settings
# onto the names the rest of this script (shared with android-factory) uses.
PROJECT_DIR="$ANDROID_PROJECT_DIR"
SETUP_CMD="$ANDROID_SETUP_CMD"
COPY_INTO_WORKTREE=("${ANDROID_COPY_INTO_WORKTREE[@]+"${ANDROID_COPY_INTO_WORKTREE[@]}"}")
UI_TEST_SCREENS="$ANDROID_UI_TEST_SCREENS"
PLATFORM=android
SCREENS=("${SCREENS[@]+"${SCREENS[@]}"}" "${ANDROID_SCREENS[@]+"${ANDROID_SCREENS[@]}"}")
JOBSTATE=(python3 -I "$REPO/factory/scripts/jobstate.py")
NAME="$(basename "$REPO")"

export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
ADB="$ANDROID_HOME/platform-tools/adb"
EMULATOR="$ANDROID_HOME/emulator/emulator"
# Per-machine state outside every repo: port claims and emulator logs.
STATE="$HOME/.android-factory"   # shared with android-factory, so ports never clash
FIRST_PORT=5580 LAST_PORT=5680   # emulator ports are even; leaves 5554-5578 for your own emulators

camel() { echo "$(tr '[:lower:]' '[:upper:]' <<<"${1:0:1}")${1:1}"; }   # devDebug → DevDebug
V="$(camel "$VARIANT")"
RV="${V%Debug}Release"                                                     # DevDebug → DevRelease
apk_dir_of() { python3 -I -c 'import re,sys; print("/".join(p.lower() for p in re.findall(r"[A-Z]?[a-z0-9]+", sys.argv[1])))' "$1"; }

worktree() { if [[ $1 == main ]]; then echo "$REPO"; else "${JOBSTATE[@]}" get "$1" worktree; fi; }
job_dir() { echo "$REPO/factory/jobs/$1"; }
state_dir() { echo "$STATE/$NAME/$1"; }
project_dir() { echo "$(worktree "$1")/$PROJECT_DIR"; }
module_dir() { local m="${APP_MODULE#:}"; echo "$(project_dir "$1")/${m//://}"; }

gradle() { # gradle <job> <log file> <gradle args...>
  local job=$1 log=$2; shift 2
  (cd "$(project_dir "$job")" && ./gradlew --console=plain "$@") >"$log" 2>&1
}

show_failure() { # print what matters from a failed Gradle log
  echo "✗ Gradle failed. Full log: $1" >&2
  grep -E "^e: |error:|What went wrong" -A3 "$1" | head -40 >&2 || true
  tail -15 "$1" >&2
}

# --- Emulator --------------------------------------------------------------------

online() { [[ "$("$ADB" -s "$1" get-state 2>/dev/null)" == device ]]; }
sh_() { local s=$1; shift; "$ADB" -s "$s" shell "$@" </dev/null; }

claim_port() { # claim_port <job>: an even port no other job or emulator uses
  mkdir -p "$STATE/ports"
  local p
  for ((p = FIRST_PORT; p <= LAST_PORT; p += 2)); do
    "$ADB" devices | grep -qE "^emulator-$p[[:space:]]" && continue   # someone's own emulator
    if mkdir "$STATE/ports/$p" 2>/dev/null; then                    # atomic: two jobs can't both win
      echo "$NAME/$1" >"$STATE/ports/$p/owner"; echo "$p"; return
    fi
  done
  echo "✗ No free emulator port in $FIRST_PORT-$LAST_PORT. Clean up old jobs: droid.sh cleanup <job>." >&2
  return 1
}

avd() {
  if [[ -n $AVD_NAME ]]; then echo "$AVD_NAME"; return; fi
  local first; first="$("$EMULATOR" -list-avds 2>/dev/null | grep -v '^INFO' | head -1)"
  [[ -n $first ]] || { echo "✗ No AVD found. Create one in Android Studio (Device Manager), or set AVD_NAME." >&2; return 1; }
  echo "$first"
}

demo() { sh_ "$1" am broadcast -a com.android.systemui.demo -e command "${@:2}" >/dev/null; }

prepare() { # prepare <serial>: settings that keep tests and screenshots repeatable
  local s=$1
  for k in window_animation_scale transition_animation_scale animator_duration_scale; do sh_ "$s" settings put global "$k" 0; done
  sh_ "$s" svc power stayon true || true
  sh_ "$s" wm dismiss-keyguard || true
  status_bar "$s"
  if [[ -n $EMU_LOCATION ]]; then "$ADB" -s "$s" emu geo fix "${EMU_LOCATION#*,}" "${EMU_LOCATION%,*}" >/dev/null || true; fi
}

status_bar() { # status_bar <serial>: demo mode, so screenshots compare between rounds
  # SystemUI can miss this right after boot, so cmd_shots applies it again.
  local s=$1
  sh_ "$s" settings put global sysui_demo_allowed 1
  demo "$s" enter
  demo "$s" clock -e hhmm 1200
  demo "$s" battery -e level 100 -e plugged false
  demo "$s" network -e wifi show -e level 4 -e fully true
  demo "$s" network -e mobile show -e datatype none -e level 4
  demo "$s" notifications -e visible false
}

lock_starts() { # one emulator start at a time: simultaneous first boots of an AVD corrupt its images
  local waited=0
  until mkdir "$STATE/start.lock" 2>/dev/null; do
    # A lock older than 5 minutes belongs to a start that died.
    if [[ -n "$(find "$STATE/start.lock" -maxdepth 0 -mmin +5 2>/dev/null)" ]]; then rmdir "$STATE/start.lock" 2>/dev/null || true; fi
    sleep 2; ((waited += 2)); ((waited < 600)) || { echo "✗ Waited 10 minutes for another emulator to start." >&2; return 1; }
  done
}

ensure_emu() { # ensure_emu <job>: print the serial of the job's booted emulator, starting it if needed
  local job=$1 serial port sd
  if [[ -n ${FACTORY_ANDROID_SERIAL:-} ]]; then
    # Escape hatch: pin every job to one running device (no parallel isolation).
    online "$FACTORY_ANDROID_SERIAL" || { echo "✗ FACTORY_ANDROID_SERIAL=$FACTORY_ANDROID_SERIAL is not online." >&2; return 1; }
    echo "$FACTORY_ANDROID_SERIAL"; return
  fi
  sd="$(state_dir "$job")"; mkdir -p "$sd"
  if [[ -f $sd/port ]]; then
    port="$(cat "$sd/port")"; serial="emulator-$port"
    if online "$serial" && [[ "$(sh_ "$serial" getprop sys.boot_completed | tr -d '\r')" == 1 ]]; then echo "$serial"; return; fi
  else
    port="$(claim_port "$job")" || return 1
    echo "$port" >"$sd/port"; serial="emulator-$port"
  fi
  local name; name="$(avd)" || return 1
  mkdir -p "$STATE"; lock_starts || return 1
  # -read-only lets several copies of one AVD run at once and never writes to it.
  nohup "$EMULATOR" -avd "$name" -read-only -no-snapshot -no-window -no-audio -no-boot-anim \
    -port "$port" >"$sd/emulator.log" 2>&1 </dev/null &
  local pid=$! waited=0
  echo "$pid" >"$sd/pid"
  until online "$serial"; do
    if ! kill -0 "$pid" 2>/dev/null || ((waited >= 180)); then
      rmdir "$STATE/start.lock" 2>/dev/null || true
      kill "$pid" 2>/dev/null || true
      echo "✗ Emulator $name on port $port didn't come up. Log: $sd/emulator.log" >&2
      grep -vE '^INFO' "$sd/emulator.log" | tail -5 >&2 || true
      return 1
    fi
    sleep 2; ((waited += 2))
  done
  rmdir "$STATE/start.lock" 2>/dev/null || true
  waited=0
  until [[ "$(sh_ "$serial" getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]]; do
    ((waited < 300)) || { echo "✗ $serial didn't finish booting in 5 minutes. Log: $sd/emulator.log" >&2; return 1; }
    sleep 3; ((waited += 3))
  done
  prepare "$serial" >/dev/null 2>&1 || true
  echo "$serial"
}

# --- App ---------------------------------------------------------------------------

apk_path() { # apk_path <job> <Variant>
  local f
  for f in "$(module_dir "$1")/build/outputs/apk/$(apk_dir_of "$2")"/*.apk; do
    [[ -f $f ]] && { echo "$f"; return; }
  done
  echo "✗ No $2 APK built. Run droid.sh build first." >&2
  return 1
}

aapt2() { local a; a="$(ls -d "$ANDROID_HOME"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1)"; echo "${a:-aapt2}"; }
PKG="" APK=""
resolve_apk() { # resolve_apk <job> [Variant]: sets APK and PKG (the package it installs as)
  APK="$(apk_path "$1" "${2:-$V}")" || return 1
  PKG="$("$(aapt2)" dump packagename "$APK" 2>/dev/null || echo "$APPLICATION_ID")"
}
install_app() { # install_app <job> <serial>: install the job's build, grant permissions
  resolve_apk "$1" || return 1
  "$ADB" -s "$2" install -r -t "$APK" >/dev/null
  local p
  for p in $PERMISSION_GRANTS; do
    [[ $p == *.* ]] || p="android.permission.$p"
    sh_ "$2" pm grant "$PKG" "$p" 2>/dev/null || echo "⚠ couldn't grant $p (is it in the manifest?)" >&2
  done
}

launch() { # launch <serial> [am start extras...]: cold start, so extras always apply
  local s=$1; shift
  local activity
  activity="$(sh_ "$s" cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$PKG" | tr -d '\r' | tail -1)"
  [[ $activity == */* ]] || { echo "✗ No launcher activity for $PKG" >&2; return 1; }
  sh_ "$s" am start -S -W -n "$activity" "$@" >/dev/null
}

open_url() { sh_ "$1" "am start -W -a android.intent.action.VIEW -d '$2' $PKG" >/dev/null; }

screencap() { "$ADB" -s "$1" exec-out screencap -p >"$2"; }

set_variant() { # set_variant <serial> light|dark|large-text
  case $2 in
    dark) sh_ "$1" cmd uimode night yes >/dev/null; sh_ "$1" settings put system font_scale 1.0 ;;
    large-text) sh_ "$1" cmd uimode night no >/dev/null; sh_ "$1" settings put system font_scale "$LARGE_TEXT_SCALE" ;;
    *) sh_ "$1" cmd uimode night no >/dev/null; sh_ "$1" settings put system font_scale 1.0 ;;
  esac
}

# --- Commands --------------------------------------------------------------------

cmd_setup() {
  local job=$1 wt; wt="$(worktree "$job")"
  local f
  for f in "${COPY_INTO_WORKTREE[@]+"${COPY_INTO_WORKTREE[@]}"}"; do
    if [[ -e "$REPO/$f" ]]; then mkdir -p "$(dirname "$wt/$f")"; cp -R "$REPO/$f" "$wt/$f"; fi
  done
  if [[ -n $SETUP_CMD ]]; then (cd "$wt/$PROJECT_DIR" && eval "$SETUP_CMD"); fi
}

cmd_build() {
  local job=$1 log; log="$(mktemp "${TMPDIR:-/tmp}/droid-build-$job.XXXXXX")" || return 1
  cmd_setup "$job" >/dev/null
  if gradle "$job" "$log" "$APP_MODULE:assemble$V" "$APP_MODULE:assemble${V}UnitTest" "$APP_MODULE:assemble${V}AndroidTest"; then
    echo "✓ build succeeded"; grep -E "^w: " "$log" | head -15 || true
  else
    show_failure "$log"; return 1
  fi
}

cmd_test() {
  local job=$1 out=$2; shift 2
  mkdir -p "$out" && out="$(cd "$out" && pwd)"
  local pd; pd="$(project_dir "$job")"
  local serial; serial="$(ensure_emu "$job")" || return 1
  # Stale results would be reported as this run's.
  find "$pd" -type d \( -path "*/build/test-results" -o -path "*/build/outputs/androidTest-results" \) -prune -exec rm -rf {} + 2>/dev/null || true
  rm -rf "$out/junit"; mkdir -p "$out/junit"
  local args=("$@")
  if [[ ${#args[@]} -eq 0 ]]; then
    # Every module's unit tests, then the UI tests on the job's emulator.
    args=("test${V}UnitTest" "connected${V}AndroidTest" --continue)
    if [[ -n $UI_TEST_SCREENS ]]; then args+=("-Pandroid.testInstrumentationRunnerArguments.notClass=$UI_TEST_SCREENS"); fi
  fi
  local status=0
  ANDROID_SERIAL="$serial" gradle "$job" "$out/gradle-test.log" "${args[@]}" || status=$?
  local f
  while IFS= read -r f; do
    cp "$f" "$out/junit/$(echo "${f#"$pd"/}" | tr '/' '_')"
  done < <(find "$pd" -name '*.xml' \( -path "*/build/test-results/*" -o -path "*/build/outputs/androidTest-results/*" \) 2>/dev/null)
  python3 -I "$REPO/factory/scripts/test_summary_android.py" "$out/junit" "$out/gradle-test.log" "$status" >"$out/test-summary.md"
  cat "$out/test-summary.md"
  return $status
}

cmd_shots() {
  local job=$1 out=$2
  mkdir -p "$out"
  local serial; serial="$(ensure_emu "$job")" || return 1
  local screens=("${SCREENS[@]}")
  local extra; extra="$(job_dir "$job")/screens.txt"
  if [[ -f $extra ]]; then
    while IFS= read -r line; do
      [[ -z $line || $line == \#* ]] && continue
      case $line in "$PLATFORM:"*) line="${line#"$PLATFORM:"}" ;; ios:* | android:*) continue ;; esac
      screens+=("$line")
    done <"$extra"
  fi
  status_bar "$serial" >/dev/null 2>&1 || true
  local variant entry name how
  for variant in "${SCREEN_VARIANTS[@]}"; do
    install_app "$job" "$serial"   # every round: the UI-test run below uninstalls the app
    set_variant "$serial" "$variant"
    for entry in "${screens[@]}"; do
      name="${entry%%|*}"; how="${entry#*|}"
      if [[ $how == url:* ]]; then
        launch "$serial"; sleep 2; open_url "$serial" "${how#url:}"
      elif [[ $how == screen:* ]]; then
        launch "$serial" --es factoryScreen "${how#screen:}" --ez factoryNoPrompts true
      else
        # shellcheck disable=SC2086  # intent extras are meant to split
        launch "$serial" $how
      fi
      sleep "$SCREEN_WAIT"
      screencap "$serial" "$out/$PLATFORM-$name-$variant.png"
    done
    if [[ -n $UI_TEST_SCREENS ]]; then
      local add; add="$(module_dir "$job")/build/outputs/connected_android_test_additional_output"
      rm -rf "$add"
      local ui="$out/ui-$PLATFORM-$variant"
      if ANDROID_SERIAL="$serial" gradle "$job" "$ui.log" "$APP_MODULE:connected${V}AndroidTest" \
        "-Pandroid.testInstrumentationRunnerArguments.class=$UI_TEST_SCREENS"; then :; else echo "⚠ UI screenshot tests failed in $variant (see $ui.log)" >&2; fi
      mkdir -p "$ui"
      find "$add" -name '*.png' -exec cp {} "$ui/" \; 2>/dev/null || true
    fi
  done
  set_variant "$serial" light
  ls "$out/$PLATFORM"-*.png "$out/ui-$PLATFORM"-*/* 2>/dev/null | sed "s|^$REPO/||" || true
}

cmd_smoke() { # the release build differs from debug (R8 shrinking): prove it starts
  local job=$1 out=$2
  mkdir -p "$out" && out="$(cd "$out" && pwd)"
  cmd_setup "$job" >/dev/null
  if ! gradle "$job" "$out/gradle-release.log" "$APP_MODULE:assemble$RV"; then show_failure "$out/gradle-release.log"; return 1; fi
  local serial; serial="$(ensure_emu "$job")" || return 1
  resolve_apk "$job" "$RV" || return 1
  sh_ "$serial" pm uninstall "$PKG" >/dev/null 2>&1 || true   # a differently signed copy blocks install
  "$ADB" -s "$serial" install -t "$APK" >/dev/null
  "$ADB" -s "$serial" logcat -b crash -c
  launch "$serial"
  sleep "$SCREEN_WAIT"; sleep 2
  screencap "$serial" "$out/release-launch.png"
  local crash; crash="$("$ADB" -s "$serial" logcat -b crash -d | grep -v '^---------' | head -30 || true)"
  local alive; alive="$(sh_ "$serial" pidof "$PKG" | tr -d '\r' || true)"
  sh_ "$serial" pm uninstall "$PKG" >/dev/null 2>&1 || true   # so the debug build installs again
  if [[ -z $crash && -n $alive ]]; then
    echo "✓ release build ($RV, R8) launched and kept running. Screenshot: $out/release-launch.png"
  else
    echo "✗ release build ($RV) crashed or exited on launch:"; echo "${crash:-(no crash log, but the process had exited)}"
    return 1
  fi
}

cmd_check() { # writes round-<N>/android/checks.md; platforms.sh merges the platforms
  local job=$1 round=$2
  local out; out="$(job_dir "$job")/round-$round/$PLATFORM"
  local shots; shots="$(job_dir "$job")/round-$round/shots"
  mkdir -p "$out"
  local verdict=PASS
  echo "### Setup" >"$out/checks.body.md"
  if cmd_setup "$job" >>"$out/checks.body.md" 2>&1; then echo "ok" >>"$out/checks.body.md"; else verdict=FAIL; echo "FAILED" >>"$out/checks.body.md"; fi
  echo >>"$out/checks.body.md"
  if [[ $verdict == PASS ]]; then
    if ! cmd_test "$job" "$out" >/dev/null 2>&1; then verdict=FAIL; fi
    if [[ -f $out/test-summary.md ]]; then sed 's/^## /### /' "$out/test-summary.md" >>"$out/checks.body.md"; else echo "### Build & tests"$'\n'"result: couldn't run (no emulator?)" >>"$out/checks.body.md"; fi
  fi
  if [[ $verdict == PASS && -n $LINT_TASK ]]; then
    local lint_status=0
    gradle "$job" "$out/lint.log" "$LINT_TASK" || lint_status=$?
    # shellcheck disable=SC2046  # one argument per report
    { echo; python3 -I "$REPO/factory/scripts/test_summary_android.py" --lint "$out/lint.log" "$lint_status" $(find "$(project_dir "$job")" -path '*/build/reports/lint-results-*.xml' 2>/dev/null) | sed 's/^## /### /'; } >>"$out/checks.body.md"
    ((lint_status == 0)) || verdict=FAIL
  fi
  {
    echo
    echo "### Screenshots"
    if [[ $verdict == PASS ]]; then
      if cmd_shots "$job" "$shots" 2>&1; then :; else echo "(screenshots failed; see output above)"; fi
    else
      echo "Skipped: the build, tests or lint failed."
    fi
  } >>"$out/checks.body.md"
  { echo "CHECKS: $verdict"; echo; cat "$out/checks.body.md"; } >"$out/checks.md"
  rm "$out/checks.body.md"
  head -1 "$out/checks.md"
  [[ $verdict == PASS ]]
}

cmd_cleanup() {
  local job=$1 sd; sd="$(state_dir "$job")"
  if [[ -f $sd/port ]]; then
    local port; port="$(cat "$sd/port")"
    "$ADB" -s "emulator-$port" emu kill >/dev/null 2>&1 || true
    if [[ -f $sd/pid ]]; then
      local pid; pid="$(cat "$sd/pid")" waited=0
      while kill -0 "$pid" 2>/dev/null && ((waited < 20)); do sleep 1; ((waited++)) || true; done
      kill "$pid" 2>/dev/null || true
    fi
    rm -rf "$STATE/ports/$port"
  fi
  rm -rf "$sd"
  echo "✓ stopped the emulator for $job (build output goes with the worktree)"
}

cmd=${1:-}; shift || true
case $cmd in
  setup) cmd_setup "$@" ;;
  build) cmd_build "$@" ;;
  test) cmd_test "$@" ;;
  run) job=$1; shift; serial="$(ensure_emu "$job")"; install_app "$job" "$serial"; launch "$serial" "$@"; echo "✓ launched $PKG on $serial" ;;
  url) serial="$(ensure_emu "$1")"; resolve_apk "$1"; open_url "$serial" "$2" ;;
  screenshot) screencap "$(ensure_emu "$1")" "$2" && echo "$2" ;;
  shots) cmd_shots "$@" ;;
  check) cmd_check "$@" ;;
  smoke) cmd_smoke "$@" ;;
  emu) ensure_emu "$1" ;;
  cleanup) cmd_cleanup "$@" ;;
  *) sed -n '2,20p' "$0"; exit 64 ;;
esac
