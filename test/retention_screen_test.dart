import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slide_merge/game_logic.dart';
import 'package:slide_merge/how_to_play.dart';
import 'package:slide_merge/main.dart';
import 'package:slide_merge/platform/game_platform.dart';
import 'package:slide_merge/src/audio/sound_fx.dart';
import 'package:slide_merge/src/meta/sea_progress.dart';
import 'package:slide_merge/src/meta/sea_progress_store.dart';
import 'package:slide_merge/src/meta/sea_theme.dart';

class _Seen extends TutorialStore {
  @override
  Future<bool> hasSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

class _Player implements SoundPlayer {
  final List<String> played = <String>[];
  @override
  void play(String asset, double volume) => played.add(asset);
  @override
  void dispose() {}
}

class _Music implements MusicPlayer {
  final List<String> calls = <String>[];
  @override
  Future<bool> play(String asset, double volume) async {
    calls.add('play');
    return true;
  }

  @override
  void pause() => calls.add('pause');
  @override
  void dispose() => calls.add('dispose');
}

/// Store whose load waits for [gate].
class _SlowStore extends MemorySeaProgressStore {
  _SlowStore(super.value);
  final Completer<void> gate = Completer<void>();
  @override
  Future<SeaProgress> load() async {
    await gate.future;
    return value;
  }
}

class _Fixed implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.99;
  @override
  int nextInt(int max) => 0;
}

SlideMergeGame Function(GameMode) _board(List<int> powers, {int charges = 1}) =>
    (mode) {
      final g = SlideMergeGame(mode: mode, random: _Fixed());
      if (mode.id == GameMode.classic.id) {
        for (var i = 0; i < 16; i++) {
          g.cells[i] = powers[i] == 0
              ? null
              : Tile(id: 100 + i, power: powers[i]);
        }
        g.undoCharges = charges;
      }
      return g;
    };

/// Sliding right ends the run: the spawn fills the last cell, nothing merges.
final _endingBoard = _board([
  3, 4, 3, 4, //
  4, 3, 4, 3,
  3, 4, 3, 4,
  5, 6, 5, 0,
], charges: 0);

