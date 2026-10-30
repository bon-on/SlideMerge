---
id: contract-classic-mode-undo-input
title: Deliver classic 4x4 mode, undo twist, and improved input
status: active
related_specs:
  - feature-classic-mode-undo-input
evidence_files:
  - reports/classic-mode-undo-input-audit.md
---

# Contract: Classic mode, undo, input

## Goal
Make the game tense by default, give it one distinguishing mechanic, and make it playable with keyboard and slow swipes.

## Done Criteria
- Logic unit tests, analyze, web build, and harness audit pass.
- Screenshots at 1280x720 and 390x844 show a fully visible board.

## Verification
- flutter analyze
- flutter test
- flutter build web --release --base-href /SlideMerge/
- harness audit

## Evidence References
- reports/classic-mode-undo-input-audit.md
