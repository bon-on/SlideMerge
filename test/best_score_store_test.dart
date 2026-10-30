import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slide_merge/best_score_store.dart';

void main() {
  test('best score is stored per mode', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await BestScoreStore.load('classic'), 0);
    await BestScoreStore.save('classic', 120);
    await BestScoreStore.save('relaxed', 40);
    expect(await BestScoreStore.load('classic'), 120);
    expect(await BestScoreStore.load('relaxed'), 40);
  });

  test('a lower score never overwrites the stored best', () async {
    SharedPreferences.setMockInitialValues({'best_score_classic': 500});
    await BestScoreStore.save('classic', 20);
    expect(await BestScoreStore.load('classic'), 500);
  });
}
