---
id: feature-how-to-play-tutorial
title: First-run how-to-play tutorial with skip
status: active
owner: games
related_adrs:
  - adr-spec-driven-delivery
related_contracts:
  - contract-how-to-play-tutorial
required_evidence:
  - flutter-tests
  - harness-audit
---

# Feature: First-run how-to-play tutorial

## Problem
New players get no explanation of the merge goal, the input options or the undo
charge. Players asked for a short explanation with a way to skip it.

## Scope
- On the first launch only, a "How to play" overlay card is shown over the
  dimmed game. It has 3 short steps with an icon, page dots, a Skip button and
  a Next button (Play on the last step).
- Skip or Play closes it and stores `tutorial_seen_v1` (bool) in
  shared_preferences. Later launches go straight to the game.
- A "?" (help_outline, tooltip "How to play") header button reopens it at step
  1 at any time without resetting the game.
- Keys while open: Enter/Space next/play, Escape skip, Left/Right previous/next.
  Arrow keys, WASD and Z/U never reach the game while it is open.
- Swipes, taps and the Undo button are blocked while it is open.
- Storage failures never break play: a read failure shows the tutorial, a write
  failure just closes it.
- The store is injectable (`TutorialStore`) so tests do not need real prefs.
- Text is English, card max width 360 px, scrollable for short viewports.
- Slide Merge has no clock, so there is nothing to pause.
- Pointer input is ignored until the seen-flag read has answered; the card does not consume Tab, F5 or Ctrl/Meta/Alt shortcuts. The game key handler ignores auto-repeat and Ctrl/Meta/Alt combos.

## Acceptance Criteria
- Unset flag: overlay shown at launch; arrow keys and swipes do not move tiles.
- Next walks 3 steps; the last shows Play; Play closes and stores the flag.
- Skip and Escape close and store the flag.
- Flag set: no overlay at launch.
- "?" reopens at step 1 and the board, score and moves are unchanged.
- After closing, arrow keys move the board again.
- Fits 390x844, 844x390 and 1280x720 without overflow.
- Flutter tests, analyze, web build and harness audit pass.

## Constraints
- Do not change merge rules, modes, undo rules or leaderboard behavior.
- No new dependency beyond shared_preferences (already used).

## Evidence
- flutter test
- harness audit
