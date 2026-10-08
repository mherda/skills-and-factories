---
title: Feature name
type: feature
summary: One line: what it does for the user.
code: [path/to/FeatureFolder/, path/to/Service.swift]
related: [modules/xxx.md, architecture/data.md]
decisions: []
shipped: unreleased
---

# Feature name

## For users
What it does and how to use it, in plain words (this is what testers and the
release notes draw on). Permissions it needs, and its limits.

## How it works
The flow, step by step, from the trigger to what's on screen. Name the types
and functions (`AreaService.refresh()`), and link module pages.

## Data
What it reads and writes, and where (SwiftData model, App Group, iCloud,
network). Migration or sync notes.

## Edge cases and gotchas
What's subtle, what broke before, what not to change without care.

## Decisions
- D-xxx: how it shaped this feature.

## Tests
Where the tests are and what they cover.
