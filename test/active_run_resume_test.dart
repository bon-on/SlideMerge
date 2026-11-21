import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slide_merge/game_logic.dart';
import 'package:slide_merge/how_to_play.dart';
import 'package:slide_merge/main.dart';
import 'package:slide_merge/src/audio/sound_fx.dart';
import 'package:slide_merge/src/meta/active_run.dart';
import 'package:slide_merge/src/meta/missions.dart';
import 'package:slide_merge/src/meta/sea_progress.dart';
import 'package:slide_merge/src/meta/sea_progress_store.dart';

class Seen extends TutorialStore {
  @override
  Future<bool> hasSeen() async => true;
}

class Silent extends SoundPlayer {
  @override
  void play(String asset, double volume) {}
  @override
  void dispose() {}
}

ActiveRun run(SlideMergeGame game, {bool completed = false}) => ActiveRun(
  game: game,
  missions: MissionSet([
    Mission(
      kind: MissionKind.moves,
      target: 1,
      xp: 20,
      progress: completed ? 1 : 0,
    ),
    const Mission(kind: MissionKind.score, target: 100000, xp: 20),
    const Mission(kind: MissionKind.merges, target: 100000, xp: 20),
  ]),
  missionLevel: 1,
  highest: game.highestPower,
  merges: 0,
  bestCombo: 0,
  missionXp: completed ? 20 : 0,
  bestAtStart: 0,
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('both modes roundtrip board, counters and undo', () {
    for (final mode in GameMode.all) {
      final game = SlideMergeGame(mode: mode, random: Random(3));
      final before = game.toSnapshot();
      for (final d in Direction.values) {
        if (game.move(d)) break;
      }
      final saved = jsonDecode(jsonEncode(game.toSnapshot()));
      final restored = SlideMergeGame(mode: mode);
      expect(restored.restoreSnapshot(saved), isTrue);
      expect(restored.toSnapshot(), saved);
      expect(restored.undo(), isTrue);
      expect(restored.toSnapshot()['cells'], before['cells']);
      expect(restored.score, before['score']);
      expect(restored.moves, 0);
    }
  });
  test('corrupt snapshots reject atomically, including invalid undo', () {
    final game = SlideMergeGame(mode: GameMode.classic);
    final before = game.toSnapshot();
    for (final bad in [
      null,
      {'v': 2},
      {...before, 'cells': []},
      {...before, 'charges': -1},
      {
        ...before,
        'undo': {'moves': -1},
      },
      {...before, 'nextId': 1},
    ]) {
      expect(game.restoreSnapshot(bad), isFalse);
      expect(game.toSnapshot(), before);
    }
    expect(ActiveRun.restore({'v': 1, 'game': before}, totalXp: 0), isNull);
    final badMission = run(game).toJson();
    ((badMission['missions'] as List).first as Map)['xp'] = 20.0;
    expect(ActiveRun.restore(badMission, totalXp: 20), isNull);
  });
  test(
    'mission completion and session statistics survive JSON without new XP',
    () {
      final game = SlideMergeGame(mode: GameMode.relaxed);
      game.move(Direction.left);
      final progress = const SeaProgress.initial()
          .withXp(20)
          .withActiveRun(run(game, completed: true).toJson());
      final decoded = SeaProgress.fromJson(
        jsonDecode(jsonEncode(progress.toJson())),
      );
      final restored = ActiveRun.restore(
        decoded.activeRun,
        totalXp: decoded.totalXp,
      )!;
      expect(restored.game.mode.id, 'relaxed');
      expect(restored.missions.update(const RunStats(moves: 2)), isEmpty);
      expect(restored.missionXp, 20);
      expect(decoded.totalXp, 20);
    },
  );
  testWidgets('refresh restores relaxed board and undo; restart settles once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = SlideMergeGame(mode: GameMode.relaxed, random: Random(4));
    final initial = game.toSnapshot()['cells'];
    for (final d in Direction.values) {
      if (game.move(d)) break;
    }
    final store = MemorySeaProgressStore(
      const SeaProgress.initial()
          .withXp(20)
          .withActiveRun(run(game, completed: true).toJson()),
    );
    Future<void> mount() async {
      await tester.pumpWidget(
        MaterialApp(
          home: SlideMergeScreen(
            tutorialStore: Seen(),
            progressStore: store,
            soundFx: SoundFx(player: Silent()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mount();
    var restored = ActiveRun.restore(
      store.value.activeRun,
      totalXp: store.value.totalXp,
    )!;
    expect(restored.game.toSnapshot(), game.toSnapshot());
    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.pumpAndSettle();
    restored = ActiveRun.restore(
      store.value.activeRun,
      totalXp: store.value.totalXp,
    )!;
    expect(restored.game.toSnapshot()['cells'], initial);
    expect(restored.game.undoCharges, 0);
    expect(store.value.totalXp, 20);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Restart').first);
    await tester.pumpAndSettle();
    final xp = store.value.totalXp;
    expect(store.value.runs, 1);
    await tester.pumpWidget(const SizedBox());
    await mount();
    expect(store.value.runs, 1);
    expect(store.value.totalXp, xp);
  });

  Future<void> mountWith(WidgetTester tester, SeaProgressStore store) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SlideMergeScreen(
          tutorialStore: Seen(),
          progressStore: store,
          soundFx: SoundFx(player: Silent()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a corrupt saved attempt starts fresh and keeps meta progress', (
    tester,
  ) async {
    final store = MemorySeaProgressStore(
      const SeaProgress.initial().withXp(500).withActiveRun({'v': 99}),
    );
    final before = store.value;
    await mountWith(tester, store);
    final restored = ActiveRun.restore(
      store.value.activeRun,
      totalXp: store.value.totalXp,
    );
    expect(restored, isNotNull);
    expect(restored!.game.moves, 0);
    expect(store.value.totalXp, 500);
    expect(store.value.discovered, before.discovered);
    expect(store.value.runs, before.runs);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching mode replaces the saved attempt', (tester) async {
    final store = MemorySeaProgressStore();
    await mountWith(tester, store);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    final other = GameMode.all.firstWhere(
      (m) =>
          m.id !=
          ActiveRun.restore(
            store.value.activeRun,
            totalXp: store.value.totalXp,
          )!.game.mode.id,
    );
    await tester.tap(find.text(other.label).first);
    await tester.pumpAndSettle();
    final saved = ActiveRun.restore(
      store.value.activeRun,
      totalXp: store.value.totalXp,
    )!;
    expect(saved.game.mode.id, other.id);
    expect(saved.game.moves, 0);
  });
}
