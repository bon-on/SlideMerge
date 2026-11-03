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

  /// Highest difficulty tier.
  static const int maxTier = 3;

  /// Mission XP per tier (harder goals pay more).
  static const List<int> tierXp = [20, 35, 55, 80];

  /// Difficulty tiers a player of [level] can draw. A Lv1-2 newcomer only
  /// gets tier 0 goals, which one normal run completes.
  static List<int> tiersForLevel(int level) {
    if (level <= 2) return const [0];
    if (level <= 5) return const [0, 1];
    if (level <= 9) return const [1, 2];
    return const [2, 3];
  }

  /// Target of [kind] at [tier] on a board of [boardSize].
  ///
  /// Tier 0 (4x4): make a 16 or 32, merge 10-15 times, combo x2, score
  /// 300-500, 40-60 moves. Combo goals are capped (x3 on 4x4, x4 on 5x5):
  /// more merges in one move are rare even for good players.
  static int targetFor(
    MissionKind kind,
    int tier,
    int boardSize,
    math.Random rng,
  ) {
    final t = tier.clamp(0, maxTier);
    final big = boardSize >= 5;
    int pick(List<int> options) => options[rng.nextInt(options.length)];
    int scaled(int value) => big ? (value * 3 ~/ 2) : value;
    switch (kind) {
      case MissionKind.reachTile:
        final power = pick(
          const [
            [4, 5],
            [6, 7],
            [8],
            [9],
          ][t],
        );
        return big && t > 0 ? power + 1 : power;
      case MissionKind.merges:
        return scaled(
          pick(
            const [
              [10, 15],
              [25, 35],
              [50, 70],
              [90],
            ][t],
          ),
        );
      case MissionKind.combo:
        final combo = const [2, 2, 3, 3][t] + (big && t >= 2 ? 1 : 0);
        return math.min(combo, big ? 4 : 3);
      case MissionKind.score:
        return scaled(
          pick(
            const [
              [300, 500],
              [1000, 1500],
              [2500, 3500],
              [5000],
            ][t],
          ),
        );
      case MissionKind.moves:
        return scaled(
          pick(
            const [
              [40, 60],
              [100, 150],
              [200],
              [300],
            ][t],
          ),
        );
    }
  }

  /// Picks three different kinds with a difficulty fitted to [level].
  factory MissionSet.forRun({
    required int boardSize,
    int level = 1,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final kinds = List<MissionKind>.of(MissionKind.values)..shuffle(rng);
    final tiers = tiersForLevel(level);
    final picked = <Mission>[];
    for (final kind in kinds.take(3)) {
      final tier = tiers[rng.nextInt(tiers.length)];
      picked.add(
        Mission(
          kind: kind,
          target: targetFor(kind, tier, boardSize, rng),
          xp: tierXp[tier],
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
