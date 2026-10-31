# Verification: SlideMerge CrazyGames web distribution

- Spec: `harness/specs/feature-slide-merge-crazygames.md`
- ADR: `harness/adrs/adr-slide-merge-crazygames-web.md`
- Contract: `harness/contracts/contract-slide-merge-crazygames.md`
- Environment: Flutter 3.41.7, macOS, headless Chrome for web tests

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 46 passed (was 37 before this change) |
| `flutter test --platform chrome test/web` | 6 passed (SDK missing, disabled, init rejected, init timeout, gameplay events, leaderboard off) |
| `tool/build_crazygames.sh` | passed; 32 files, about 28MB; zip `build/slide-merge-crazygames.zip` |
| Bundle `index.html` | `<base href="./">`, SDK script once before the Flutter loader, no hub nav bar or bon-on link, nav height 0px |
| `flutter build web --release --base-href /SlideMerge/` | passed; no SDK script, hub nav bar kept |
| harness audit | Critical 0, Blocked no |

Not verified: upload to the CrazyGames portal and the portal QA tool (needs a developer account).
