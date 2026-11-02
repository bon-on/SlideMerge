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
  gameOver,
  combo,
  discover,
  mission,
  levelUp;

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

/// Background music backend: one looping track that can be paused.
abstract class MusicPlayer {
  /// Starts (or resumes) the loop. Completes with false when the platform
  /// refused (browser autoplay policy), so the caller can retry later.
  Future<bool> play(String asset, double volume);

  /// Pauses the loop (web keeps the position; native stops it).
  void pause();

  void dispose();
}

/// Web: a looping HTML audio element. Native: `startLoop` / `stopLoop` on the
/// `slide_merge/audio` channel. Failures are swallowed.
class PlatformMusicPlayer implements MusicPlayer {
  static const MethodChannel _channel = MethodChannel('slide_merge/audio');

  final WebSound _web = WebSound();

  @override
  Future<bool> play(String asset, double volume) async {
    if (kIsWeb) return _web.loop(asset, volume);
    try {
      await _channel.invokeMethod<void>('startLoop', <String, Object>{
        'asset': asset,
        'volume': volume,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void pause() {
    if (kIsWeb) {
      _web.pauseLoop();
      return;
    }
    _channel
        .invokeMethod<void>('stopLoop')
        .then<void>((_) {}, onError: (Object _) {});
  }

  @override
  void dispose() => pause();
}

/// Plays short sound effects and the music loop, and owns the persisted mute
/// switch (one toggle for both).
///
/// Effective mute = the player's own toggle OR the portal asking for silence
/// (`GamePlatform.isAudioMuted`).
class SoundFx extends ChangeNotifier {
  SoundFx({
    this.platform = const NoopGamePlatform(),
    SoundPlayer? player,
    MusicPlayer? music,
    bool? musicNeedsGesture,
    Future<SharedPreferences> Function()? preferences,
  }) : _player = player ?? PlatformSoundPlayer(),
       // A custom effects player (tests) gets no music unless given one.
       _music = music ?? (player == null ? PlatformMusicPlayer() : null),
       _needsGesture = musicNeedsGesture ?? kIsWeb,
       _preferences = preferences ?? SharedPreferences.getInstance;

  /// `shared_preferences` key of the user's mute choice (default: sound on).
  static const String mutedKey = 'sound_muted_v1';

  static const double _volume = 0.7;

  /// The background loop, produced by `tool/generate_sounds.py`.
  static const String musicAsset = 'assets/audio/music_loop.wav';
  static const double musicVolume = 0.4;

  final GamePlatform platform;
  final SoundPlayer _player;
  final MusicPlayer? _music;
  final bool _needsGesture;

  // Music: wanted by the game, app visible, first user input seen (web).
  bool _musicWanted = false;
  bool _appVisible = true;
  bool _userInteracted = false;
  bool _musicPlaying = false;

  // Bumped on every start/pause, so a late answer to an older start cannot
  // clear the flag of a newer one.
  int _musicRequest = 0;

  /// Whether the music loop is (believed to be) running.
  bool get isMusicPlaying => _musicPlaying;
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
      _applyMusic();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setUserMuted(bool value) async {
    _touched = true;
    if (value != _userMuted) {
      _userMuted = value;
      _applyMusic();
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

  /// Asks for background music; it plays once nothing holds it back.
  void startMusic() {
    _musicWanted = true;
    _applyMusic();
  }

  void stopMusic() {
    _musicWanted = false;
    _applyMusic();
  }

  /// The app or browser tab was hidden or shown.
  void setAppVisible(bool visible) {
    if (_appVisible == visible) return;
    _appVisible = visible;
    _applyMusic();
  }

  /// Any pointer or key input. Browsers only allow audio after the first one;
  /// a loop the browser refused earlier is retried.
  void onUserInput() {
    _userInteracted = true;
    if (!_musicPlaying) _applyMusic();
  }

  /// The platform mute (portal setting) may have changed.
  void refreshMute() {
    if (_disposed) return;
    _applyMusic();
    notifyListeners();
  }

  bool get _musicAllowed =>
      !_disposed &&
      _musicWanted &&
      !muted &&
      _appVisible &&
      (!_needsGesture || _userInteracted);

  void _applyMusic() {
    final music = _music;
    if (music == null) return;
    try {
      if (_musicAllowed) {
        if (_musicPlaying) return;
        _musicPlaying = true;
        final request = ++_musicRequest;
        music
            .play(musicAsset, musicVolume)
            .then<bool>((ok) => ok, onError: (Object _) => false)
            .then((ok) {
              if (!ok && request == _musicRequest) _musicPlaying = false;
            });
      } else if (_musicPlaying) {
        _musicRequest++;
        _musicPlaying = false;
        music.pause();
      }
    } catch (_) {
      _musicPlaying = false;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      _player.dispose();
    } catch (_) {}
    try {
      _musicPlaying = false;
      _music?.dispose();
    } catch (_) {}
    super.dispose();
  }
}
