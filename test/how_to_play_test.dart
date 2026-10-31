import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slide_merge/game_logic.dart';
import 'package:slide_merge/how_to_play.dart';
import 'package:slide_merge/main.dart';

class _FakeStore extends TutorialStore {
  _FakeStore({this.seen = false});
  bool seen;
  @override
  Future<bool> hasSeen() async => seen;
  @override
  Future<void> markSeen() async => seen = true;
}

Future<void> _pump(
  WidgetTester tester,
  TutorialStore store, {
  Size size = const Size(800, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: SlideMergeScreen(
        tutorialStore: store,
        gameFactory: (m) => SlideMergeGame(mode: m, random: math.Random(1)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

int _moves(WidgetTester tester) {
  final text = tester.widget<Text>(
    find
        .descendant(
          of: find
              .ancestor(of: find.text('Moves'), matching: find.byType(Column))
              .first,
          matching: find.byType(Text),
        )
        .last,
  );
  return int.parse(text.data!);
}

Future<void> _slide(WidgetTester tester) async {
  for (final key in [
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowDown,
  ]) {
    await tester.sendKeyEvent(key);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

class _SlowStore extends TutorialStore {
  final Completer<void> release = Completer<void>();
  @override
  Future<bool> hasSeen() async {
    await release.future;
    return false;
  }

  @override
  Future<void> markSeen() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first launch shows the overlay and blocks keys and swipes', (
    tester,
  ) async {
    await _pump(tester, _FakeStore());
    expect(find.text('How to play'), findsOneWidget);
    await _slide(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.pump(const Duration(milliseconds: 300));
    // Overlay navigation keys must not have closed it or moved tiles.
    expect(_moves(tester), 0);
    await tester.dragFrom(const Offset(400, 600), const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_moves(tester), 0);
  });

  testWidgets('Next walks the steps and Play stores the flag', (tester) async {
    final store = _FakeStore();
    await _pump(tester, store);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsNothing);
    expect(store.seen, isTrue);
    // Keys reach the game again after closing.
    await _slide(tester);
    expect(_moves(tester), greaterThan(0));
  });

  testWidgets('Skip and Escape close and store the flag', (tester) async {
    final store = _FakeStore();
    await _pump(tester, store);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsNothing);
    expect(store.seen, isTrue);

    final escStore = _FakeStore();
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, escStore);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsNothing);
    expect(escStore.seen, isTrue);
  });

  testWidgets('arrows step through and Enter finishes', (tester) async {
    final store = _FakeStore();
    await _pump(tester, store);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('Next'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('no overlay when the flag is set', (tester) async {
    await _pump(tester, _FakeStore(seen: true));
    expect(find.text('How to play'), findsNothing);
  });

  testWidgets('real store persists the flag in shared_preferences', (
    tester,
  ) async {
    await _pump(tester, const TutorialStore());
    expect(find.text('How to play'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(await const TutorialStore().hasSeen(), isTrue);
  });

  testWidgets('input is ignored while the first-run check is pending', (
    tester,
  ) async {
    final store = _SlowStore();
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SlideMergeScreen(
          tutorialStore: store,
          gameFactory: (m) => SlideMergeGame(mode: m, random: math.Random(1)),
        ),
      ),
    );
    await _slide(tester);
    await tester.dragFrom(const Offset(400, 600), const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_moves(tester), 0);

    store.release.complete();
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await _slide(tester);
    expect(_moves(tester), greaterThan(0));
  });

  testWidgets('F5 and Ctrl shortcuts are not swallowed by the card', (
    tester,
  ) async {
    await _pump(tester, _FakeStore());
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('How to play'), findsOneWidget);
  });

  testWidgets('Ctrl combos and key repeat do not move the game', (
    tester,
  ) async {
    await _pump(tester, _FakeStore(seen: true));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_moves(tester), 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_moves(tester), lessThanOrEqualTo(1));
  });

  testWidgets('? reopens at step 1 without resetting the game', (tester) async {
    await _pump(tester, _FakeStore(seen: true));
    await _slide(tester);
    final moves = _moves(tester);
    expect(moves, greaterThan(0));

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(_moves(tester), moves);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(find.text('Next'), findsOneWidget);
    expect(_moves(tester), moves);
  });

  for (final size in const [Size(390, 844), Size(844, 390), Size(1280, 720)]) {
    testWidgets('overlay and header fit without overflow at $size', (
      tester,
    ) async {
      await _pump(tester, _FakeStore(), size: size);
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(SingleChildScrollView));
      expect(card.width, lessThanOrEqualTo(360));
      expect(card.bottom, lessThanOrEqualTo(size.height));
    });
  }
}
