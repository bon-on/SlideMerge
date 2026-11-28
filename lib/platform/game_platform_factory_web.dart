import 'crazygames_platform.dart';
import 'game_platform.dart';
import 'gamepix_platform.dart';

const bool _crazyGamesBuild = bool.fromEnvironment('CRAZYGAMES');
const bool _gamePixBuild = bool.fromEnvironment('GAMEPIX');

/// Picks the portal adapter. CrazyGames wins over GamePix
/// (feature-gamepix-sdk).
GamePlatform selectGamePlatform({
  required bool crazyGames,
  required bool gamePix,
}) {
  if (crazyGames) return CrazyGamesPlatform();
  if (gamePix) return GamePixPlatform();
  return const NoopGamePlatform();
}

GamePlatform createGamePlatform() =>
    selectGamePlatform(crazyGames: _crazyGamesBuild, gamePix: _gamePixBuild);
