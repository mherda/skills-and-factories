#!/usr/bin/env bash
# Run a job's per-platform steps across the platforms it touches. The
# orchestrator uses this; agents call xc.sh (iOS) and droid.sh (Android)
# directly for one platform.
#
#   platforms.sh list <job>            the platforms the job's checks cover, and why
#   platforms.sh setup <job>           setup for every configured platform
#   platforms.sh check <job> <round>   each covered platform's check, one after the
#                                      other, merged into round-<N>/checks.md
#   platforms.sh cleanup <job>         stop the job's simulator and emulator
#
# A job covers the platforms its spec names (job.json "platforms") plus every
# platform whose paths its branch changed (IOS_PATHS, ANDROID_PATHS); a change
# under SHARED_PATHS covers them all. "main" covers every platform.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../config.sh
source "$REPO/factory/config.sh"
S="$REPO/factory/scripts"
JOBSTATE=(python3 -I "$S/jobstate.py")

script_for() { case $1 in ios) echo "$S/xc.sh" ;; android) echo "$S/droid.sh" ;; *) echo "✗ unknown platform $1" >&2; return 1 ;; esac; }
label() { case $1 in ios) echo iOS ;; android) echo Android ;; *) echo "$1" ;; esac; }

covered() { # covered <job>: "platform<TAB>reason" lines, in PLATFORMS order
  local job=$1 declared="null" wt="$REPO" changed=""
  if [[ $job != main ]]; then
    declared="$("${JOBSTATE[@]}" get "$job" platforms 2>/dev/null || echo null)"
    wt="$("${JOBSTATE[@]}" get "$job" worktree)"
    changed="$(git -C "$wt" diff --name-only main...HEAD 2>/dev/null || true)"
  fi
  python3 -I - "$job" "$declared" "$changed" <<PY
import fnmatch, json, sys
job, declared, changed = sys.argv[1], sys.argv[2], sys.argv[3].split()
platforms = "${PLATFORMS[*]}".split()
paths = {"ios": "${IOS_PATHS[*]+${IOS_PATHS[*]}}".split(), "android": "${ANDROID_PATHS[*]+${ANDROID_PATHS[*]}}".split()}
shared = "${SHARED_PATHS[*]+${SHARED_PATHS[*]}}".split()
hit = lambda path, globs: any(fnmatch.fnmatch(path, g) for g in globs)
why = {}
if job == "main":
    why = {p: "main checkout" for p in platforms}
try:
    for p in json.loads(declared) or []:
        why.setdefault(p, "spec")
except json.JSONDecodeError:
    pass
shared_hits = [c for c in changed if hit(c, shared)]
for p in platforms:
    mine = [c for c in changed if hit(c, paths.get(p, []))]
    if mine:
        why.setdefault(p, f"changes {mine[0]}" + (f" (+{len(mine) - 1})" if len(mine) > 1 else ""))
    elif shared_hits:
        why.setdefault(p, f"shared code changed ({shared_hits[0]})")
if not why:  # nothing declared or matched yet (e.g. a docs-only branch): check everything
    why = {p: "no platform-specific changes; checking all" for p in platforms}
for p in platforms:
    if p in why:
        print(f"{p}\t{why[p]}")
PY
}

cmd_check() {
  local job=$1 round=$2
  local out; out="$REPO/factory/jobs/$job/round-$round"
  mkdir -p "$out"
  rm -rf "$out/shots"
  local plats=() whys=() p reason i verdict=PASS
  while IFS=$'\t' read -r p reason; do plats+=("$p"); whys+=("$reason"); done < <(covered "$job")
  for p in "${plats[@]}"; do
    # One platform at a time: in a shared Gradle project both builds would fight over its locks.
    "$(script_for "$p")" check "$job" "$round" </dev/null >/dev/null 2>&1 || verdict=FAIL
    if [[ ! -f $out/$p/checks.md ]]; then
      mkdir -p "$out/$p"
      printf 'CHECKS: FAIL\n\n%s check crashed before writing its report.\n' "$(label "$p")" >"$out/$p/checks.md"
      verdict=FAIL
    fi
  done
  local wt="$REPO"
  if [[ $job != main ]]; then wt="$("${JOBSTATE[@]}" get "$job" worktree)"; fi
  {
    echo "CHECKS: $verdict"
    echo
    echo "# Checks: round $round"
    echo
    echo "Platforms checked:"
    for i in "${!plats[@]}"; do
      echo "- $(label "${plats[$i]}"): $(head -1 "$out/${plats[$i]}/checks.md" | sed 's/CHECKS: //') (${whys[$i]})"
    done
    for p in "${plats[@]}"; do
      echo
      echo "## $(label "$p")"
      echo
      tail -n +3 "$out/$p/checks.md"
    done
    echo
    echo "## Sensitive paths changed on this branch"
    python3 -I "$S/sensitive_paths.py" "$wt" "${IOS_DATA_MODEL_GLOBS[@]+"${IOS_DATA_MODEL_GLOBS[@]}"}" "${ANDROID_DATA_MODEL_GLOBS[@]+"${ANDROID_DATA_MODEL_GLOBS[@]}"}"
  } >"$out/checks.md"
  head -1 "$out/checks.md"
  [[ $verdict == PASS ]]
}

cmd=${1:-}; shift || true
case $cmd in
  list) covered "$1" ;;
  setup) for p in "${PLATFORMS[@]}"; do "$(script_for "$p")" setup "$1" </dev/null; done ;;
  check) cmd_check "$@" ;;
  cleanup) for p in "${PLATFORMS[@]}"; do "$(script_for "$p")" cleanup "$1" || true; done ;;
  *) sed -n '2,15p' "$0"; exit 64 ;;
esac
