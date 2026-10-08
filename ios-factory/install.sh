#!/usr/bin/env bash
# Install the iOS factory into an app repo, or update an installed one.
#
#   ./install.sh <app repo>            first install: copies everything, never overwrites
#   ./install.sh --update <app repo>   refresh factory-owned files (agents, skills,
#                                      scripts, dashboard, templates); never touches the
#                                      project's own config, trackers or product brief
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
    .claude/agents/*|.claude/skills/*|factory/scripts/*|factory/templates/*|factory/dashboard.html|factory/issues/_TEMPLATE.md) return 0 ;;
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

if [[ $UPDATE == 1 ]]; then
  echo "✓ Updated $DEST: $updated refreshed, $new new, $same unchanged, $skipped project-owned left alone."
  echo "  Review with: git -C \"$DEST\" diff --stat   then commit."
else
  echo "✓ Copied $new files into $DEST ($skipped already there, left untouched)."
  echo "  Next: commit them, open Claude Code in $DEST, and run /factory-init."
fi
