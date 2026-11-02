import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sea_progress.dart';

/// Persists [SeaProgress] as JSON under [progressKey].
///
/// Storage failures never break play: a read failure or a corrupt value
/// loads the initial progress and a write failure is ignored.
class SeaProgressStore {
  const SeaProgressStore();

  static const String progressKey = 'slide_merge_progress_v1';

  Future<SeaProgress> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(progressKey);
      if (raw == null) return const SeaProgress.initial();
      return SeaProgress.fromJson(jsonDecode(raw));
    } catch (_) {
      return const SeaProgress.initial();
    }
  }

  Future<void> save(SeaProgress progress) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(progressKey, jsonEncode(progress.toJson()));
    } catch (_) {}
  }
}

/// In-memory store for tests.
class MemorySeaProgressStore extends SeaProgressStore {
  MemorySeaProgressStore([this.value = const SeaProgress.initial()]);

  SeaProgress value;
  int saveCount = 0;

  @override
  Future<SeaProgress> load() async => value;

  @override
  Future<void> save(SeaProgress progress) async {
    value = progress;
    saveCount += 1;
  }
}
