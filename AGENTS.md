# Agent Instructions

Use the `harness-apply` skill for substantive work in this repo.

Startup sequence:
1. Read `harness/manifest.json`.
2. Select the active feature spec from `harness/specs/`.
3. Read `approvedPacks` from the manifest. If it is empty, treat `suggestedPacks` as recommendations only.
4. Read linked ADRs and contracts before making code changes.
5. Read `harness/rules/constraints.md` and `harness/rules/golden-rules.md`.

Response contract:
- Include `References used`, `Constraints`, `Conflicts or gaps`, and `Escalation`.
- Escalate when required harness artifacts are missing or conflicting.
- State which approved or suggested profile packs were used.
