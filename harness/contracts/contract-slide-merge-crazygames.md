---
id: contract-slide-merge-crazygames
title: Slide Merge CrazyGames web distribution contract
status: active
related_specs:
  - feature-slide-merge-crazygames
  - feature-sound-effects
evidence_files:
  - docs/crazygames.md
  - reports/slide-merge-crazygames-verification.md
---

# Contract: Slide Merge CrazyGames web distribution

## Goal
Produce an upload-ready CrazyGames web bundle from the same Flutter codebase.

## Scope
- `GamePlatform` interface, no-op implementation and `dart:js_interop` CrazyGames adapter under `lib/platform/`.
- Gameplay start/stop calls from the game screen on transitions.
- `tool/build_crazygames.sh` and `docs/crazygames.md`.

Excluded: gameplay changes, ads, Data/User modules, portal upload.

## Done Criteria
- `flutter analyze`, `flutter test` and `flutter test --platform chrome test/web` pass.
- `tool/build_crazygames.sh` succeeds and its index.html checks pass.
- The GitHub Pages build contains no CrazyGames SDK script.
- Results are recorded in `reports/slide-merge-crazygames-verification.md`.

## Verification
```sh
flutter analyze
flutter test
flutter test --platform chrome test/web
tool/build_crazygames.sh
flutter build web --release --base-href /SlideMerge/
node <harness-lab>/dist/index.js audit . --format md
```

## Evidence References
- docs/crazygames.md
- reports/slide-merge-crazygames-verification.md
