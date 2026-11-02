---
id: contract-how-to-play-tutorial
title: Deliver a skippable first-run tutorial that never affects play
status: active
related_specs:
  - feature-how-to-play-tutorial
  - feature-retention-polish
evidence_files:
  - reports/how-to-play-tutorial-verification.md
---

# Contract: How-to-play tutorial

## Goal
Explain the goal and controls once, let players skip, and let them reopen it.

## Done Criteria
- First-run overlay with 3 steps, Skip, Next/Play, page dots and `?` reopen.
- Seen flag `tutorial_seen_v1` persists; storage failures never break play.
- Game input is blocked while the overlay is open.
- Widget tests cover the behaviors in the feature spec.
- Flutter tests and harness audit pass.

## Verification
- flutter test
- harness audit

## Evidence References
- reports/how-to-play-tutorial-verification.md
