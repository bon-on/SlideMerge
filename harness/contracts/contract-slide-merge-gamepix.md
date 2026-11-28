---
id: contract-slide-merge-gamepix
title: Slide Merge GamePix web distribution contract
status: active
related_specs:
  - feature-slide-merge-gamepix
evidence_files:
  - docs/gamepix.md
  - reports/slide-merge-gamepix-verification.md
---

# Contract: Slide Merge GamePix web distribution

## Goal
Produce an upload-ready GamePix web bundle whose only third-party script is the GamePix SDK v3 (feature-gamepix-sdk) from the same Flutter codebase.

## Scope
- `--dart-define=GAMEPIX=true` selects `NoopGamePlatform(allowsResultRegistration: false)` in `lib/platform/game_platform_factory_web.dart`.
- Bundled Roboto font (`assets/fonts/`), CSS loader in `web/index.html`.
- `tool/build_gamepix.sh` and `docs/gamepix.md`.

Excluded: gameplay changes, portal upload. The GamePix SDK and ads are covered by feature-gamepix-sdk.

## Done Criteria
- `flutter analyze`, `flutter test` and `flutter test --platform chrome test/web` pass.
- `tool/build_gamepix.sh` succeeds and its self-checks pass.
- `tool/build_crazygames.sh` and the GitHub Pages build still succeed.
- Results are recorded in `reports/slide-merge-gamepix-verification.md`.

## Verification
```sh
flutter analyze
flutter test
flutter test --platform chrome test/web
tool/build_gamepix.sh
tool/build_crazygames.sh
node <harness-lab>/dist/index.js audit . --format md
```

## Evidence References
- docs/gamepix.md
- reports/slide-merge-gamepix-verification.md
