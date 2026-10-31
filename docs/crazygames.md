# CrazyGames upload

A web build made with `--dart-define=CRAZYGAMES=true` uses the CrazyGames HTML5 SDK v3. Builds without that flag (GitHub Pages, mobile) never touch the SDK.

## Build

```sh
tool/build_crazygames.sh
```

Output:

- `build/crazygames/`: bundle folder
- `build/slide-merge-crazygames.zip`: zip for the portal upload

The script runs `flutter build web --release --base-href / --no-web-resources-cdn --dart-define=CRAZYGAMES=true`, then:

1. sets `<base href="./">`;
2. inserts the SDK script before the Flutter loader (this shell uses an inline loader, not `flutter_bootstrap.js`);
3. removes the Bon-on hub navigation bar and sets its height to 0 (the portal forbids outbound links);
4. deletes `*.symbols`, checks at most 1500 files and 50MB, and zips the folder.

## Tests

```sh
flutter test                              # game flow with a fake platform (VM)
flutter test --platform chrome test/web   # SDK adapter against a fake window.CrazyGames
```

## Local check

```sh
cd build && python3 -m http.server 8765
# open http://localhost:8765/crazygames/index.html
```

On `localhost` the SDK environment is `local`; the console shows `Requesting gameplay start`/`stop` logs.

## SDK events

| When | Call |
|---|---|
| App start | `SDK.init()`; the SDK is disabled unless `environment` is `crazygames` or `local` |
| Tutorial check done, no overlay | `gameplayStart()` (first launch: only after the overlay closes) |
| How-to-play overlay opens | `gameplayStop()` |
| Overlay closes | `gameplayStart()` |
| Game over / field cleared | `gameplayStop()` |
| Restart, new game, mode switch, undo that revives the run | `gameplayStart()` |

Calls are sent on transitions only. Leaderboard registration prompts are disabled in this build, and there are no ads.

## Upload checklist

- [ ] Submit through Basic Launch (ads are off there).
- [ ] Orientation: portrait. On desktop the game is centered in a narrow column.
- [ ] Input: Swipe (touch or mouse drag), arrow keys or WASD to slide; Z or U undoes.
- [ ] Covers to prepare (not created yet): 1920x1080, 800x1200, 800x800.
- [ ] In the portal QA tool, check loading and gameplay events.

## Known limits

- Classic 4x4 and Relaxed 5x5 modes.
- Material's default font fallback may still be fetched from a Google font CDN.
