import 'package:shared_preferences/shared_preferences.dart';

/// Local best score per game mode id. Failures degrade to "no stored score".
class BestScoreStore {
  static String _key(String modeId) => 'best_score_$modeId';

  static Future<int> load(String modeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_key(modeId)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> save(String modeId, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(modeId), value);
    } catch (_) {}
  }
}
