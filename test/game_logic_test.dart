import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:slide_merge/game_logic.dart';

/// Random whose nextDouble is >= any tier2 chance (always tier 1) and
/// nextInt picks the first empty cell.
class _FirstCellRandom implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.99;
  @override
  int nextInt(int max) => 0;
}

SlideMergeGame game([GameMode mode = GameMode.classic]) =>
    SlideMergeGame(mode: mode, random: _FirstCellRandom());

/// Loads a power grid (0 = empty) into the game.
void load(SlideMergeGame g, List<List<int>> grid) {
  var id = 100;
  for (var r = 0; r < g.size; r++) {
    for (var c = 0; c < g.size; c++) {
      final p = grid[r][c];
      g.cells[r * g.size + c] = p == 0 ? null : Tile(id: id++, power: p);
    }
  }
}

List<int> row(SlideMergeGame g, int r) => [
  for (var c = 0; c < g.size; c++) g.cells[r * g.size + c]?.power ?? 0,
];

void main() {
  group('move report', () {
    test('records origins, merges with both sources, gain and spawn', () {
      final g = game();
      load(g, [
        [1, 1, 0, 2],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
      expect(g.move(Direction.left), isTrue);
      final r = g.lastMove!;
      expect(r.direction, Direction.left);
      expect(r.gained, 4);
      expect(r.merges, hasLength(1));
      final m = r.merges.single;
      expect(m.keptId, 100);
      expect(m.keptFrom, 0);
      expect(m.consumedId, 101);
      expect(m.consumedFrom, 1);
      expect(m.target, 0);
      expect(m.power, 2);
      expect(r.from[102], 3);
      expect(g.cells[1]?.id, 102);
      expect(r.spawnedId, g.lastSpawnedId);
      expect(g.cells[r.spawnedIndex!]?.id, r.spawnedId);
      expect(g.highestPower, 2);
    });

    test('reports two merges in one line toward the right wall', () {
      final g = game();
      load(g, [
        [1, 1, 1, 1],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
      g.move(Direction.right);
      final targets = g.lastMove!.merges.map((m) => m.target).toList();
      expect(targets, [3, 2]);
      expect(row(g, 0).sublist(2), [2, 2]);
    });

    test('is cleared by undo and reset', () {
      final g = game();
      load(g, [
        [1, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
      g.move(Direction.right);
      expect(g.lastMove, isNotNull);
      expect(g.undo(), isTrue);
      expect(g.lastMove, isNull);
      g.move(Direction.right);
      g.reset();
      expect(g.lastMove, isNull);
      expect(g.emptyCells, 14);
    });
  });

  test('modes: classic is 4x4 90/10, relaxed is 5x5', () {
    expect(game().size, 4);
    expect(GameMode.classic.tier2Chance, 0.10);
    expect(game(GameMode.relaxed).size, 5);
    expect(game().cells.where((c) => c != null).length, 2);
  });

  test('spawn uses tier2 chance', () {
    final g = SlideMergeGame(mode: GameMode.classic, random: _LowRandom());
    expect(g.cells.whereType<Tile>().every((t) => t.power == 2), isTrue);
  });

  test('slide left merges once per tile per move', () {
    final g = game();
    load(g, [
      [1, 1, 1, 1],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    expect(g.move(Direction.left), isTrue);
    expect(row(g, 0).sublist(0, 2), [2, 2]);
    expect(g.score, 8); // two merges of 2^2
  });

  test('three equal tiles merge leading pair only', () {
    final g = game();
    load(g, [
      [1, 1, 1, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    g.move(Direction.right);
    expect(row(g, 0).sublist(1), [0, 1, 2]); // index 0 = spawn
  });

  test('merged result does not chain', () {
    final g = game();
    load(g, [
      [1, 1, 2, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    g.move(Direction.left);
    expect(row(g, 0).sublist(0, 2), [2, 2]); // no 3 chain
  });

  test('each direction slides and merges', () {
    for (final d in Direction.values) {
      final g = game();
      load(g, [
        [1, 0, 0, 1],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [1, 0, 0, 1],
      ]);
      g.move(d);
      final t = g.cells;
      int p(int r, int c) => t[r * 4 + c]?.power ?? 0;
      switch (d) {
        case Direction.left:
          expect([p(0, 0), p(3, 0)], [2, 2]);
        case Direction.right:
          expect([p(0, 3), p(3, 3)], [2, 2]);
        case Direction.up:
          expect([p(0, 0), p(0, 3)], [2, 2]);
        case Direction.down:
          expect([p(3, 0), p(3, 3)], [2, 2]);
      }
    }
  });

  test('no-op move returns false and spawns nothing', () {
    final g = game();
    load(g, [
      [1, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    expect(g.move(Direction.left), isFalse);
    expect(g.moves, 0);
    expect(g.cells.whereType<Tile>().length, 1);
  });

  test('successful move spawns one tile', () {
    final g = game();
    load(g, [
      [0, 1, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    g.move(Direction.left);
    expect(g.cells.whereType<Tile>().length, 2);
    expect(g.lastSpawnedId, isNotNull);
  });

  test('game over detection', () {
    final g = game();
    load(g, [
      [1, 2, 1, 2],
      [2, 1, 2, 1],
      [1, 2, 1, 2],
      [2, 1, 2, 1],
    ]);
    expect(g.isGameOver, isTrue);
    load(g, [
      [1, 2, 1, 2],
      [2, 1, 2, 1],
      [1, 2, 1, 2],
      [2, 1, 2, 2],
    ]);
    expect(g.isGameOver, isFalse);
    load(g, [
      [1, 2, 1, 2],
      [2, 1, 2, 1],
      [1, 2, 1, 2],
      [2, 1, 2, 0],
    ]);
    expect(g.isGameOver, isFalse);
  });

  test('undo restores board and score, spends the charge', () {
    final g = game();
    load(g, [
      [1, 1, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    g.move(Direction.left);
    expect(g.score, 4);
    expect(g.canUndo, isTrue);
    expect(g.undo(), isTrue);
    expect(g.score, 0);
    expect(g.moves, 0);
    expect(row(g, 0), [1, 1, 0, 0]);
    expect(g.undoCharges, 0);
    expect(g.undo(), isFalse);
  });

  test('undo needs a prior move and is single-step', () {
    final g = game();
    expect(g.undo(), isFalse);
  });

  test('charge is earned every $mergesPerChargeLabel merges', () {
    final g = game();
    g.undoCharges = 0;
    g.mergeProgress = SlideMergeGame.mergesPerCharge - 1;
    load(g, [
      [1, 1, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    g.move(Direction.left);
    expect(g.undoCharges, 1);
    expect(g.mergeProgress, 0);
  });

  test('charges cap at the maximum', () {
    final g = game();
    g.mergeProgress = SlideMergeGame.mergesPerCharge - 1;
    load(g, [
      [1, 1, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    g.move(Direction.left);
    expect(g.undoCharges, SlideMergeGame.maxUndoCharges);
  });

  test('reset restores initial state', () {
    final g = game();
    g.move(Direction.left);
    g.move(Direction.down);
    g.reset();
    expect(g.score, 0);
    expect(g.moves, 0);
    expect(g.undoCharges, 1);
    expect(g.canUndo, isFalse);
  });
}

const mergesPerChargeLabel = SlideMergeGame.mergesPerCharge;

class _LowRandom implements math.Random {
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0.0;
  @override
  int nextInt(int max) => 0;
}
