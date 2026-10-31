// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:slide_merge/platform/crazygames_platform.dart';
import 'package:slide_merge/platform/game_platform.dart';
import 'package:slide_merge/platform/game_platform_factory_web.dart';

void main() {
  test('default web build keeps the no-op platform with registration', () {
    final platform = selectGamePlatform(crazyGames: false, gamePix: false);
    expect(platform, isA<NoopGamePlatform>());
    expect(platform.allowsResultRegistration, isTrue);
  });

  test('GamePix build is a no-op without result registration', () {
    final platform = selectGamePlatform(crazyGames: false, gamePix: true);
    expect(platform, isA<NoopGamePlatform>());
    expect(platform.allowsResultRegistration, isFalse);
  });

  test('CrazyGames adapter is only selected for CRAZYGAMES', () {
    expect(
      selectGamePlatform(crazyGames: true, gamePix: false),
      isA<CrazyGamesPlatform>(),
    );
    expect(
      selectGamePlatform(crazyGames: false, gamePix: true),
      isNot(isA<CrazyGamesPlatform>()),
    );
  });
}
