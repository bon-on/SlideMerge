---
id: feature-gamepix-sdk
title: Slide Merge GamePix SDK v3 integration
status: active
owner: games
related_adrs:
  - adr-gamepix-sdk
related_contracts:
  - contract-slide-merge-gamepix
required_evidence:
  - flutter-tests
  - flutter-web-tests
  - flutter-analyze
  - gamepix-web-build
---

# Feature Spec: Slide Merge GamePix SDK v3 integration

## Problem
GamePix approved the SDK-free package but told us it "has not received GamePix SDK integration approval", so it misses the extra exposure SDK games get. The SDK v3 guide (my.gamepix.com/sdk/doc) asks for pause/resume handlers that mute audio, manual lifecycle signals, ads only at natural breaks and localStorage read by known key names.

## Scope
- GamePix web build (`--dart-define=GAMEPIX=true`) only: `GamePixPlatform` adapter and `tool/build_gamepix.sh`.
- Out of scope: gameplay and balance, CrazyGames/Pages/mobile behaviour, rewarded ads, login, multiplayer, `happyMoment`/`sadMoment`, loading percentages.

## Acceptance Criteria
- S1: The GamePix `index.html` sets `window.GamePixConfig = { lifecycle: 'manual' }` and loads `https://integration.gamepix.com/sdk/v3/gamepix.sdk.js` exactly once, both before the Flutter bootstrap. No other external script, link or URL is added; the build script fails otherwise.
- S2: The adapter registers `pause` and `resume`. Pause mutes all game audio (`isAudioMuted`), resume restores it; the Player's `soundOff`/`soundOn` do the same for its mute control; repeated events change nothing.
- S3: `lifecycle.loaded()` is sent once after the first Flutter frame; `lifecycle.gameStart()` is sent when gameplay starts, after `loaded()`. A Player that never answers does not block the game (10 s timeout).
- S4: Interstitials (`ads.interstitial()`) play only when the player starts a new board from a finished run (Play again on the run summary, the Restart button or key after game over), never mid-run, at least 2 minutes after the previous ad (the first run break may show one; the Player itself caps ads at one every 3 minutes), and never twice at once. A failed, unfilled or hung ad (120 s) still starts the next board.
- S5: Preferences are kept in one localStorage item read with `getItem` by name (`slidemerge.prefs_v1`, named per game because GamePix may serve several games from one origin), so GamePix storage sync restores progress. Progress saved before the SDK (enumerated `flutter.` keys) is kept on the first SDK session, and those keys are never cleared.
- S6: Without the SDK (blocked script, direct page) the adapter behaves like the old no-op platform: no ads, no registration prompt.
- S7: The CrazyGames and Pages bundles contain no GamePix adapter code, and the GamePix bundle no CrazyGames code.

## Constraints
- GamePix rules: no other third-party SDK, no external links, no timer-triggered ads, the game pauses and mutes during ads.
- A broken SDK must never keep the game from starting or continuing.

## Stack Notes
- `lib/platform/gamepix_platform.dart` reuses `CloudPrefsStore` with the prefixed localStorage item as the "cloud", an in-memory mirror seeded from the old keys and no local stamp, so the named item is always the source.
- shared_preferences_web lists keys with `localStorage.key(i)`, which GamePix sync does not see; that is why the named item is needed.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`.
- `tool/build_gamepix.sh` and `tool/build_crazygames.sh` succeed; `GamePix` strings only in the GamePix `main.dart.js`.
