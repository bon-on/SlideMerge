import 'dart:math' as math;

enum Direction { left, right, up, down }

/// A selectable difficulty. Scores are only comparable within one mode.
class GameMode {
  const GameMode({
    required this.id,
    required this.label,
    required this.size,
    required this.tier2Chance,
  });

  final String id;
  final String label;
  final int size;
  final double tier2Chance;

  static const classic = GameMode(
    id: 'classic',
    label: 'Classic 4x4',
    size: 4,
    tier2Chance: 0.10,
  );
  static const relaxed = GameMode(
    id: 'relaxed',
    label: 'Relaxed 5x5',
    size: 5,
    tier2Chance: 0.18,
  );
  static const all = [classic, relaxed];
}

class Tile {
  const Tile({required this.id, required this.power});

  final int id;
  final int power;
}

/// One merge of a move, for effects: [keptId] slid from [keptFrom] and
/// [consumedId] from [consumedFrom] into [target], becoming [power].
class MergeEvent {
  const MergeEvent({
    required this.keptId,
    required this.keptFrom,
    required this.consumedId,
    required this.consumedFrom,
    required this.target,
    required this.power,
  });

  final int keptId;
  final int keptFrom;
  final int consumedId;
  final int consumedFrom;
  final int target;

  /// Power of the merged tile (value `1 << power`).
  final int power;
}

/// What the last successful move did. Purely informational (animations,
/// statistics); the rules never read it.
class MoveReport {
  const MoveReport({
    required this.direction,
    required this.from,
    required this.merges,
    required this.gained,
    this.spawnedId,
    this.spawnedIndex,
  });

  final Direction direction;

  /// Cell index each surviving tile id occupied before the move.
  final Map<int, int> from;
  final List<MergeEvent> merges;

  /// Points added by this move.
  final int gained;
  final int? spawnedId;
  final int? spawnedIndex;
}

class _Snapshot {
  _Snapshot(this.cells, this.score, this.moves, this.mergeProgress);
  final List<Tile?> cells;
  final int score;
  final int moves;
  final int mergeProgress;
}

/// Widget-free 2048-style engine with an undo-charge twist.
class SlideMergeGame {
  SlideMergeGame({required this.mode, math.Random? random})
    : _random = random ?? math.Random() {
    reset();
  }

  /// Merges needed to earn one undo charge.
  static const int mergesPerCharge = 20;
  static const int maxUndoCharges = 1;

  final GameMode mode;
  final math.Random _random;

  late List<Tile?> cells;
  int score = 0;
  int moves = 0;
  int undoCharges = maxUndoCharges;
  int mergeProgress = 0;
  int? lastSpawnedId;

  /// Cell index of [lastSpawnedId], if any.
  int? lastSpawnedIndex;

  /// Report of the last successful move; null after reset and undo.
  MoveReport? lastMove;
  int _nextTileId = 1;
  _Snapshot? _snapshot;

  int get size => mode.size;

  bool get canUndo => undoCharges > 0 && _snapshot != null;

  void reset() {
    cells = List<Tile?>.filled(size * size, null);
    score = 0;
    moves = 0;
    undoCharges = maxUndoCharges;
    mergeProgress = 0;
    _nextTileId = 1;
    _snapshot = null;
    _spawn();
    _spawn();
    lastSpawnedId = null;
    lastSpawnedIndex = null;
    lastMove = null;
  }

  bool get isGameOver {
    if (cells.any((c) => c == null)) return false;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final p = cells[r * size + c]!.power;
        if (r + 1 < size && cells[(r + 1) * size + c]!.power == p) return false;
        if (c + 1 < size && cells[r * size + c + 1]!.power == p) return false;
      }
    }
    return true;
  }

  void _spawn() {
    final empty = <int>[
      for (var i = 0; i < cells.length; i++)
        if (cells[i] == null) i,
    ];
    if (empty.isEmpty) return;
    final index = empty[_random.nextInt(empty.length)];
    final tile = Tile(
      id: _nextTileId++,
      power: _random.nextDouble() < mode.tier2Chance ? 2 : 1,
    );
    cells[index] = tile;
    lastSpawnedId = tile.id;
    lastSpawnedIndex = index;
  }

  /// Slides in [direction]. Returns true if the board changed.
  bool move(Direction direction) {
    final next = List<Tile?>.filled(size * size, null);
    var gained = 0;
    var merges = 0;
    final from = <int, int>{};
    final mergeEvents = <MergeEvent>[];

    for (var line = 0; line < size; line++) {
      int idx(int step) {
        final (row, col) = switch (direction) {
          Direction.left => (line, step),
          Direction.right => (line, size - 1 - step),
          Direction.up => (step, line),
          Direction.down => (size - 1 - step, line),
        };
        return row * size + col;
      }

      final tiles = <Tile>[];
      final origins = <int>[];
      for (var s = 0; s < size; s++) {
        final tile = cells[idx(s)];
        if (tile != null) {
          tiles.add(tile);
          origins.add(idx(s));
          from[tile.id] = idx(s);
        }
      }
      final out = <Tile>[];
      for (var i = 0; i < tiles.length; i++) {
        if (i + 1 < tiles.length && tiles[i].power == tiles[i + 1].power) {
          final power = tiles[i].power + 1;
          out.add(Tile(id: tiles[i].id, power: power));
          mergeEvents.add(
            MergeEvent(
              keptId: tiles[i].id,
              keptFrom: origins[i],
              consumedId: tiles[i + 1].id,
              consumedFrom: origins[i + 1],
              target: idx(out.length - 1),
              power: power,
            ),
          );
          gained += 1 << power;
          merges++;
          i++;
        } else {
          out.add(tiles[i]);
        }
      }
      for (var s = 0; s < out.length; s++) {
        next[idx(s)] = out[s];
      }
    }

    var changed = false;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i]?.id != next[i]?.id || cells[i]?.power != next[i]?.power) {
        changed = true;
        break;
      }
    }
    if (!changed) return false;

    _snapshot = _Snapshot(List<Tile?>.of(cells), score, moves, mergeProgress);
    cells = next;
    moves++;
    score += gained;
    mergeProgress += merges;
    while (mergeProgress >= mergesPerCharge) {
      mergeProgress -= mergesPerCharge;
      if (undoCharges < maxUndoCharges) undoCharges++;
    }
    lastSpawnedId = null;
    lastSpawnedIndex = null;
    _spawn();
    lastMove = MoveReport(
      direction: direction,
      from: from,
      merges: mergeEvents,
      gained: gained,
      spawnedId: lastSpawnedId,
      spawnedIndex: lastSpawnedIndex,
    );
    return true;
  }

  /// Reverts the last move, spending one charge. Returns true on success.
  bool undo() {
    final snap = _snapshot;
    if (snap == null || undoCharges <= 0) return false;
    cells = List<Tile?>.of(snap.cells);
    score = snap.score;
    moves = snap.moves;
    mergeProgress = snap.mergeProgress;
    undoCharges--;
    lastSpawnedId = null;
    lastSpawnedIndex = null;
    lastMove = null;
    _snapshot = null;
    return true;
  }
}

extension SlideMergeGameStats on SlideMergeGame {
  /// Highest tile power on the board (0 when empty).
  int get highestPower {
    var best = 0;
    for (final tile in cells) {
      if (tile != null && tile.power > best) best = tile.power;
    }
    return best;
  }

  /// Number of empty cells.
  int get emptyCells => cells.where((c) => c == null).length;
}
