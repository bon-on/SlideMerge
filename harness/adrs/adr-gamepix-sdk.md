---
id: adr-gamepix-sdk
title: Integrate the GamePix SDK v3 in the GamePix build
status: accepted
related_specs:
  - feature-gamepix-sdk
  - feature-slide-merge-gamepix
---

# ADR: Integrate the GamePix SDK v3 in the GamePix build

## Context
The GamePix build was SDK-free by design (feature-slide-merge-gamepix). GamePix published it but withheld "SDK integration approval", which limits exposure on the portal.

## Decision
- `GAMEPIX=true` web builds select `GamePixPlatform` (SDK v3, manual lifecycle). The SDK script is injected by `tool/build_gamepix.sh` before the Flutter bootstrap; it is the only external script allowed.
- Pause/resume mute audio; interstitials only between finished runs with a 2 minute cooldown; preferences in one named localStorage item via `CloudPrefsStore`.
- This supersedes the "no SDK" part of feature-slide-merge-gamepix; its other rules (no outbound links, bundled fonts, relative paths) stay.

## Alternatives
- Stay SDK-free: no work, but no SDK approval or extra exposure.
- Legacy automatic lifecycle: less code, but GamePix analytics (load time, time to play) are less accurate, which the guide says affects ranking.
- Keep shared_preferences_web as is: GamePix sync would not restore progress, because the plugin enumerates keys.

## Consequences
- The GamePix bundle makes requests to integration.gamepix.com and shows GamePix ads.
- The board clock and audio follow GamePix pause events as well as tab visibility.
- Existing players keep their progress: the first SDK session copies the enumerated local keys into the named item.
