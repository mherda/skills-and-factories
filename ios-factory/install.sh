#!/usr/bin/env bash
# Install the iOS factory into an app repo, or update an installed one.
#
#   ./install.sh <app repo>            first install: copies everything, never overwrites
#   ./install.sh --update <app repo>   refresh factory-owned files (agents, skills,
#                                      scripts, hooks, dashboard, templates); never touches
#                                      the project's own config, trackers or product brief
#
# Both modes also link the wiki git hooks (factory/hooks/) into the repo, unless
# it already has its own pre-commit/post-commit hooks. Re-run on each clone,
# because git hooks aren't versioned.
#
# Then open Claude Code in the app repo and run /factory-init (first install).
set -euo pipefail

UPDATE=0
if [[ ${1:-} == --update ]]; then UPDATE=1; shift; fi
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:?Usage: install.sh [--update] <path to app repo>}"
DEST="$(cd "$DEST" && pwd)"
git -C "$DEST" rev-parse --show-toplevel >/dev/null

# Files the factory owns. Everything else under factory/ belongs to the project.
owned() {
  case $1 in
    .claude/agents/*|.claude/skills/*|factory/scripts/*|factory/hooks/*|factory/templates/*|factory/dashboard.html|factory/issues/_TEMPLATE.md) return 0 ;;
    *) return 1 ;;
  esac
}

new=0 updated=0 same=0 skipped=0
while IFS= read -r -d '' f; do
  rel="${f#"$SRC"/}"
  dest="$DEST/$rel"
  if [[ ! -e $dest ]]; then
    mkdir -p "$(dirname "$dest")"; cp -p "$f" "$dest"; new=$((new + 1))
    [[ $UPDATE == 1 ]] && echo "  + $rel"
  elif cmp -s "$f" "$dest"; then
    same=$((same + 1))
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
  echo "  Next: commit them, open Claude Code in $DEST, and run /factory-init."
fi
