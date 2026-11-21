# Project instructions

Project-owned. Add instructions specific to this repository here, such as operational cautions, domain rules or verification notes that do not fit a spec, ADR or rule file. harness-lab creates this file once and never replaces your edits; keep `AGENTS.md`, `CLAUDE.md` and `harness/workflow.md` identical to the template so `harness-lab update` can refresh them.

- 회귀 검증은 `flutter test`(CI와 동일), 공유 실행 증거는 `harness-lab verify`(`harness/verify.json`) 후 `check-evidence`와 `audit`로 확인한다.
