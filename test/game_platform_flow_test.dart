import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slide_merge/game_logic.dart';
import 'package:slide_merge/how_to_play.dart';
import 'package:slide_merge/main.dart';
import 'package:slide_merge/platform/game_platform.dart';

class _FakeStore extends TutorialStore {
  _FakeStore({this.seen = false});
  bool seen;
  @override
  Future<bool> hasSeen() async => seen;
  @override
  Future<void> markSeen() async => seen = true;
}

class _FakePlatform extends GamePlatform {
  _FakePlatform({this.allowsResultRegistration = false});

  @override
  final bool allowsResultRegistration;

  final List<String> events = <String>[];

  @override
  Future<void> initialize() async {}

  @override
  void gameplayStart() => events.add('start');

  @override
  void gameplayStop() => events.add('stop');
}

/// Classic board that is one move (slide right) from game over: a checkerboard
/// of powers 3 and 4 over a bottom row of 5, 6, 5 and an empty last cell, so
/// the spawned tile cannot merge with anything.
SlideMergeGame _nearGameOver(GameMode mode) {
  final game = SlideMergeGame(mode: mode, random: math.Random(1));
  if (mode.id != GameMode.classic.id) return game;
  var id = 100;
  game.cells = [
    for (var i = 0; i < 16; i++)
      if (i == 15)
        null
      else if (i >= 12)
        Tile(id: id++, power: i.isEven ? 5 : 6)
      else
        Tile(id: id++, power: (i ~/ 4 + i % 4).isEven ? 3 : 4),
  ];
  return game;
}

Future<void> _pump(
  WidgetTester tester,
  _FakePlatform platform,
  TutorialStore store,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: SlideMergeScreen(
        tutorialStore: store,
        platform: platform,
        gameFactory: _nearGameOver,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _slideRight(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('seen tutorial: gameplay starts once the check resolves', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _FakeStore(seen: true));
    expect(platform.events, <String>['start']);
  });

  testWidgets('first launch starts only after the overlay closes', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _FakeStore());
    expect(find.text('How to play'), findsOneWidget);
    expect(platform.events, isEmpty);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(platform.events, <String>['start']);
  });

  testWidgets('reopening the overlay stops then restarts, no duplicates', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _FakeStore(seen: true));

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop']);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop']);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(platform.events, <String>['start', 'stop', 'start']);
  });

  testWidgets('game over stops, undo and restart start again', (tester) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _FakeStore(seen: true));

    await _slideRight(tester);
    expect(find.textContaining('No moves left'), findsOneWidget);
    expect(platform.events, <String>['start', 'stop']);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.pump(const Duration(milliseconds: 300));
    expect(platform.events, <String>['start', 'stop', 'start']);

    await _slideRight(tester);
    expect(platform.events, <String>['start', 'stop', 'start', 'stop']);

    await tester.tap(find.byTooltip('Restart'));
    await tester.pump();
    expect(platform.events, <String>[
      'start',
      'stop',
      'start',
      'stop',
      'start',
    ]);

    // Restarting mid-run adds no events.
    await tester.tap(find.byTooltip('Restart'));
    await tester.pump();
    expect(platform.events, hasLength(5));
  });

  testWidgets('leaderboard prompt follows the platform', (tester) async {
    for (final allowed in <bool>[true, false]) {
      final platform = _FakePlatform(allowsResultRegistration: allowed);
      await _pump(tester, platform, _FakeStore(seen: true));
      await _slideRight(tester);
      await tester.tap(find.byTooltip('Restart'));
      await tester.pumpAndSettle();
      expect(
        find.text('기록을 등록할까요?'),
        allowed ? findsOneWidget : findsNothing,
        reason: 'allowsResultRegistration: $allowed',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  test('default platform is a no-op that allows the leaderboard', () {
    const platform = NoopGamePlatform();
    expect(platform.allowsResultRegistration, isTrue);
    platform.gameplayStart();
    platform.gameplayStop();
  });
}
