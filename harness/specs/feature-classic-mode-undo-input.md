---
id: feature-classic-mode-undo-input
title: Classic 4x4 tension, undo charge twist, keyboard and swipe input, persisted best
status: active
owner: games
related_adrs:
  - adr-spec-driven-delivery
related_contracts:
  - contract-classic-mode-undo-input
required_evidence:
  - flutter-tests
  - flutter-web-build
  - harness-audit
  - layout-screenshots
---

# Feature: Classic mode, undo charge, better input

## Problem
The 5x5 board with 82/18 spawns makes runs very long and almost never lost. Web has no keyboard control, slow swipes are ignored (velocity-only), best score is not persisted, and the game is a generic 2048 clone.

## Scope
- Modes: Classic (4x4, 90% tier-1 / 10% tier-2 spawns, default) and Relaxed (5x5, 82/18, the previous behaviour). A simple mode picker in the UI.
- Twist: one undo charge. The player holds at most 1 charge (starts with 1), can revert the last move, and earns a new charge every 20 merges. Chosen over blocker stones because it adds a risk/reward decision with almost no extra rules or visuals, and is easy to make deterministic (state snapshot, injectable Random).
- Board logic extracted to a widget-free file (`lib/game_logic.dart`) with unit tests.
- Input: arrow keys and WASD; swipe recognised by displacement (>= 24 px), not velocity.
- Best score stored locally per mode (shared_preferences).
- Responsive layout: centered, max width, board fully visible at 390x844 and 1280x720.

## Acceptance Criteria
- Default game is 4x4 with 90/10 spawns; Relaxed 5x5 selectable.
- Unit tests cover slide/merge per direction, one merge per tile per move, score, game over, spawn, undo and recharge.
- Keyboard and slow swipes move the board; best score survives restart per mode.
- Leaderboard offer (gameId `slide-merge`) is kept for Classic mode only, since scores across modes are not comparable.
- No overflow at the two target sizes; hub nav bar in web/index.html unchanged.
- flutter analyze, flutter test, web build with `--base-href /SlideMerge/`, and harness audit (0 Critical) pass.

## Constraints
- One new runtime dependency only (shared_preferences).
- Game logic must not import Flutter widgets.

## Evidence
- reports/classic-mode-undo-input-audit.md
