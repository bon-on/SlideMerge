import 'dart:math' as math;

import '../art/creature_art.dart';

enum MissionKind { reachTile, merges, combo, score, moves }

/// Running statistics of the current run that missions are measured on.
class RunStats {
  const RunStats({
    this.highestPower = 0,
    this.merges = 0,
    this.bestCombo = 0,
    this.score = 0,
    this.moves = 0,
  });

  final int highestPower;
  final int merges;
  final int bestCombo;
  final int score;
  final int moves;

  int valueFor(MissionKind kind) => switch (kind) {
    MissionKind.reachTile => highestPower,
    MissionKind.merges => merges,
    MissionKind.combo => bestCombo,
    MissionKind.score => score,
    MissionKind.moves => moves,
  };
}

/// One in-run goal. Once completed it stays completed, even after an undo.
class Mission {
  const Mission({
    required this.kind,
    required this.target,
    required this.xp,
    this.progress = 0,
  });

  final MissionKind kind;

  /// Tile power for [MissionKind.reachTile], otherwise a count.
  final int target;
  final int xp;

  /// Clamped to 0..[target]; never decreases.
  final int progress;

  bool get completed => progress >= target;

  double get fraction => target <= 0 ? 1 : progress / target;

  String get label => switch (kind) {
    MissionKind.reachTile =>
      'Make a ${Creature.forPower(target).name} (${1 << target})',
    MissionKind.merges => 'Merge $target times',
    MissionKind.combo => 'Combo x$target in one move',
    MissionKind.score => 'Score ${groupThousands(target)}',
    MissionKind.moves => 'Make $target moves',
  };

  /// Short progress text, e.g. "12/40" or "Done".
  String get progressLabel {
    if (completed) return 'Done';
    if (kind == MissionKind.reachTile) {
      return progress <= 0 ? '-' : '${1 << progress}/${1 << target}';
    }
    return '$progress/$target';
  }

  Mission withProgress(int value) {
    final next = math.max(progress, value.clamp(0, target));
    if (next == progress) return this;
    return Mission(kind: kind, target: target, xp: xp, progress: next);
  }
}

String groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Three missions per run, targets fitted to the board size.
class MissionSet {
  MissionSet(this.missions);

  /// Picks three different kinds with a random difficulty each.
  factory MissionSet.forRun({required int boardSize, math.Random? random}) {
    final rng = random ?? math.Random();
    final kinds = List<MissionKind>.of(MissionKind.values)..shuffle(rng);
    final big = boardSize >= 5;
    final picked = <Mission>[];
    for (final kind in kinds.take(3)) {
      final tier = rng.nextInt(3);
      final targets = switch (kind) {
        MissionKind.reachTile => big ? const [7, 8, 9] : const [6, 7, 8],
        MissionKind.merges => big ? const [40, 70, 110] : const [25, 45, 70],
        MissionKind.combo => big ? const [3, 4, 5] : const [3, 3, 4],
        MissionKind.score =>
          big ? const [1500, 3000, 6000] : const [800, 1600, 3000],
        MissionKind.moves => big ? const [150, 250, 400] : const [80, 150, 250],
      };
      picked.add(
        Mission(
          kind: kind,
          target: targets[tier],
          xp: const [30, 50, 80][tier],
        ),
      );
    }
    // Stable order: tile goals first, then counts.
    picked.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return MissionSet(picked);
  }

  final List<Mission> missions;

  int get completedCount => missions.where((m) => m.completed).length;

  int get earnedXp =>
      missions.where((m) => m.completed).fold(0, (sum, m) => sum + m.xp);

  /// Applies [stats]; returns the missions completed by this update.
  List<Mission> update(RunStats stats) {
    final done = <Mission>[];
    for (var i = 0; i < missions.length; i++) {
      final before = missions[i];
      final after = before.withProgress(stats.valueFor(before.kind));
      missions[i] = after;
      if (!before.completed && after.completed) done.add(after);
    }
    return done;
  }
}
