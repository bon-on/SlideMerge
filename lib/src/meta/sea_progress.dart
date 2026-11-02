import '../art/creature_art.dart';
import 'sea_theme.dart';

/// Facts about one finished (or restarted) run, fed to [SeaProgress.applyRun].
class RunSummary {
  const RunSummary({
    required this.score,
    required this.highestPower,
    required this.moves,
    this.merges = 0,
    this.bestCombo = 0,
    this.missionXp = 0,
  });

  final int score;
  final int highestPower;
  final int moves;
  final int merges;
  final int bestCombo;

  /// XP already earned from missions completed during the run.
  final int missionXp;
}

/// Result of applying a run to the saved progress.
class RunOutcome {
  const RunOutcome({
    required this.before,
    required this.progress,
    required this.xpGained,
    required this.newlyUnlockedThemes,
  });

  final SeaProgress before;
  final SeaProgress progress;
  final int xpGained;
  final List<SeaTheme> newlyUnlockedThemes;

  int get levelBefore => before.level;
  int get levelAfter => progress.level;
  bool get leveledUp => levelAfter > levelBefore;
}

/// Saved meta progress: XP (player level), the creature album, the highest
/// tile ever made and the chosen theme. Best scores stay in
/// `BestScoreStore` (per mode, older key).
///
/// Tuning: a casual 4x4 run scores roughly 1,000 to 6,000 points, so
/// XP = score / 20 + mission XP (30 to 80 each) + 10 for a run of at least
/// [participationMinMoves] moves gives about 100 to 400 XP per run. Reaching
/// level L+1 costs 150 + 50 * (L - 1) XP, so Lv3 (Coral Reef) takes about two
/// runs, Lv6 (Polar Sea) about five and Lv10 (Moonlit Deep) about ten to
/// fifteen.
class SeaProgress {
  const SeaProgress({
    required this.totalXp,
    required this.discovered,
    required this.bestPower,
    required this.selectedTheme,
    required this.runs,
  });

  const SeaProgress.initial()
    : totalXp = 0,
      discovered = const <int>{1, 2},
      bestPower = 0,
      selectedTheme = SeaTheme.lagoon,
      runs = 0;

  static const int participationXp = 10;
  static const int participationMinMoves = 10;

  final int totalXp;

  /// Creature powers seen at least once (album entries, 1..[Creature.maxPower]).
  final Set<int> discovered;

  /// Highest tile power ever made (uncapped).
  final int bestPower;
  final SeaTheme selectedTheme;

  /// Runs that counted (at least one move).
  final int runs;

  static int xpToAdvance(int level) => 150 + 50 * (level < 1 ? 0 : level - 1);

  static int xpForScore(int score) => score <= 0 ? 0 : score ~/ 20;

  int get level => _split().$1;
  int get xpIntoLevel => _split().$2;
  int get xpForNextLevel => xpToAdvance(level);

  /// 0..1 progress towards the next level.
  double get levelFraction => xpIntoLevel / xpForNextLevel;

  (int, int) _split() {
    var level = 1;
    var left = totalXp < 0 ? 0 : totalXp;
    while (left >= xpToAdvance(level)) {
      left -= xpToAdvance(level);
      level += 1;
    }
    return (level, left);
  }

  bool isThemeUnlocked(SeaTheme theme) => level >= theme.requiredLevel;

  bool isDiscovered(int power) =>
      discovered.contains(power.clamp(1, Creature.maxPower));

  /// Records a tile of [power]; returns this unchanged when nothing is new.
  SeaProgress withTile(int power) {
    final entry = power.clamp(1, Creature.maxPower);
    final newEntry = !discovered.contains(entry);
    final newBest = power > bestPower;
    if (!newEntry && !newBest) return this;
    return _copy(
      discovered: newEntry ? {...discovered, entry} : null,
      bestPower: newBest ? power : null,
    );
  }

  /// Returns this progress unchanged when [theme] is still locked.
  SeaProgress withTheme(SeaTheme theme) {
    if (!isThemeUnlocked(theme)) return this;
    return _copy(selectedTheme: theme);
  }

  SeaProgress withXp(int xp) => xp <= 0 ? this : _copy(totalXp: totalXp + xp);

  RunOutcome applyRun(RunSummary summary) {
    if (summary.moves <= 0) {
      return RunOutcome(
        before: this,
        progress: this,
        xpGained: 0,
        newlyUnlockedThemes: const <SeaTheme>[],
      );
    }
    final xp =
        xpForScore(summary.score) +
        (summary.missionXp < 0 ? 0 : summary.missionXp) +
        (summary.moves >= participationMinMoves ? participationXp : 0);
    final next = _copy(
      totalXp: totalXp + xp,
      runs: runs + 1,
    ).withTile(summary.highestPower);
    return RunOutcome(
      before: this,
      progress: next,
      xpGained: xp,
      newlyUnlockedThemes: [
        for (final theme in SeaTheme.values)
          if (level < theme.requiredLevel && next.level >= theme.requiredLevel)
            theme,
      ],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'totalXp': totalXp,
    'discovered': (discovered.toList()..sort()),
    'bestPower': bestPower,
    'selectedTheme': selectedTheme.name,
    'runs': runs,
  };

  /// Tolerant parser: every missing or invalid field falls back on its own.
  factory SeaProgress.fromJson(Object? json) {
    if (json is! Map) return const SeaProgress.initial();
    int readInt(Object? value) =>
        value is num && value.isFinite && value >= 0 ? value.toInt() : 0;
    final found = <int>{1, 2};
    final raw = json['discovered'];
    if (raw is List) {
      for (final value in raw) {
        if (value is num && value.isFinite && value >= 1) {
          found.add(value.toInt().clamp(1, Creature.maxPower));
        }
      }
    }
    final progress = SeaProgress(
      totalXp: readInt(json['totalXp']),
      discovered: Set.unmodifiable(found),
      bestPower: readInt(json['bestPower']).clamp(0, 30),
      selectedTheme: SeaTheme.lagoon,
      runs: readInt(json['runs']),
    );
    final theme = json['selectedTheme'];
    return progress.withTheme(
      SeaTheme.fromName(theme is String ? theme : null),
    );
  }

  SeaProgress _copy({
    int? totalXp,
    Set<int>? discovered,
    int? bestPower,
    SeaTheme? selectedTheme,
    int? runs,
  }) {
    return SeaProgress(
      totalXp: totalXp ?? this.totalXp,
      discovered: Set.unmodifiable(discovered ?? this.discovered),
      bestPower: bestPower ?? this.bestPower,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      runs: runs ?? this.runs,
    );
  }
}
