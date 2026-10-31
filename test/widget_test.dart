import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slide_merge/game_logic.dart';
import 'package:slide_merge/main.dart';

class _FixedRandom implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.99;
  @override
  int nextInt(int max) => 0;
}

/// Classic board that is full and has no merges, except an optional last pair.
SlideMergeGame _stuckGame(GameMode mode, {int charges = 0}) {
  final g = SlideMergeGame(mode: mode, random: _FixedRandom());
  if (mode.id == GameMode.classic.id) {
    for (var i = 0; i < 16; i++) {
      final p = ((i ~/ 4) + (i % 4)) % 2 == 0 ? 1 : 2;
      g.cells[i] = Tile(id: 100 + i, power: p);
    }
    g.score = 123;
  }
  g.undoCharges = charges;
  return g;
}

Widget _app(SlideMergeGame Function(GameMode) factory) =>
    MaterialApp(home: SlideMergeScreen(gameFactory: factory));

int _tileCount(WidgetTester t) =>
    find.byType(AnimatedPositioned).evaluate().length;

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({'tutorial_seen_v1': true}),
  );

  testWidgets('Slide Merge renders the game board', (tester) async {
    await tester.pumpWidget(const SlideMergeApp());
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Slide Merge'), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
    expect(find.text('Classic 4x4'), findsOneWidget);
    expect(find.text('Relaxed 5x5'), findsOneWidget);
    expect(find.text('Moves'), findsOneWidget);
  });

  testWidgets('keyboard moves the board', (tester) async {
    await tester.pumpWidget(
      _app((m) => SlideMergeGame(mode: m, random: math.Random(1))),
    );
    await tester.pump();
    expect(find.text('0'), findsWidgets); // moves counter starts at 0
    for (final key in [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.keyS,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump(const Duration(milliseconds: 300));
    }
    final moves = tester.widget<Text>(
      find
          .descendant(
            of: find
                .ancestor(of: find.text('Moves'), matching: find.byType(Column))
                .first,
            matching: find.byType(Text),
          )
          .last,
    );
    expect(int.parse(moves.data!), greaterThan(0));
  });

  testWidgets('slow swipe moves the board', (tester) async {
    await tester.pumpWidget(
      _app((m) => SlideMergeGame(mode: m, random: math.Random(1))),
    );
    await tester.pump();
    final before = _tileCount(tester);
    await tester.drag(
      find.byType(AnimatedPositioned).first,
      const Offset(40, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final moves = tester.widget<Text>(
      find
          .descendant(
            of: find
                .ancestor(of: find.text('Moves'), matching: find.byType(Column))
                .first,
            matching: find.byType(Text),
          )
          .last,
    );
    expect(int.parse(moves.data!), 1);
    expect(_tileCount(tester), before + 1); // one spawn after the move
  });

  group('leaderboard offer', () {
    Future<void> pumpStuck(
      WidgetTester tester, {
      int charges = 0,
      bool alreadyOver = false,
    }) async {
      await tester.pumpWidget(_app((m) => _stuckGame(m, charges: charges)));
      await tester.pump();
    }

    // The stuck board has no legal move, so a move never fires; drive the
    // offer through restart / mode switch (force) or a real finishing move.
    testWidgets('restart on a finished Classic run offers exactly once', (
      tester,
    ) async {
      await pumpStuck(tester, charges: 1);
      expect(find.text('기록을 등록할까요?'), findsNothing);
      await tester.tap(find.byTooltip('Restart'));
      await tester.pumpAndSettle();
      expect(find.text('기록을 등록할까요?'), findsOneWidget);
      expect(find.text('이번 기록: 123점'), findsOneWidget);
      await tester.tap(find.text('아니요'));
      await tester.pumpAndSettle();
      expect(find.text('기록을 등록할까요?'), findsNothing);
      // A fresh board is not game over, so a second restart offers nothing.
      await tester.tap(find.byTooltip('Restart'));
      await tester.pumpAndSettle();
      expect(find.text('기록을 등록할까요?'), findsNothing);
    });

    testWidgets('mode switch on a finished Classic run offers it', (
      tester,
    ) async {
      await pumpStuck(tester, charges: 1);
      await tester.tap(find.text('Relaxed 5x5'));
      await tester.pumpAndSettle();
      expect(find.text('이번 기록: 123점'), findsOneWidget);
    });

    testWidgets('finishing move with no charge offers; with charge defers', (
      tester,
    ) async {
      // One empty cell: moving up shifts column 0, the spawn fills the
      // board and no merges remain -> game over after the move.
      SlideMergeGame nearOver(GameMode m, int charges) {
        final g = _stuckGame(m, charges: charges);
        // Unique powers everywhere: nothing can merge, spawns are power 1.
        for (var i = 0; i < 16; i++) {
          g.cells[i] = i == 0 ? null : Tile(id: 200 + i, power: i + 1);
        }
        return g;
      }

      for (final charges in [1, 0]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(_app((m) => nearOver(m, charges)));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        final offered = find.text('기록을 등록할까요?').evaluate().isNotEmpty;
        expect(offered, charges == 0, reason: 'charges=$charges');
        if (offered) {
          await tester.tap(find.text('아니요'));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Relaxed never offers', (tester) async {
      await tester.pumpWidget(
        _app((m) => SlideMergeGame(mode: m, random: _FixedRandom())),
      );
      await tester.pump();
      await tester.tap(find.text('Relaxed 5x5'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Restart'));
      await tester.pumpAndSettle();
      expect(find.text('기록을 등록할까요?'), findsNothing);
    });
  });
}
