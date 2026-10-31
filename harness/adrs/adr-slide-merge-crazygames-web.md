---
id: adr-slide-merge-crazygames-web
title: Use a build flag and platform adapter for the CrazyGames build
status: accepted
related_specs:
  - feature-slide-merge-crazygames
  - feature-slide-merge-gamepix
---

# ADR: Build flag and platform adapter for CrazyGames

## Context
Slide Merge ships to GitHub Pages and mobile without any portal code. CrazyGames needs SDK gameplay events, serves the bundle from an unknown sub path, and forbids outbound links and (for Basic Launch) ads.

## Decision
- A compile-time constant `bool.fromEnvironment('CRAZYGAMES')` selects the CrazyGames adapter; without it the web build uses `NoopGamePlatform`. A conditional import on `dart.library.js_interop` keeps `dart:js_interop` out of native builds.
- Game screens depend only on the `GamePlatform` interface (`initialize`, `gameplayStart`, `gameplayStop`, `allowsResultRegistration`) and call it on state transitions, guarded so exceptions never escape.
- The SDK script and relative base href are injected into the build output by `tool/build_crazygames.sh`, not into `web/index.html`. This shell boots Flutter with an inline loader, so the SDK tag is inserted right after the `game-host` element, before that loader.
- The hub navigation bar is removed from the output by the script; the leaderboard prompt is blocked via `allowsResultRegistration`.

## Consequences
- Pages, mobile and CrazyGames builds share one codebase without affecting each other.
- The script relies on string substitutions in `index.html`, so it verifies the result and fails the build otherwise.

## GamePix addendum
GamePix builds (`--dart-define=GAMEPIX=true`, see `feature-slide-merge-gamepix`) reuse the no-op platform with `allowsResultRegistration == false` instead of an adapter: GamePix forbids third-party SDKs and external network use. The CrazyGames adapter is selected only by `CRAZYGAMES=true`.
