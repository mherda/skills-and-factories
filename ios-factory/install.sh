#!/usr/bin/env bash
# Install the iOS factory into an app repo, or update an installed one.
#
#   ./install.sh <app repo>            first install: copies everything, never overwrites.
#                                      A new or empty folder works too: it's created and
#                                      git-initialised, ready for /factory-new.
#   ./install.sh --update <app repo>   refresh factory-owned files (agents, skills,
#                                      scripts, hooks, dashboard, templates); never touches
#                                      the project's own config, trackers or product brief
#
# Both modes also link the wiki git hooks (factory/hooks/) into the repo, unless
# it already has its own pre-commit/post-commit hooks. Re-run on each clone,
# because git hooks aren't versioned.
#
# Then open Claude Code in the app repo and run /factory-init (existing app) or
# /factory-new (new app, from an idea).
set -euo pipefail

UPDATE=0
if [[ ${1:-} == --update ]]; then UPDATE=1; shift; fi
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:?Usage: install.sh [--update] <path to app repo>}"
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"
FRESH=0
if ! git -C "$DEST" rev-parse --show-toplevel >/dev/null 2>&1; then
  [[ $UPDATE == 1 ]] && { echo "✗ $DEST is not a git repo. Install first (without --update)." >&2; exit 1; }
  git -C "$DEST" init -q -b main && FRESH=1 && echo "  ✱ git init $DEST (branch main)"
fi

# Files the factory owns. Everything else under factory/ belongs to the project.
owned() {
  case $1 in
    .claude/agents/*|.claude/skills/*|factory/scripts/*|factory/hooks/*|factory/templates/*|factory/dashboard.html|factory/issues/_TEMPLATE.md) return 0 ;;
    *) return 1 ;;
  esac
}

# Unported fixes (factory/UPSTREAM.md): with --update, keep the app's copy of
# those files rather than overwrite the fix; tick entries the factory now has.
declare -a HELD=()
has_fix() { # has_fix <commit> <file>: does the factory's copy already have that commit's change?
  # Ported when every code line the commit added is in the factory's file
  # (comments may be reworded when porting). Unknown commit: files must match.
  local commit=$1 f=$2
  cmp -s "$SRC/$f" "$DEST/$f" && return 0
  git -C "$DEST" rev-parse -q --verify "$commit^{commit}" >/dev/null 2>&1 || return 1
  git -C "$DEST" diff "$commit^" "$commit" -- "$f" | python3 -I -c '
import sys
have = {l.strip() for l in open(sys.argv[1], encoding="utf-8", errors="replace")}
added = [l[1:].strip() for l in sys.stdin if l.startswith("+") and not l.startswith("+++")]
code = [l for l in added if len(l) > 3 and not l.startswith(("#", "//", "<!--"))]  # skip fi, }, ;; ...
sys.exit(0 if code and all(l in have for l in code) else 1)' "$SRC/$f"
}
UP="$DEST/factory/UPSTREAM.md"
if [[ $UPDATE == 1 && -f $UP ]]; then
  ENTRIES=() TICK=()
  while IFS= read -r line; do ENTRIES+=("$line"); done < <(grep -E '^- \[ \] ' "$UP" || true)
  for line in "${ENTRIES[@]+"${ENTRIES[@]}"}"; do
    commit="$(sed -E 's/^- \[ \] [^·]*· *([^ ·]*) *·.*/\1/' <<<"$line")"
    files="$(sed -E 's/^- \[ \] [^·]*· [^·]*· ([^·]*) ·.*/\1/' <<<"$line" | tr ',' ' ')"
    ported=1
    for f in $files; do has_fix "$commit" "$f" || ported=0; done
    if [[ $ported == 1 ]]; then
      TICK+=("$line"); echo "  ✓ ported upstream: ${line#- \[ \] }"
    else
      for f in $files; do HELD+=("$f"); done
      echo "  ⚠ not yet in ios-factory: ${line#- \[ \] }"
      for f in $files; do echo "      diff -u \"$SRC/$f\" \"$DEST/$f\""; done
    fi
  done
  if ((${#TICK[@]})); then
    python3 -I -c '
import sys
p, done = sys.argv[1], sys.argv[2:]
lines = open(p, encoding="utf-8").read().split("\n")
lines = ["- [x]" + l[5:] if l in done else l for l in lines]
open(p, "w", encoding="utf-8").write("\n".join(lines))' "$UP" "${TICK[@]}"
  fi
fi
held() { local h; for h in "${HELD[@]+"${HELD[@]}"}"; do [[ $h == "$1" ]] && return 0; done; return 1; }

new=0 updated=0 same=0 skipped=0
while IFS= read -r -d '' f; do
  rel="${f#"$SRC"/}"
  dest="$DEST/$rel"
  if [[ ! -e $dest ]]; then
    mkdir -p "$(dirname "$dest")"; cp -p "$f" "$dest"; new=$((new + 1))
    [[ $UPDATE == 1 ]] && echo "  + $rel"
  elif cmp -s "$f" "$dest"; then
    same=$((same + 1))
  elif [[ $UPDATE == 1 ]] && held "$rel"; then
    skipped=$((skipped + 1)); echo "  ⏸ $rel kept (unported fix, see factory/UPSTREAM.md)"
  elif [[ $UPDATE == 1 ]] && owned "$rel"; then
    cp -p "$f" "$dest"; updated=$((updated + 1)); echo "  ↻ $rel"
  else
    skipped=$((skipped + 1))
    [[ $UPDATE == 0 ]] && echo "  skip (exists) $rel"
  fi
done < <(find "$SRC/.claude" "$SRC/factory" -type f ! -name .DS_Store ! -path "*/__pycache__/*" -print0)

touch "$DEST/.gitignore"
for line in "/factory/jobs/" "/build/"; do
  grep -qxF "$line" "$DEST/.gitignore" || echo "$line" >>"$DEST/.gitignore"
done

# Git hooks: symlinks into factory/hooks/, so --update keeps them current.
if [[ -n "$(git -C "$DEST" config core.hooksPath)" ]]; then
  echo "  ⚠ core.hooksPath is set; add factory/hooks/pre-commit and post-commit to your hooks yourself."
else
  HOOKS="$(cd "$DEST" && cd "$(git rev-parse --git-common-dir)" && pwd)/hooks"
  mkdir -p "$HOOKS"
  for h in pre-commit post-commit; do
    target="$DEST/factory/hooks/$h"
    if [[ -L "$HOOKS/$h" && "$(readlink "$HOOKS/$h")" == "$target" ]]; then :
    elif [[ -e "$HOOKS/$h" ]]; then
      echo "  ⚠ $h hook already exists. Call factory/hooks/$h from it to get wiki checks."
    else
      ln -s "$target" "$HOOKS/$h" && echo "  ⚓ linked git $h hook (wiki checks)"
    fi
  done
fi

if [[ $UPDATE == 1 ]]; then
  echo "✓ Updated $DEST: $updated refreshed, $new new, $same unchanged, $skipped project-owned left alone."
  echo "  Review with: git -C \"$DEST\" diff --stat   then commit."
else
  echo "✓ Copied $new files into $DEST ($skipped already there, left untouched)."
  if [[ $FRESH == 1 || -z "$(git -C "$DEST" ls-files | grep -v -e '^factory/' -e '^\.claude/' -e '^\.gitignore$' | head -1)" ]]; then
    echo "  New app? Put your idea in $DEST/IDEA.md (or just describe it), open Claude Code"
    echo "  there and run /factory-new. It commits the factory files for you."
  else
    echo "  Next: commit them, open Claude Code in $DEST, and run /factory-init."
  fi
fi
