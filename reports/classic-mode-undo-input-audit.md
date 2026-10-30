# Classic mode, undo twist, input - evidence

- Spec: feature-classic-mode-undo-input; contract: contract-classic-mode-undo-input
- `flutter analyze`: No issues found
- `flutter test`: 21 tests passed (game logic, best score store, widget/keyboard, web shell)
- `flutter build web --release --base-href /SlideMerge/`: built
- Screenshots (iframe-sized 1280x720 and 390x844): board, header, mode picker, undo, and hint fully visible, no overflow.
- Web shell: Flutter now hosts in `#game-host` below the hub nav bar (previously the nav covered the game header or clipped the bottom).
