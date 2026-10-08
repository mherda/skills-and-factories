#!/usr/bin/env bash
# Build, test, run and screenshot one factory job's worktree on its own
# simulator. Agents and the orchestrator use this instead of raw xcodebuild so
# parallel jobs never share a simulator or a DerivedData folder.
#
#   xc.sh setup <job>                 copy gitignored files in, run SETUP_CMD
#   xc.sh build <job>                 compile app + tests (fast check while coding)
#   xc.sh test  <job> <out-dir> [xcodebuild -only-testing:... args]
#                                     run tests → <out-dir>/tests.xcresult + test-summary.md
#   xc.sh run   <job> [launch args]   install and launch the app on the job's simulator
#   xc.sh url   <job> <deep link>     open a deep link in the running app
#   xc.sh screenshot <job> <file.png> screenshot the job's simulator
#   xc.sh shots <job> <out-dir>       capture every configured screen × variant
#   xc.sh check <job> <round>         setup + test + shots → round-<N>/checks.md
#   xc.sh sim   <job>                 print the job's simulator UDID (creating/booting it)
#   xc.sh cleanup <job>               delete the job's simulator and DerivedData
#
# <job> is a job id, or "main" for the main checkout (used by /testflight).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../config.sh
source "$REPO/factory/config.sh"
JOBSTATE=(python3 -I "$REPO/factory/scripts/jobstate.py")
NAME="$(basename "$REPO")"

worktree() { if [[ $1 == main ]]; then echo "$REPO"; else "${JOBSTATE[@]}" get "$1" worktree; fi; }
job_dir() { echo "$REPO/factory/jobs/$1"; }
sim_name() { echo "factory-$NAME-$1"; }
derived_data() { echo "$HOME/Library/Developer/ios-factory/$NAME/$1"; }
project_dir() { echo "$(worktree "$1")/$PROJECT_DIR"; }

udid_of() {
  xcrun simctl list devices -j | python3 -I -c '
import json, sys
name = sys.argv[1]
for runtime in json.load(sys.stdin)["devices"].values():
    for d in runtime:
        if d["name"] == name and d.get("isAvailable", True):
            print(d["udid"]); sys.exit()
' "$(sim_name "$1")"
}

ensure_sim() {
  local udid
  if [[ -n ${FACTORY_SIM_UDID:-} ]]; then
    # Escape hatch: pin every job to one existing simulator (no parallel isolation).
    udid=$FACTORY_SIM_UDID
  else
    udid="$(udid_of "$1")"
  fi
  if [[ -z $udid ]]; then
    # simctl create can hang forever when CoreSimulatorService is wedged
    # (e.g. a device stuck "Shutting Down"), so give it a deadline.
    local tmp; tmp="$(mktemp)"
    xcrun simctl create "$(sim_name "$1")" "$SIM_DEVICE_TYPE" >"$tmp" 2>/dev/null &
    local pid=$! waited=0
    while kill -0 "$pid" 2>/dev/null && ((waited < 90)); do sleep 1; ((waited++)) || true; done
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      echo "✗ simctl create timed out. CoreSimulatorService is probably stuck: run" >&2
      echo "  killall -9 com.apple.CoreSimulator.CoreSimulatorService   (shuts down all simulators)" >&2
      echo "  or set FACTORY_SIM_UDID=<udid> to use one existing simulator." >&2
      rm -f "$tmp"; return 1
    fi
    udid="$(tail -1 "$tmp")"; rm -f "$tmp"
  fi
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryLevel 100 --cellularBars 4 2>/dev/null || true
  if [[ -n $SIM_LOCATION ]]; then xcrun simctl location "$udid" set "$SIM_LOCATION" 2>/dev/null || true; fi
  echo "$udid"
}

xcb() { # xcb <job> <log file> <xcodebuild args...>
  local job=$1 log=$2; shift 2
  local udid; udid="$(ensure_sim "$job")"
  (cd "$(project_dir "$job")" && xcodebuild "${XCODE_CONTAINER[@]}" -scheme "$SCHEME" \
    -destination "id=$udid" -derivedDataPath "$(derived_data "$job")" "$@") >"$log" 2>&1
}

