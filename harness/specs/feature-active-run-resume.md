---
id: feature-active-run-resume
title: Automatically resume unfinished attempts
status: active
owner: games
related_adrs:
  - adr-progress-run-envelope
related_contracts:
  - contract-classic-mode-undo-input
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - portal-builds
  - harness-audit
---

# Automatically resume unfinished attempts

## Problem
Refreshing or reopening the game discards an unfinished board, even though long-term progress is already saved.

## Scope
Automatically persist and restore the current attempt, including reversible state and session accounting, inside existing progress storage.

## Constraints
No new dependencies, scoring changes, generator changes or portal/cloud adapter changes. Storage is best effort and must not block play.

## Acceptance Criteria
- R1: Save the current board, mode or level, move counters, undo state and assistance allowance after every successful rule mutation. Restore before accepting input.
- R2: Preserve attempt mission/session statistics with meta progress. Completed rewards are never granted again on refresh; a settled attempt is removed in the same progress write as its reward.
- R3: Version and validate the entire attempt before installing it. Malformed, unsupported or inconsistent attempts fall back to a fresh board without deleting valid legacy XP, records or settings.
- R4: Keep the existing progress key, legacy migration and portal/cloud adapters. Serialize writes in order; storage failures never prevent play. No new dependencies or changes to scoring, spawn weights or puzzle generation.
- R5: Restart and mode/level changes replace the saved attempt. Undo after restore behaves as before refresh.

## Requirement-to-check map
- R1/R5: active_run_resume_test.dart roundtrip and controller/screen recreation, undo and restart tests.
- R2: active_run_resume_test.dart reward settlement/mission replay tests.
- R3: active_run_resume_test.dart corrupt and unsupported payload tests.
- R4: existing progress/cloud/platform tests; analyze; Pages, CrazyGames and GamePix builds.

## Evidence
- reports/active-run-resume-verification.md
