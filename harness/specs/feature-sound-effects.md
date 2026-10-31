---
id: feature-sound-effects
title: Sound effects with a persisted mute toggle
status: active
owner: games
related_adrs:
  - adr-slide-merge-crazygames-web
related_contracts:
  - contract-slide-merge-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - flutter-web-build
  - crazygames-web-build
  - gamepix-web-build
  - harness-audit
---

# Feature: Sound effects with a persisted mute toggle

## Problem
The game is silent. Short sound effects make slides, merges, undo and the end
of a run feel responsive on web (GitHub Pages, CrazyGames, GamePix) and on iOS
and Android, and players need a way to turn them off.

## Scope
- Four short effects in `assets/audio/` (mono 44.1 kHz 16-bit WAV, each under
  40 KB): `slide` (a move that changed the board without merging), `merge` (a
  move that merged at least one pair; once per move, replaces `slide`), `undo`
  (an undo that reverted a move) and `game_over` (the move after which no move
  is left; replaces `slide`/`merge`).
- Sounds are synthesized by the committed, dependency-free generator
  `tool/generate_sounds.py` (Python 3 stdlib, fixed seed, deterministic).
  No third-party audio.
- `lib/src/audio/sound_fx.dart`: `SoundFx.play(Sfx)` is fire-and-forget, a
  no-op when muted and never throws. Web uses HTML `Audio` elements
  (`web_sound_web.dart`, with `web_sound_stub.dart` for other targets); native
  uses the MethodChannel `slide_merge/audio` (`play {asset, volume}`,
  `disposeAudio`). iOS plays with `AVAudioPlayer` in the `.ambient` session
  category (respects the silent switch, keeps the user's music); Android uses
  `MediaPlayer` with `USAGE_GAME`. Missing plugin or platform errors are
  swallowed.
- Hook points are in `lib/main.dart` (`_move`, `_undo`), once per user action,
  never from `game_logic.dart`. Moves that change nothing, restart and mode
  switches are silent. No sound for the tutorial card.
- Mute: a sound icon button next to "?" in the header
  (`Icons.volume_up_rounded` / `Icons.volume_off_rounded`, tooltip "Sound on" /
  "Sound off"). The choice is stored as the bool `sound_muted_v1` in
  `shared_preferences` (default: sound on). Effective mute is the user choice
  OR `GamePlatform.isAudioMuted`, which the CrazyGames adapter reads from
  `CrazyGames.SDK.game.settings.muteAudio` on every sound; the no-op and
  GamePix platforms return false.
- The button lives inside the same `ExcludeFocus` / `AbsorbPointer` subtree as
  "?", so it is blocked while the tutorial card is open or loading. After a
  toggle the board is refocused so arrow keys / WASD keep working. No new
  keyboard shortcut.

## Acceptance Criteria
- Each move plays exactly one of slide, merge or game_over; a blocked move
  plays nothing; undo plays `undo` only when it reverted a move.
- Nothing plays while muted (user toggle or platform mute); the toggle flips
  the icon and tooltip and persists across launches.
- The board keeps keyboard focus after using the toggle.
- Every `Sfx` value has a file in `assets/audio/` listed by `pubspec.yaml`.
- Running `python3 tool/generate_sounds.py` twice yields identical files.
- `tool/build_crazygames.sh` and `tool/build_gamepix.sh` self-checks pass; the
  GamePix bundle makes no external requests.
- A headless browser run observes `HTMLMediaElement.play` for the expected
  assets, and nothing when muted.
- No layout overflow in the existing layout tests.

## Constraints
- English UI text; no new package dependency.
- Do not change game rules or scoring.
- Audio must be bundled assets (GamePix: no external requests).

## Evidence
- flutter analyze, flutter test, `flutter test --platform chrome test/web`
- flutter build web --release --base-href /SlideMerge/
- tool/build_crazygames.sh, tool/build_gamepix.sh
- `<harness-lab>` audit (`node <harness-lab>/dist/index.js audit . --format md`)