show_failure() { # print what matters from a failed xcodebuild log
  echo "✗ xcodebuild failed. Full log: $1" >&2
  grep -E "error:|failed|FAILED|\*\* .* FAILED \*\*" "$1" | grep -v "^note:" | head -40 >&2 || true
  tail -15 "$1" >&2
}

app_path() {
  local app
  for app in "$(derived_data "$1")"/Build/Products/*-iphonesimulator/*.app; do
    if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist" 2>/dev/null)" == "$BUNDLE_ID" ]]; then
      echo "$app"; return
    fi
  done
  echo "✗ No built app with bundle id $BUNDLE_ID. Run xc.sh build or test first." >&2
  return 1
}

install_app() {
  local udid; udid="$(ensure_sim "$1")"
  xcrun simctl install "$udid" "$(app_path "$1")"
  local svc
  for svc in $SIM_PRIVACY_GRANTS; do xcrun simctl privacy "$udid" grant "$svc" "$BUNDLE_ID" || true; done
}

launch() { # launch <job> [args...]
  local job=$1; shift
  local udid; udid="$(ensure_sim "$job")"
  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$udid" "$BUNDLE_ID" "$@" >/dev/null
}

set_variant() { # set_variant <udid> light|dark|large-text
  case $2 in
    dark) xcrun simctl ui "$1" appearance dark; xcrun simctl ui "$1" content_size large ;;
    large-text) xcrun simctl ui "$1" appearance light; xcrun simctl ui "$1" content_size accessibility-large ;;
    *) xcrun simctl ui "$1" appearance light; xcrun simctl ui "$1" content_size large ;;
  esac
}

cmd_setup() {
  local job=$1 wt; wt="$(worktree "$job")"
  local f
  for f in "${COPY_INTO_WORKTREE[@]+"${COPY_INTO_WORKTREE[@]}"}"; do
    if [[ -e "$REPO/$f" ]]; then mkdir -p "$(dirname "$wt/$f")"; cp -R "$REPO/$f" "$wt/$f"; fi
  done
  if [[ -n $SETUP_CMD ]]; then (cd "$wt/$PROJECT_DIR" && eval "$SETUP_CMD"); fi
}

cmd_build() {
  local job=$1 log; log="$(mktemp -t "xc-build-$job").log"
  cmd_setup "$job" >/dev/null
  if xcb "$job" "$log" build-for-testing; then echo "✓ build succeeded"; else show_failure "$log"; return 1; fi
}

cmd_test() {
  local job=$1 out=$2; shift 2
  mkdir -p "$out"
  rm -rf "$out/tests.xcresult"
  local args=(test -resultBundlePath "$out/tests.xcresult")
  if [[ $# -eq 0 && -n $UI_TEST_SCREENS ]]; then args+=("-skip-testing:$UI_TEST_SCREENS"); fi
  local status=0
  xcb "$job" "$out/xcodebuild-test.log" "${args[@]}" "$@" || status=$?
  python3 -I "$REPO/factory/scripts/test_summary.py" "$out/tests.xcresult" "$out/xcodebuild-test.log" "$status" >"$out/test-summary.md"
  cat "$out/test-summary.md"
  return $status
}

cmd_shots() {
  local job=$1 out=$2
  mkdir -p "$out"
  install_app "$job"
  local udid; udid="$(ensure_sim "$job")"
  local screens=("${SCREENS[@]}")
  local extra; extra="$(job_dir "$job")/screens.txt"
  if [[ -f $extra ]]; then while IFS= read -r line; do [[ -n $line && $line != \#* ]] && screens+=("$line"); done <"$extra"; fi
  local variant entry name how
  for variant in "${SCREEN_VARIANTS[@]}"; do
    set_variant "$udid" "$variant"
    for entry in "${screens[@]}"; do
      name="${entry%%|*}"; how="${entry#*|}"
      if [[ $how == url:* ]]; then
        launch "$job"; sleep 2; xcrun simctl openurl "$udid" "${how#url:}"
      else
        # shellcheck disable=SC2086  # launch arguments are meant to split
        launch "$job" $how
      fi
      sleep "$SCREEN_WAIT"
      xcrun simctl io "$udid" screenshot "$out/$name-$variant.png" >/dev/null 2>&1
    done
    if [[ -n $UI_TEST_SCREENS ]]; then
      rm -rf "$out/ui-$variant.xcresult"
      if xcb "$job" "$out/ui-$variant.log" test-without-building "-only-testing:$UI_TEST_SCREENS" -resultBundlePath "$out/ui-$variant.xcresult"; then :; else echo "⚠ UI screenshot tests failed in $variant (see $out/ui-$variant.log)" >&2; fi
      xcrun xcresulttool export attachments --path "$out/ui-$variant.xcresult" --output-path "$out/ui-$variant" >/dev/null 2>&1 || true
      rm -rf "$out/ui-$variant.xcresult"
    fi
  done
  set_variant "$udid" light
  ls "$out"/*.png "$out"/ui-*/* 2>/dev/null | sed "s|^$REPO/||" || true
}

