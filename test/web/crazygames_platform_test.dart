// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:slide_merge/platform/crazygames_platform.dart';

/// Installs a fake `window.CrazyGames.SDK` and records the calls it receives.
class _FakeSdk {
  _FakeSdk({this.environment = 'local', this.initResult}) {
    settings.setProperty('muteAudio'.toJS, false.toJS);
    final game = JSObject()
      ..setProperty('settings'.toJS, settings)
      ..setProperty(
        'gameplayStart'.toJS,
        (() => calls.add('gameplayStart')).toJS,
      )
      ..setProperty(
        'gameplayStop'.toJS,
        (() => calls.add('gameplayStop')).toJS,
      )
      ..setProperty(
        'addSettingsChangeListener'.toJS,
        ((JSFunction listener) => settingsListener = listener).toJS,
      );
    final sdk = JSObject()
      ..setProperty('environment'.toJS, environment.toJS)
      ..setProperty('game'.toJS, game)
      ..setProperty(
        'init'.toJS,
        (() => (initResult ?? Future<void>.value()).toJS).toJS,
      );
    globalContext.setProperty(
      'CrazyGames'.toJS,
      JSObject()..setProperty('SDK'.toJS, sdk),
    );
  }

  final String environment;
  final Future<void>? initResult;
  final JSObject settings = JSObject();

  set muteAudio(bool value) =>
      settings.setProperty('muteAudio'.toJS, value.toJS);

  final List<String> calls = <String>[];
  JSFunction? settingsListener;

  /// Changes the setting the way the portal does and notifies the game.
  void changeMute(bool value) {
    muteAudio = value;
    settingsListener?.callAsFunction(null, settings);
  }
}

void _removeSdk() => globalContext.delete('CrazyGames'.toJS);

void main() {
  tearDown(_removeSdk);

  test('missing SDK falls back to no-op', () async {
    _removeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
  });

  test('disabled environment never calls the SDK', () async {
    final sdk = _FakeSdk(environment: 'disabled');
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('rejected init falls back to no-op', () async {
    final sdk = _FakeSdk(initResult: Future<void>.error('init failed'));
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('hung init times out and falls back to no-op', () async {
    final sdk = _FakeSdk(initResult: Completer<void>().future);
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('CrazyGames builds never offer leaderboard registration', () {
    expect(CrazyGamesPlatform().allowsResultRegistration, isFalse);
  });

  test('gameplay events reach the SDK', () async {
    final sdk = _FakeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    platform.gameplayStop();
    expect(sdk.calls, <String>['gameplayStart', 'gameplayStop']);
  });

  test('isAudioMuted follows the SDK muteAudio setting', () async {
    final sdk = _FakeSdk();
    final platform = CrazyGamesPlatform();
    expect(platform.isAudioMuted, isFalse);
    await platform.initialize();

    expect(platform.isAudioMuted, isFalse);
    sdk.muteAudio = true;
    expect(platform.isAudioMuted, isTrue);
    sdk.muteAudio = false;
    expect(platform.isAudioMuted, isFalse);
  });

  test('settings changes reach the mute listener', () async {
    final sdk = _FakeSdk();
    final platform = CrazyGamesPlatform();
    var notified = 0;
    platform.setAudioMuteListener(() => notified++);
    await platform.initialize();
    expect(sdk.settingsListener, isNotNull);

    sdk.changeMute(true);
    expect(notified, 1);
    expect(platform.isAudioMuted, isTrue);
    sdk.changeMute(false);
    expect(notified, 2);
    expect(platform.isAudioMuted, isFalse);

    platform.setAudioMuteListener(null);
    sdk.changeMute(true);
    expect(notified, 2);
  });
}
