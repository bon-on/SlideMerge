import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/game_platform.dart';
import 'web_sound_stub.dart' if (dart.library.js_interop) 'web_sound_web.dart';

/// Sound effects of the game. Each value maps to `assets/audio/<name>.wav`,
/// produced by `tool/generate_sounds.py`.
enum Sfx {
  slide,
  merge,
  undo,
  gameOver;

  /// Bundled file; camelCase names map to snake_case (`gameOver` ->
  /// `game_over.wav`).
  String get asset {
    final snake = name.replaceAllMapped(
      RegExp('[A-Z]'),
      (m) => '_${m[0]!.toLowerCase()}',
    );
    return 'assets/audio/$snake.wav';
  }
}

/// Backend that actually makes noise; tests substitute a recorder.
abstract class SoundPlayer {
  void play(String asset, double volume);

  void dispose();
}

/// Web: HTML audio elements. Native: the `slide_merge/audio` channel.
/// Every failure is swallowed so audio can never block input.
class PlatformSoundPlayer implements SoundPlayer {
  static const MethodChannel _channel = MethodChannel('slide_merge/audio');

  final WebSound _web = WebSound();

  @override
  void play(String asset, double volume) {
    if (kIsWeb) {
      _web.play(asset, volume);
      return;
    }
    _invoke('play', <String, Object>{'asset': asset, 'volume': volume});
  }

  @override
  void dispose() {
    if (!kIsWeb) _invoke('disposeAudio');
  }

  void _invoke(String method, [Object? arguments]) {
    try {
      unawaited(
        _channel
            .invokeMethod<void>(method, arguments)
            .then<void>(
              (_) {},
              onError: (Object _) {
                // MissingPluginException / PlatformException: audio is optional.
              },
            ),
      );
    } catch (_) {}
  }
}

/// Plays short sound effects and owns the persisted mute switch.
///
/// Effective mute = the player's own toggle OR the portal asking for silence
/// (`GamePlatform.isAudioMuted`).
class SoundFx extends ChangeNotifier {
  SoundFx({
    this.platform = const NoopGamePlatform(),
    SoundPlayer? player,
    Future<SharedPreferences> Function()? preferences,
  }) : _player = player ?? PlatformSoundPlayer(),
       _preferences = preferences ?? SharedPreferences.getInstance;

  /// `shared_preferences` key of the user's mute choice (default: sound on).
  static const String mutedKey = 'sound_muted_v1';

  static const double _volume = 0.7;

  final GamePlatform platform;
  final SoundPlayer _player;
  final Future<SharedPreferences> Function() _preferences;

  bool _userMuted = false;
  bool _touched = false;
  bool _disposed = false;

  /// The player's own choice, shown by the toggle button.
  bool get userMuted => _userMuted;

  /// Whether nothing is audible right now.
  bool get muted => _userMuted || _platformMuted;

  bool get _platformMuted {
    try {
      return platform.isAudioMuted;
    } catch (_) {
      return false;
    }
  }

  /// Reads the stored choice; a storage failure keeps sound on.
  Future<void> load() async {
    try {
      final stored = (await _preferences()).getBool(mutedKey);
      // A toggle made while the read was pending wins.
      if (_touched || _disposed || stored == null || stored == _userMuted) {
        return;
      }
      _userMuted = stored;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setUserMuted(bool value) async {
    _touched = true;
    if (value != _userMuted) {
      _userMuted = value;
      if (!_disposed) notifyListeners();
    }
    try {
      await (await _preferences()).setBool(mutedKey, value);
    } catch (_) {}
  }

  Future<void> toggle() => setUserMuted(!_userMuted);

  /// Fire-and-forget; silent when muted, never throws.
  void play(Sfx sfx) {
    if (_disposed || muted) return;
    try {
      _player.play(sfx.asset, _volume);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      _player.dispose();
    } catch (_) {}
    super.dispose();
  }
}
