import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slide_merge/main.dart';

void main() {
  testWidgets('Slide Merge renders the game board', (tester) async {
    await tester.pumpWidget(const SlideMergeApp());
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Slide Merge'), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
  });
}
