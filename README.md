# Slide Merge

A compact sliding merge puzzle (2048-style) built with Flutter for iOS, Android, and web.

## Gameplay

- **Modes**: Classic 4x4 (default, 90% / 10% spawns, tense) and Relaxed 5x5 (roomier, 82% / 18% spawns).
- **Twist - undo charge**: you hold one undo charge. Spend it to take back your last move; it recharges every 20 merges.
- **Controls**: swipe (any deliberate drag of 24 px or more), arrow keys, or WASD. `Z` / `U` undoes.
- **Best score** is saved locally per mode.
- Classic scores can be submitted to the opt-in leaderboard at game over.

## Development

```sh
flutter pub get
flutter run -d chrome
flutter analyze
flutter test
```

Game rules live in `lib/game_logic.dart` (widget-free, injectable `Random`) and are unit tested in `test/game_logic_test.dart`.

## Local Web Build

```sh
flutter build web --release --base-href /SlideMerge/
```

GitHub Pages deploys from `.github/workflows/deploy-pages.yml`.
