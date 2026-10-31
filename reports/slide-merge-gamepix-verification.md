# Verification: SlideMerge GamePix web distribution

- Spec: `harness/specs/feature-slide-merge-gamepix.md`
- ADR: `harness/adrs/adr-slide-merge-crazygames-web.md`
- Contract: `harness/contracts/contract-slide-merge-gamepix.md`
- Environment: Flutter 3.41.7, macOS, headless Chrome

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 49 passed |
| `flutter test --platform chrome test/web` | 9 passed (includes GAMEPIX platform selection) |
| `flutter build web --release --base-href /SlideMerge/` | passed; no CrazyGames text, hub bar kept |
| `tool/build_crazygames.sh` | passed; also checks Roboto in FontManifest |
| `tool/build_gamepix.sh` | passed; 36 files, about 29MB; zip `build/slide-merge-gamepix.zip` about 11412KB, `index.html` at the zip root |
| Bundle `index.html` | `<base href="./">`, no external script, no hub nav, no crazygames text, nav height 0px |
| `crazygames` strings in GamePix `main.dart.js` | 0 |
| `assets/FontManifest.json` | lists family Roboto (400/500/700/900) |
| Headless Chrome, hosts other than localhost unresolvable | no name-resolution errors; loader present early, removed after the first frame |
| Layout in 640x480 and 360x640 iframes | renders without overflow or clipping |
| Harness audit | Critical 0 |
