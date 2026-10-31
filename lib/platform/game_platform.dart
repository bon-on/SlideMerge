import 'game_platform_factory_stub.dart'
    if (dart.library.js_interop) 'game_platform_factory_web.dart'
    as platform_factory;

/// Hooks a distribution portal needs from the game loop.
///
/// Mobile and plain web builds use [NoopGamePlatform]; CrazyGames web builds
/// (`--dart-define=CRAZYGAMES=true`) use the SDK-backed implementation.
abstract class GamePlatform {
  const GamePlatform();

  Future<void> initialize();

  /// The player is actively playing (no overlay, run not over).
  void gameplayStart();

  /// The player stopped playing (overlay open, run over).
  void gameplayStop();

  /// Whether the post-game prompt to submit results to the Bon-on leaderboard
  /// may be shown. Portal builds keep players on the portal.
  bool get allowsResultRegistration;
}

class NoopGamePlatform extends GamePlatform {
  const NoopGamePlatform();

  @override
  Future<void> initialize() async {}

  @override
  void gameplayStart() {}

  @override
  void gameplayStop() {}

  @override
  bool get allowsResultRegistration => true;
}

GamePlatform createGamePlatform() => platform_factory.createGamePlatform();
