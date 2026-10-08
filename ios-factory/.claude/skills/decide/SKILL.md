---
name: decide
description: Record, list or supersede the user's standing decisions in factory/decisions.md, which every factory agent reads and follows. Use when the user types /decide, /decide <decision>, /decide supersede <D-n> <decision>, or says "from now on…", "always…", "never…", "we decided…" about the app's product, design, copy, privacy or tech.
---

# Decide

`factory/decisions.md` is the user's rulebook for the agents. The spec-writer
follows it, the builder never contradicts it, reviewers flag violations, and
the approver escalates anything that conflicts with it or touches an area
marked `escalate`. Only the user makes decisions. Agents propose them as
questions in issues.

`T="python3 -I <repo>/factory/scripts/tracker.py"`.

## /decide (no arguments)

Run `$T decisions` and show the list. Group by scope if there are more than
ten, and leave out superseded ones unless asked.

## /decide <decision>

1. Check `$T decisions` and read related entries. If the new one conflicts
   with an active decision, say which one and ask whether it supersedes it.
2. Turn the user's words into an entry. Keep their meaning exactly: tighten the
   wording, but don't add rules they didn't state. If the reason isn't obvious,
   ask for it in one short question. "Why" is what lets agents judge edge
   cases.
3. Pick the scope: a few comma-separated areas (e.g. `ui, copy`,
   `data, cloudkit`, `widget`, `privacy`, `release`, `all`).
4. Get the id with `$T decision-id` and append to the end of
   `factory/decisions.md`:

   ```markdown

   ## D-<n> · <YYYY-MM-DD> · <short title>
   Scope: <areas>
   Decision: <what to do, stated so an agent can follow it>
   Why: <reason>
   Source: user            (or ISS-<n> when it came from answering an issue)
   Status: active          (or "escalate": agents must ask before touching this area)
   ```

5. Show the entry in one block and confirm it's saved. If jobs are running
   (`jobstate.py list --active`), say that agents pick it up from their next
   step, and that a spec already written won't change unless the user asks for
   a rework.

## /decide supersede <D-n> <decision>

Record the new decision as above, then change the old entry's `Status:` line
to `Status: superseded by D-<new>`. Never delete entries. The history is part
of the record.

## Good decisions

Concrete and checkable: "Distances in km everywhere, metres under 1 km", not
"use good units". If the user says something vague, offer a concrete wording
and let them correct it.
