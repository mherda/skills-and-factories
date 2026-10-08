---
name: issues
description: The factory's inbox and issue tracker. Use when the user types /issues, /issues <ISS-n>, /issues new <text>, /issues close <ISS-n>, or asks what needs their input, which bugs are open, or wants to answer an agent's question.
---

# Issues

Issues are markdown files in `factory/issues/` (`ISS-<n>-<slug>.md`, format in
`factory/issues/_TEMPLATE.md`). They hold bugs, feature requests, and every
question an agent couldn't answer itself. This skill lists them, lets the user
answer questions with a picker, records the answers (and, if the user wants,
promotes them to standing decisions), and restarts the paused work.

`T="python3 -I <repo>/factory/scripts/tracker.py"`.

Statuses: `open` (not started) · `needs-input` (an agent is waiting on the user)
· `answered` (answered, work not yet resumed) · `in-progress` (a job is on it)
· `done` · `wontfix`.

## /issues

1. Run `$T inbox` and `$T issues open in-progress`.
2. Show it compactly: first **Needs your input** (id, title, job, number of
   unanswered questions), then **Answered, ready to resume**, then **Open**
   (bugs first, then by priority), then **In progress**. Leave out done and
   wontfix unless asked.
3. If anything needs input, use AskUserQuestion to let the user pick one (up to
   three, most recent first, with "Other" for typing an id). Then go to
   **Answer**. If nothing needs input, suggest `/factory ISS-<n>` for an open
   item, or `/bug` to report one.

## /issues <ISS-n>

Show the issue: title, type, status, job, the description in brief, then each
question with its answer, if any. If it has unanswered questions, go to
**Answer**. If it's `open` with no job, offer to start it with `/factory ISS-<n>`.

## Answer

For the chosen issue:

1. Read the whole issue and, if it has a job, the job's `job.json` and the file
   the questions came from (`spec.md`, `build.md` or `decision.md`) for
   context.
2. Find the questions under `## Questions` with no matching entry under
   `## Answers`. Ask them with AskUserQuestion, up to four per call, one
   question each:
   - `question`: the question text. `header`: `Q<n>` plus a word or two.
   - `options`: the issue's options, with labels shortened to five words or
     fewer and the consequence as the description. Keep "(Recommended)" on the
     recommended one, and keep it first.
   - If the context is long, give the user a two-line summary before asking.
3. Record each answer under `## Answers`, exactly like this:

   ```markdown
   ### A<n> (to Q<n>) · <date>
   <chosen option, verbatim, or the user's own words if they picked Other>
   ```

   Add a Log line, set `status: answered`, and in the roadmap change the job's
   `[?]` item to `[~]`.
4. **Decisions.** If an answer is a rule that should hold beyond this one job
   (a product, design, copy, privacy or technical policy), not a one-off
   detail, ask with AskUserQuestion whether to save it as a standing decision:
   "Record as decision" (Recommended) or "Only for this issue". On yes, follow
   the **decide** skill to append it with `Source: ISS-<n>`.
5. **Resume.** If the issue has a job, ask "Resume <job-id> now?" (Resume now
   (Recommended) / Later). On "Resume now", invoke the `factory` skill with
   `resume <job-id>`. This session becomes that job's orchestrator. On
   "Later", tell the user to run `/factory resume <job-id>` when they're ready.
   If the issue has no job, offer `/factory ISS-<n>`.

## /issues new <text>

Create an issue with `$T issue-id <slug>`, which prints the new file path. Fill
it from the template with type `feature` (or `question` if the text is a
question), status `open` and today's date. Write the description from the
user's text, and ask at most one follow-up question if something essential is
missing. For bugs, use `/bug` instead. If it belongs to a roadmap milestone,
ask whether to add it to the roadmap (`/roadmap add`).

## /issues close <ISS-n> [wontfix]

Set `status: done` (or `wontfix`) with a Log line. If a job is still active on
it, warn the user and suggest `/factory abandon <job-id>` instead.

## Rules

- Edit issue files with Edit. Never rewrite one wholesale, because a factory
  session may be appending questions at the same time.
- Don't answer questions on the user's behalf. Every answer comes from the
  user in this conversation.
