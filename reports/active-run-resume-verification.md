# Active run resume verification — 2026-11-22

Base commit: `9079910` plus the active-run-resume working tree committed with this report.

| Check | Command | Result |
|---|---|---|
| Analyze | `flutter analyze` | exit 0, no issues |
| Tests | `flutter test` | exit 0, 162 passed |
| Pages build | `flutter build web --release --base-href /SlideMerge/` | exit 0, no CrazyGames SDK in `index.html` |
| CrazyGames build | `bash tool/build_crazygames.sh` | exit 0; `build/slide-merge-crazygames.zip` 12.5 MB |
| GamePix build | `bash tool/build_gamepix.sh` | exit 0; `build/slide-merge-gamepix.zip` 12.5 MB |
| Harness audit | `node <harness-lab>/dist/index.js audit . --format md` | exit 0, Critical 0, warnings 3 |
| Independent review | code-reviewer | approve with comments, no Critical/High |

Review follow-ups: the evidence path now points here; the lifecycle pause shipped with this change is described in `feature-slide-merge-crazygames.md`.

Not verified: real portal QA (iframe focus, cloud save on a signed-in account) and native devices.
