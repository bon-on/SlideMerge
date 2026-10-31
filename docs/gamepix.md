# GamePix upload

A web build made with `--dart-define=GAMEPIX=true` is SDK-free: no third-party script, no hub link, no leaderboard upload, no ads, no external requests. Other builds (GitHub Pages, CrazyGames, mobile) are unaffected.

## Build

```sh
tool/build_gamepix.sh
```

Output:

- `build/gamepix/`: bundle folder
- `build/slide-merge-gamepix.zip`: zip for the portal upload (`index.html` is at the zip root)

The script runs `flutter build web --release --base-href / --no-web-resources-cdn --dart-define=GAMEPIX=true`, then:

1. sets `<base href="./">`;
2. removes the Bon-on hub navigation bar and sets its height to 0, and drops the template comment with an external URL;
3. checks that `index.html` has no `crazygames`/`bon-on.github.io` text, no external script or link, and that `FontManifest.json` lists Roboto;
4. deletes `*.symbols`, zips the folder, verifies `index.html` is at the zip root and prints the file count, size and the number of `crazygames` strings left in `main.dart.js`.

Roboto is bundled in `assets/fonts/` (license: `assets/fonts/Roboto_LICENSE.txt`), so the app never downloads it from fonts.gstatic.com.

## Local check

```sh
cd build && python3 -m http.server 8765
# open http://localhost:8765/gamepix/index.html, also inside a 640x480 and a 360x640 iframe
```

## Upload checklist

- [ ] Zip: `build/slide-merge-gamepix.zip`.
- [ ] SDK integration: none.
- [ ] Orientation: portrait.
- [ ] Desktop and Mobile friendly: yes (touch and mouse). Input: Swipe (touch or mouse drag), arrow keys or WASD to slide; Z or U undoes.
- [ ] Icon 256x256 and cover 1360x850 (not created yet).
- [ ] Language: English.

## Known limits

- The loading screen is plain CSS (spinner and title); it disappears on Flutter's first frame.
- `main.dart.js` and `flutter.js` may still contain engine constants with Google URLs (for example the CanvasKit CDN fallback); the build uses local CanvasKit and Roboto, so they are not requested.
