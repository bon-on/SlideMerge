# How-to-play tutorial verification

- Spec: harness/specs/feature-how-to-play-tutorial.md
- `flutter analyze`: no issues.
- `flutter test`: all pass (see test/how_to_play_test.dart for overlay, skip,
  keyboard blocking, persistence, reopen and layout checks).
- `flutter build web --release --base-href /SlideMerge/`: succeeds.
- Not verified: manual run in a real browser or device.
