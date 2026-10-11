# Upstream

<!--
Fixes made in this app's copy of factory-owned files (factory/scripts, hooks,
templates, dashboard, .claude/agents, .claude/skills) that still need porting
to the android-factory repo. Without that, the next `install.sh --update` would
bring the bug back. While an entry is unticked, --update keeps this app's copy
of its files and prints the diff command. Once the factory has the fix (the
files match), --update ticks the entry itself.

One line per fix, added by the orchestrator in the same commit as the fix,
starting at the beginning of the line:
  - [ ] 2026-01-31 · 1a2b3c4 · factory/scripts/droid.sh · launch with am start -S: a warm start ignored the new intent extras
         date        commit    file(s), comma-separated      what and why
Ported means every code line the fix added is in android-factory's copy (comments
may be reworded). If a port changed the code itself, tick the entry by hand.
-->
