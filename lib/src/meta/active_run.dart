import '../../game_logic.dart';
import 'missions.dart';

/// An unfinished attempt; meta XP and this record are saved together.
class ActiveRun {
  const ActiveRun({
    required this.game,
    required this.missions,
    required this.missionLevel,
    required this.highest,
    required this.merges,
    required this.bestCombo,
    required this.missionXp,
    required this.bestAtStart,
  });

  final SlideMergeGame game;
  final MissionSet missions;
  final int missionLevel, highest, merges, bestCombo, missionXp, bestAtStart;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'game': game.toSnapshot(),
    'missionLevel': missionLevel,
    'highest': highest,
    'merges': merges,
    'bestCombo': bestCombo,
    'missionXp': missionXp,
    'bestAtStart': bestAtStart,
    'missions': [
      for (final m in missions.missions)
        {
          'kind': m.kind.name,
          'target': m.target,
          'xp': m.xp,
          'progress': m.progress,
        },
    ],
  };

  static ActiveRun? restore(Object? raw, {required int totalXp}) {
    if (raw is! Map || raw['v'] != 1 || raw['game'] is! Map) return null;
    final board = raw['game'] as Map;
    final modes = GameMode.all.where((m) => m.id == board['mode']);
    if (modes.isEmpty) return null;
    final game = SlideMergeGame(mode: modes.first);
    if (!game.restoreSnapshot(board) || (game.isGameOver && !game.canUndo)) {
      return null;
    }
    bool bounded(Object? v, int min, int max) =>
        v is int && v >= min && v <= max;
    if (!bounded(raw['missionLevel'], 1, 1000000) ||
        !bounded(raw['highest'], game.highestPower, 30) ||
        !bounded(raw['merges'], 0, 1000000000) ||
        !bounded(raw['bestCombo'], 0, game.size * game.size ~/ 2) ||
        !bounded(raw['missionXp'], 0, totalXp) ||
        !bounded(raw['bestAtStart'], 0, 1000000000000)) {
      return null;
    }
    final entries = raw['missions'];
    if (entries is! List || entries.length != 3) return null;
    final missions = <Mission>[];
    final kinds = <MissionKind>{};
    for (final entry in entries) {
      if (entry is! Map) return null;
      final matches = MissionKind.values.where((k) => k.name == entry['kind']);
      if (matches.isEmpty) return null;
      final kind = matches.first;
      if (!kinds.add(kind) ||
          !bounded(
            entry['target'],
            1,
            kind == MissionKind.reachTile ? 30 : 1000000,
          ) ||
          entry['xp'] is! int ||
          !MissionSet.tierXp.contains(entry['xp']) ||
          !bounded(entry['progress'], 0, entry['target'] as int)) {
        return null;
      }
      missions.add(
        Mission(
          kind: kind,
          target: entry['target'] as int,
          xp: entry['xp'] as int,
          progress: entry['progress'] as int,
        ),
      );
    }
    final set = MissionSet(missions);
    if (set.earnedXp != raw['missionXp']) return null;
    return ActiveRun(
      game: game,
      missions: set,
      missionLevel: raw['missionLevel'] as int,
      highest: raw['highest'] as int,
      merges: raw['merges'] as int,
      bestCombo: raw['bestCombo'] as int,
      missionXp: raw['missionXp'] as int,
      bestAtStart: raw['bestAtStart'] as int,
    );
  }
}
