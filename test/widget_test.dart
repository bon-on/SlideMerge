import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slide_merge/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Slide Merge renders the game board', (tester) async {
    await tester.pumpWidget(const SlideMergeApp());
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Slide Merge'), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
    expect(find.text('Classic 4x4'), findsOneWidget);
    expect(find.text('Relaxed 5x5'), findsOneWidget);
  });

  testWidgets('keyboard input and slow swipe are accepted', (tester) async {
    await tester.pumpWidget(const SlideMergeApp());
    await tester.pump();
    for (final key in [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.keyS,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.drag(find.byType(GestureDetector).last, const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
