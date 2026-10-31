import 'package:flutter_test/flutter_test.dart';
import 'package:slide_merge/platform/game_platform.dart';

void main() {
  test('default no-op platform allows result registration', () {
    expect(const NoopGamePlatform().allowsResultRegistration, isTrue);
  });

  test('GamePix no-op platform disables result registration', () async {
    const platform = NoopGamePlatform(allowsResultRegistration: false);
    expect(platform.allowsResultRegistration, isFalse);
    await platform.initialize();
    platform.gameplayStart();
    platform.gameplayStop();
  });
}
