import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slide_merge/src/art/creature_art.dart';
import 'package:slide_merge/src/art/sea_palette.dart';
import 'package:slide_merge/src/art/sea_scenery.dart';
import 'package:slide_merge/src/meta/sea_theme.dart';

void main() {
  test('every power maps to a creature; big powers reuse the last one', () {
    expect(Creature.all, hasLength(14));
    for (var p = 1; p <= Creature.maxPower; p++) {
      expect(Creature.forPower(p).power, p);
    }
    expect(Creature.forPower(11).name, 'Whale');
    expect(Creature.forPower(20).name, 'Star Whale');
    expect(Creature.all.map((c) => c.name).toSet(), hasLength(14));
  });

  test('badge labels stay short', () {
    expect(tileValueLabel(1), '2');
    expect(tileValueLabel(11), '2048');
    expect(tileValueLabel(14), '16K');
    expect(tileValueLabel(17), '128K');
  });

  test('every theme has its own palette', () {
    final palettes = SeaTheme.values.map(SeaPalette.of).toSet();
    expect(palettes, hasLength(SeaTheme.values.length));
  });

  for (final theme in SeaTheme.values) {
    testWidgets('all creatures paint on the ${theme.label} scenery', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              SeaScenery(theme: theme),
              Wrap(
                children: [
                  for (var p = 1; p <= Creature.maxPower + 2; p++) ...[
                    SizedBox.square(
                      dimension: 64,
                      child: CreatureTile(power: p),
                    ),
                    SizedBox.square(
                      dimension: 24,
                      child: CreatureTile(power: p, silhouette: true),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CreatureTile), findsNWidgets(32));
    });
  }

  testWidgets('a zero-sized tile paints nothing and does not throw', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Center(
        child: SizedBox(width: 0, height: 0, child: CreatureTile(power: 5)),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