// Two 16s merge into a 32 (Pufferfish), not in the default album.
final _discoverBoard = _board([4, 4, ...List.filled(14, 0)]);

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1280, 720),
  required SlideMergeGame Function(GameMode) factory,
  SeaProgressStore? store,
  SoundFx? sound,
  int missionSeed = 4,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: SlideMergeScreen(
        tutorialStore: _Seen(),
        gameFactory: factory,
        progressStore: store ?? MemorySeaProgressStore(),
        soundFx: sound ?? SoundFx(player: _Player()),
        missionRandom: math.Random(missionSeed),
        // Portal-style: no leaderboard dialog on top of the summary.
        platform: const NoopGamePlatform(allowsResultRegistration: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

int _moves(WidgetTester tester) => int.parse(
  tester
      .widget<Text>(
        find
            .descendant(
              of: find
                  .ancestor(
                    of: find.text('Moves'),
                    matching: find.byType(Column),
                  )
                  .first,
              matching: find.byType(Text),
            )
            .last,
      )
      .data!,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [
    Size(1280, 720),
    Size(1366, 768),
    Size(844, 390),
    Size(390, 844),
    Size(320, 900),
  ]) {
    testWidgets('screen fits at $size with missions and level', (tester) async {
      await _pump(
        tester,
        size: size,
        factory: (m) => SlideMergeGame(mode: m, random: math.Random(1)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Slide Merge'), findsOneWidget);
      expect(find.textContaining('Lv 1'), findsWidgets);
      expect(find.byTooltip('Album'), findsOneWidget);
      // Each mission label is visible once.
      expect(
        find.textContaining(RegExp('Merge|Combo|Score|Make')),
        findsWidgets,
      );
    });

    testWidgets('run summary fits at $size', (tester) async {
      await _pump(tester, size: size, factory: _endingBoard);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No moves left!'), findsOneWidget);
      expect(find.text('Play again'), findsOneWidget);
    });
  }

  testWidgets('summary: XP saved, Esc closes, Enter plays again', (
    tester,
  ) async {
    final store = MemorySeaProgressStore();
    await _pump(tester, factory: _endingBoard, store: store);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('No moves left!'), findsOneWidget);
    expect(store.value.runs, 1);
    expect(find.textContaining('XP'), findsWidgets);

    // Board keys are blocked while the card is open.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.pump();
    expect(_moves(tester), 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('No moves left!'), findsNothing);
    expect(find.textContaining('Start a fresh board'), findsOneWidget);

    // Restart (the run was already counted, so no second XP).
    await tester.tap(find.byTooltip('Restart'));
    await tester.pumpAndSettle();
    expect(store.value.runs, 1);
    expect(_moves(tester), 0);
  });

  testWidgets('Enter on the summary starts a new run', (tester) async {
    await _pump(tester, factory: _endingBoard);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('No moves left!'), findsNothing);
    expect(_moves(tester), 0);
  });

  testWidgets('restarting mid-run awards XP once and shows it', (tester) async {
    final store = MemorySeaProgressStore();
    await _pump(
      tester,
      factory: _discoverBoard,
      store: store,
      missionSeed: 0, // no mission completes on this single merge
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Restart'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.value.runs, 1);
    expect(store.value.totalXp, 1); // 32 points / 20
    expect(find.text('+1 XP'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Restart'));
    await tester.pumpAndSettle();
    expect(store.value.runs, 1);
  });

  testWidgets('a new creature is celebrated, recorded and sounds', (
    tester,
  ) async {
    final store = MemorySeaProgressStore();
    final player = _Player();
    await _pump(
      tester,
      factory: _discoverBoard,
      store: store,
      sound: SoundFx(player: player),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('New creature!'), findsOneWidget);
    expect(player.played, ['assets/audio/discover.wav']);
    expect(store.value.discovered, contains(5));
    expect(store.value.bestPower, 5);
    await tester.pumpAndSettle();
    expect(find.text('New creature!'), findsNothing);
  });

  testWidgets('mission XP is saved the moment a mission completes', (
    tester,
  ) async {
    final store = MemorySeaProgressStore();
    // Four merges in one move complete the x3 combo mission.
    await _pump(
      tester,
      factory: _board([1, 1, 2, 2, 3, 3, 0, 0, 4, 4, 0, 0, 0, 0, 0, 0]),
      store: store,
      missionSeed: 0, // Lv1: combo x2, score 500, 60 moves
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Mission complete'), findsOneWidget);
    expect(store.value.totalXp, 20);
    expect(store.value.runs, 0); // the run itself is not over

    // Restart banks the run; the mission XP is counted once.
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Restart'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.value.runs, 1);
    expect(store.value.totalXp, 20 + (4 + 8 + 16 + 32) ~/ 20);
    expect(find.text('+23 XP'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a Lv1 run gets newcomer missions; a Lv10 run harder ones', (
    tester,
  ) async {
    await _pump(
      tester,
      factory: (m) => SlideMergeGame(mode: m, random: math.Random(1)),
      missionSeed: 0,
    );
    expect(find.text('Combo x2 in one move'), findsOneWidget);
    expect(find.text('Score 500'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await _pump(
      tester,
      factory: (m) => SlideMergeGame(mode: m, random: math.Random(1)),
      store: MemorySeaProgressStore(const SeaProgress.initial().withXp(5000)),
      missionSeed: 0,
    );
    expect(find.text('Combo x2 in one move'), findsNothing);
    expect(find.text('Score 500'), findsNothing);
    expect(find.textContaining(RegExp(r'x3|Score [2-5],')), findsWidgets);
  });

  testWidgets('combo banner for two merges in one move', (tester) async {
    await _pump(tester, factory: _board([1, 1, 2, 2, ...List.filled(12, 0)]));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Combo x2'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('input right after a move applies at once', (tester) async {
    await _pump(
      tester,
      factory: (m) => SlideMergeGame(mode: m, random: math.Random(7)),
    );
    for (final key in [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(_moves(tester), 3);
    await tester.pumpAndSettle();
  });

  testWidgets('changes before the stored progress loads are merged', (
    tester,
  ) async {
    final store = _SlowStore(
      const SeaProgress.initial().withXp(500).withTile(9),
    );
    await _pump(
      tester,
      factory: _discoverBoard,
      store: store,
      missionSeed: 0, // no mission XP in this move
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.saveCount, 0);
    store.gate.complete();
    await tester.pumpAndSettle();
    expect(store.saveCount, 1);
    expect(store.value.totalXp, 500);
    expect(store.value.discovered, containsAll(<int>[5, 9]));
    expect(store.value.bestPower, 9);
  });

  testWidgets('album: opens, blocks the board, picks unlocked themes only', (
    tester,
  ) async {
    final store = MemorySeaProgressStore(
      const SeaProgress.initial().withXp(400), // level 3: Coral Reef
    );
    await _pump(
      tester,
      factory: (m) => SlideMergeGame(mode: m, random: math.Random(1)),
      store: store,
    );
    await tester.tap(find.byTooltip('Album'));
    await tester.pumpAndSettle();
    expect(find.text('Creature Album'), findsOneWidget);
    expect(find.text('Plankton'), findsWidgets);
    expect(find.text('???'), findsNWidgets(12));
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_moves(tester), 0);

    await tester.tap(find.text('Moonlit Deep'));
    await tester.pump();
    expect(store.value.selectedTheme, SeaTheme.lagoon);
    await tester.tap(find.text('Coral Reef'));
    await tester.pump();
    expect(store.value.selectedTheme, SeaTheme.coral);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Creature Album'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_moves(tester), greaterThan(0));
  });

  testWidgets('the screen asks for music and the toggle stops it', (
    tester,
  ) async {
    final music = _Music();
    final fx = SoundFx(
      player: _Player(),
      music: music,
      musicNeedsGesture: false,
    );
    await _pump(
      tester,
      factory: (m) => SlideMergeGame(mode: m, random: math.Random(1)),
      sound: fx,
    );
    expect(music.calls, ['play']);
    await tester.tap(find.byTooltip('Sound on'));
    await tester.pump();
    expect(music.calls, ['play', 'pause']);
  });
}
