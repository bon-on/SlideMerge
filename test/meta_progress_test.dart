import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slide_merge/src/meta/missions.dart';
import 'package:slide_merge/src/meta/sea_progress.dart';
import 'package:slide_merge/src/meta/sea_progress_store.dart';
import 'package:slide_merge/src/meta/sea_theme.dart';

void main() {
  group('SeaProgress', () {
    test('initial progress: level 1, plankton and shrimp found, lagoon', () {
      const p = SeaProgress.initial();
      expect(p.level, 1);
      expect(p.discovered, {1, 2});
      expect(p.selectedTheme, SeaTheme.lagoon);
      expect(p.isThemeUnlocked(SeaTheme.coral), isFalse);
    });

    test('level curve: 150 + 50 * (L - 1) per level', () {
      expect(SeaProgress.xpToAdvance(1), 150);
      expect(SeaProgress.xpToAdvance(3), 250);
      final p = const SeaProgress.initial().withXp(150 + 200 + 10);
      expect(p.level, 3);
      expect(p.xpIntoLevel, 10);
      expect(p.xpForNextLevel, 250);
      expect(p.isThemeUnlocked(SeaTheme.coral), isTrue);
      expect(p.isThemeUnlocked(SeaTheme.polar), isFalse);
    });

    test('applyRun adds score, mission and participation XP', () {
      const p = SeaProgress.initial();
      final o = p.applyRun(
        const RunSummary(
          score: 2000,
          highestPower: 8,
          moves: 30,
          missionXp: 50,
        ),
      );
      expect(o.xpGained, 100 + 50 + SeaProgress.participationXp);
      expect(o.progress.runs, 1);
      expect(o.progress.bestPower, 8);
      expect(o.progress.discovered, contains(8));
      expect(o.levelBefore, 1);
      expect(o.leveledUp, isTrue);
    });

    test('short runs skip participation XP; empty runs change nothing', () {
      const p = SeaProgress.initial();
      final short = p.applyRun(
        const RunSummary(score: 40, highestPower: 3, moves: 3),
      );
      expect(short.xpGained, 2);
      final empty = p.applyRun(
        const RunSummary(score: 0, highestPower: 2, moves: 0),
      );
      expect(empty.xpGained, 0);
      expect(identical(empty.progress, p), isTrue);
    });

    test('crossing a theme level reports it as unlocked', () {
      final p = const SeaProgress.initial().withXp(340);
      final o = p.applyRun(
        const RunSummary(score: 400, highestPower: 6, moves: 20),
      );
      expect(o.newlyUnlockedThemes, [SeaTheme.coral]);
    });

    test('withTile records album entries and the uncapped best tile', () {
      final p = const SeaProgress.initial().withTile(16);
      expect(p.bestPower, 16);
      expect(p.discovered, contains(14));
      expect(identical(p.withTile(2), p), isTrue);
    });

    test('locked themes cannot be selected', () {
      const p = SeaProgress.initial();
      expect(p.withTheme(SeaTheme.moonlit).selectedTheme, SeaTheme.lagoon);
      final rich = p.withXp(100000);
      expect(rich.withTheme(SeaTheme.moonlit).selectedTheme, SeaTheme.moonlit);
    });

    test('JSON round trip', () {
      final p = const SeaProgress.initial()
          .withXp(5000)
          .withTile(9)
          .withTheme(SeaTheme.polar);
      final back = SeaProgress.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(back.totalXp, p.totalXp);
      expect(back.discovered, p.discovered);
      expect(back.bestPower, 9);
      expect(back.selectedTheme, SeaTheme.polar);
    });

    test('corrupt fields fall back one by one', () {
      final p = SeaProgress.fromJson({
        'totalXp': 'lots',
        'discovered': [3, 'x', -4, 99, double.nan],
        'bestPower': -2,
        'selectedTheme': 'moonlit', // locked at level 1
      });
      expect(p.totalXp, 0);
      expect(p.discovered, {1, 2, 3, 14});
      expect(p.bestPower, 0);
      expect(p.selectedTheme, SeaTheme.lagoon);
      expect(SeaProgress.fromJson('nope').level, 1);
      expect(SeaProgress.fromJson(null).discovered, {1, 2});
    });
  });

  group('SeaProgressStore', () {
    test('missing and corrupt values load the initial progress', () async {
      SharedPreferences.setMockInitialValues({});
      expect((await const SeaProgressStore().load()).totalXp, 0);
      SharedPreferences.setMockInitialValues({
        SeaProgressStore.progressKey: '{not json',
      });
      expect((await const SeaProgressStore().load()).level, 1);
      SharedPreferences.setMockInitialValues({
        SeaProgressStore.progressKey: 42,
      });
      expect((await const SeaProgressStore().load()).level, 1);
    });

    test('save then load keeps the progress', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SeaProgressStore();
      await store.save(const SeaProgress.initial().withXp(777).withTile(7));
      final back = await store.load();
      expect(back.totalXp, 777);
      expect(back.discovered, contains(7));
    });
  });

  group('Missions', () {
    test('three different kinds with targets fitted to the board', () {
      for (var seed = 0; seed < 30; seed++) {
        final set = MissionSet.forRun(boardSize: 4, random: math.Random(seed));
        expect(set.missions, hasLength(3));
        expect(set.missions.map((m) => m.kind).toSet(), hasLength(3));
        for (final m in set.missions) {
          expect(m.completed, isFalse);
          expect(m.label, isNotEmpty);
          if (m.kind == MissionKind.combo) expect(m.target, greaterThan(2));
          if (m.kind == MissionKind.reachTile) {
            expect(m.target, greaterThanOrEqualTo(6));
          }
        }
      }
      final big = MissionSet.forRun(boardSize: 5, random: math.Random(1));
      expect(big.missions, hasLength(3));
    });

    test('progress never drops and completion is reported once', () {
      final set = MissionSet([
        const Mission(kind: MissionKind.merges, target: 5, xp: 30),
        const Mission(kind: MissionKind.combo, target: 3, xp: 50),
        const Mission(kind: MissionKind.reachTile, target: 6, xp: 80),
      ]);
      expect(set.update(const RunStats(merges: 3)), isEmpty);
      final done = set.update(const RunStats(merges: 5, bestCombo: 3));
      expect(done.map((m) => m.kind), [MissionKind.merges, MissionKind.combo]);
      // An undo lowers the stats; completed missions stay completed.
      expect(set.update(const RunStats(merges: 1)), isEmpty);
      expect(set.completedCount, 2);
      expect(set.earnedXp, 80);
      expect(set.missions[0].progressLabel, 'Done');
      expect(set.missions[2].progressLabel, '-');
      set.update(const RunStats(highestPower: 5));
      expect(set.missions[2].progressLabel, '32/64');
    });

    test('labels', () {
      expect(
        const Mission(kind: MissionKind.reachTile, target: 7, xp: 1).label,
        'Make a Crab (128)',
      );
      expect(
        const Mission(kind: MissionKind.score, target: 3000, xp: 1).label,
        'Score 3,000',
      );
    });
  });
}
