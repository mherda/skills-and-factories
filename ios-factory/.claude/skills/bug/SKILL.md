---
name: bug
description: File a bug in the factory's issue tracker and optionally start fixing it. Use when the user types /bug <description>, or reports something broken in the app ("it crashes when...", "the widget shows...") and wants it tracked or fixed.
---

# Bug

1. **Capture.** From the user's text, pull out: what they did, what they
   expected, what happened, and the device, iOS version and build (TestFlight
   build number, or "simulator / main"). If steps to reproduce or the build are
   missing and matter, ask once in a single short message. Don't interrogate. A
   screenshot path, crash log or TestFlight feedback text the user gives goes in
   as is (crash logs in a fenced block).
2. **Look.** Spend a minute in the code to find the likely area: grep for the
   screen, service or message involved. Add a `Suspected area:` line with
   paths. Don't fix anything here.
3. **Duplicates.** Run `python3 -I <repo>/factory/scripts/tracker.py issues`
   and check for an existing open bug about the same thing. If there is one,
   offer to add this report to it as a Log entry instead.
4. **File.** `tracker.py issue-id <slug>` prints the new path. Fill it from
   `factory/issues/_TEMPLATE.md`: `type: bug`, `status: open`, `priority`
   (high for crashes and data loss, normal otherwise), today's date, and a
   Description with **Steps**, **Expected**, **Actual**, **Environment** and
   **Suspected area**. Remove the template's example question.
5. **Next.** Ask with AskUserQuestion: "Fix now" (Recommended for high
   priority: starts `/factory ISS-<n>` in this session), "Add to roadmap"
   (`/roadmap add` under the current milestone, with a ` · ISS-<n>` ref), or
   "Just track it". Act on the answer.
