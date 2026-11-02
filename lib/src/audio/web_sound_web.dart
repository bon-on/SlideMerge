import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

/// Plays bundled sound assets with browser audio elements on web builds.
class WebSound {
  final Map<String, _Audio> _cache = <String, _Audio>{};

  // Dedicated element for the music loop so effects never touch it.
  _Audio? _loop;
  String? _loopKey;

  /// Starts or resumes [assetKey] on repeat. False when the browser refuses.
  Future<bool> loop(String assetKey, double volume) async {
    try {
      if (_loopKey != assetKey || _loop == null) {
        _loop?.pause();
        _loop = _Audio(ui_web.assetManager.getAssetUrl(assetKey));
        _loopKey = assetKey;
      }
      final audio = _loop!;
      audio.loop = true;
      audio.volume = volume;
      await audio.play().toDart;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Pauses the loop, keeping its position.
  void pauseLoop() {
    try {
      _loop?.pause();
    } catch (_) {}
  }

  void play(String assetKey, double volume) {
    try {
      final audio = _cache.putIfAbsent(
        assetKey,
        () => _Audio(ui_web.assetManager.getAssetUrl(assetKey)),
      );
      audio.volume = volume;
      audio.currentTime = 0;
      // Rejections (autoplay policy, decode errors) must not break input.
      audio.play().toDart.ignore();
    } catch (_) {}
  }
}

@JS('Audio')
extension type _Audio._(JSObject _) implements JSObject {
  external factory _Audio(String src);
  external JSPromise<JSAny?> play();
  external void pause();
  external set loop(bool value);
  external set currentTime(num value);
  external set volume(num value);
}