cmd_check() {
  local job=$1 round=$2
  local out; out="$(job_dir "$job")/round-$round"
  mkdir -p "$out"
  local wt; wt="$(worktree "$job")"
  local verdict=PASS
  {
    echo "# Checks: round $round"
    echo
    echo "## Setup"
  } >"$out/checks.body.md"
  if cmd_setup "$job" >>"$out/checks.body.md" 2>&1; then echo "ok" >>"$out/checks.body.md"; else verdict=FAIL; echo "FAILED" >>"$out/checks.body.md"; fi
  echo >>"$out/checks.body.md"
  if [[ $verdict == PASS ]]; then
    if ! cmd_test "$job" "$out" >/dev/null 2>&1; then verdict=FAIL; fi
    cat "$out/test-summary.md" >>"$out/checks.body.md"
  fi
  {
    echo
    echo "## Screenshots"
    if [[ $verdict == PASS ]]; then
      if cmd_shots "$job" "$out/shots" 2>&1; then :; else echo "(screenshots failed; see output above)"; fi
    else
      echo "Skipped: the build or tests failed."
    fi
    echo
    echo "## Sensitive paths changed on this branch"
    python3 -I "$REPO/factory/scripts/sensitive_paths.py" "$wt" "${DATA_MODEL_GLOBS[@]+"${DATA_MODEL_GLOBS[@]}"}"
  } >>"$out/checks.body.md"
  { echo "CHECKS: $verdict"; echo; cat "$out/checks.body.md"; } >"$out/checks.md"
  rm "$out/checks.body.md"
  head -1 "$out/checks.md"
  [[ $verdict == PASS ]]
}

cmd_cleanup() {
  local job=$1 udid; udid="$(udid_of "$job")"
  if [[ -n $udid ]]; then xcrun simctl shutdown "$udid" 2>/dev/null || true; xcrun simctl delete "$udid"; fi
  rm -rf "$(derived_data "$job")"
  echo "✓ removed simulator and DerivedData for $job"
}

cmd=${1:-}; shift || true
case $cmd in
  setup) cmd_setup "$@" ;;
  build) cmd_build "$@" ;;
  test) cmd_test "$@" ;;
  run) job=$1; shift; install_app "$job"; launch "$job" "$@"; echo "✓ launched on $(sim_name "$job")" ;;
  url) xcrun simctl openurl "$(ensure_sim "$1")" "$2" ;;
  screenshot) xcrun simctl io "$(ensure_sim "$1")" screenshot "$2" >/dev/null 2>&1 && echo "$2" ;;
  shots) cmd_shots "$@" ;;
  check) cmd_check "$@" ;;
  sim) ensure_sim "$1" ;;
  cleanup) cmd_cleanup "$@" ;;
  *) sed -n '2,20p' "$0"; exit 64 ;;
esac
