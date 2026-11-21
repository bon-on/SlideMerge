---
id: adr-progress-run-envelope
title: Store validated active attempts with their progress envelope
status: accepted
related_specs:
  - feature-active-run-resume
---

# Store validated active attempts with their progress envelope

## Context
Refreshing currently discards the board. Separate attempt and reward keys could restore an already rewarded attempt or lose mission accounting.

## Decision
Extend the existing progress JSON with an optional versioned active attempt. Rule engines parse snapshots without partial mutation. The screen/controller captures attempt and meta progress together after resolving actions, and queues captured writes in order. Settling a run clears its attempt in the same write that credits XP. Legacy saves omit the optional field and start fresh. Ignore invalid attempts independently of valid meta progress. PourSort validates undo history by replaying against its deterministic generated level; SlideMerge validates board identities, bounded counters and undo state. Transient animation, selection, audio and modal state are not persisted.

## Alternatives
A separate active-run key was rejected because rewards and run clearing could diverge. Saving only a board was rejected because undo and mission accounting would reset. Persisting animation or random-generator internals adds coupling without improving visible resume behavior.

## Consequences
Existing local/cloud and portal adapters remain unchanged. Recovery is best effort when storage fails or the browser terminates before an asynchronous write completes. Future randomness is not replayed; the visible board and undo state are preserved exactly.
