import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/creature_art.dart';
import '../art/sea_palette.dart';
import '../art/sea_scenery.dart';
import '../meta/missions.dart';
import '../meta/sea_progress.dart';
import '../meta/sea_theme.dart';
import 'hud.dart';

/// Everything the run summary shows.
class RunSummaryData {
  const RunSummaryData({
    required this.modeLabel,
    required this.score,
    required this.best,
    required this.isNewBest,
    required this.highestPower,
    required this.merges,
    required this.bestCombo,
    required this.missionsDone,
    required this.outcome,
  });

  final String modeLabel;
  final int score;
  final int best;
  final bool isNewBest;
  final int highestPower;
  final int merges;
  final int bestCombo;
  final int missionsDone;
  final RunOutcome outcome;
}

/// Game over card shown over the board. Enter plays again (handled by the
/// screen's key handler), Esc closes it.
class RunSummaryCard extends StatefulWidget {
  const RunSummaryCard({
    super.key,
    required this.data,
    required this.palette,
    required this.onPlayAgain,
    required this.onClose,
    this.onLevelUp,
  });

  final RunSummaryData data;
  final SeaPalette palette;
  final VoidCallback onPlayAgain;
  final VoidCallback onClose;

  /// Called once when the XP bar fills past a level.
  final VoidCallback? onLevelUp;

  @override
  State<RunSummaryCard> createState() => _RunSummaryCardState();
}

class _RunSummaryCardState extends State<RunSummaryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();
  bool _levelSoundPlayed = false;

  @override
  void initState() {
    super.initState();
    _anim.addListener(_onTick);
  }

  void _onTick() {
    if (!_levelSoundPlayed &&
        widget.data.outcome.leveledUp &&
        _anim.value > 0.75) {
      _levelSoundPlayed = true;
      widget.onLevelUp?.call();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final p = widget.palette;
    final creature = Creature.forPower(d.highestPower);
    final before = d.outcome.before;
    final after = d.outcome.progress;
    return Container(
      color: const Color(0x66021C30),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 340,
          child: SeaCard(
            opaque: true,
            palette: p,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No moves left!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: p.textPrimary,
                  ),
                ),
                Text(
                  d.modeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox.square(
                      dimension: 84,
                      child: CreatureTile(power: d.highestPower),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupThousands(d.score),
                            style: TextStyle(
                              fontSize: 34,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: p.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (d.isNewBest)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB627),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'New best!',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFFFFFF),
                                ),
                              ),
                            )
                          else
                            Text(
                              'Best ${groupThousands(d.best)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: p.textSecondary,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Top creature: ${creature.name}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat('Merges', '${d.merges}'),
                    _stat('Best combo', 'x${d.bestCombo}'),
                    _stat('Missions', '${d.missionsDone}/3'),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) => _xp(before, after),
                ),
                if (d.outcome.newlyUnlockedThemes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'New theme: ${d.outcome.newlyUnlockedThemes.map((t) => t.label).join(', ')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF7C5CFF),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    TextButton(
                      onPressed: widget.onClose,
                      child: Text(
                        'Close',
                        style: TextStyle(color: p.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: p.accent,
                          foregroundColor: p.accentInk,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: widget.onPlayAgain,
                        icon: const Icon(Icons.replay_rounded),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Play again'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    final p = widget.palette;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: p.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _xp(SeaProgress before, SeaProgress after) {
    final p = widget.palette;
    final t = Curves.easeOutCubic.transform(_anim.value);
    final xp = before.totalXp + ((after.totalXp - before.totalXp) * t).round();
    final shown = before.withXp(xp - before.totalXp);
    final leveled = shown.level > before.level;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  leveled ? 'Level up! Lv ${shown.level}' : 'Lv ${shown.level}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: leveled ? const Color(0xFF7C5CFF) : p.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '+${widget.data.outcome.xpGained} XP',
              style: TextStyle(fontWeight: FontWeight.w900, color: p.accent),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SeaBar(
          value: shown.levelFraction,
          color: p.accent,
          track: p.textSecondary.withValues(alpha: 0.2),
          height: 10,
        ),
      ],
    );
  }
}

/// Modal creature album with the theme picker. Esc / Enter close it.
class AlbumOverlay extends StatefulWidget {
  const AlbumOverlay({
    super.key,
    required this.progress,
    required this.palette,
    required this.onTheme,
    required this.onClose,
  });

  final SeaProgress progress;
  final SeaPalette palette;
  final ValueChanged<SeaTheme> onTheme;
  final VoidCallback onClose;

  @override
  State<AlbumOverlay> createState() => _AlbumOverlayState();
}

class _AlbumOverlayState extends State<AlbumOverlay> {
  final FocusNode _focus = FocusNode(debugLabel: 'album');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final closing = {
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
    };
    final swallowed = {
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyZ,
      LogicalKeyboardKey.keyU,
      LogicalKeyboardKey.space,
    };
    if (closing.contains(key)) {
      if (event is KeyDownEvent) widget.onClose();
      return KeyEventResult.handled;
    }
    if (swallowed.contains(key)) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final progress = widget.progress;
    final found = Creature.all.where((c) => progress.isDiscovered(c.power));
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          const ModalBarrier(color: Color(0xB3021C30), dismissible: false),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 560,
                  child: SeaCard(
                    opaque: true,
                    palette: p,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Creature Album',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: p.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${found.length} / ${Creature.all.length}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: p.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 7,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.72,
                          children: [
                            for (final c in Creature.all)
                              _entry(c, progress.isDiscovered(c.power)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Themes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final t in SeaTheme.values) ...[
                              if (t != SeaTheme.values.first)
                                const SizedBox(width: 8),
                              Expanded(child: _theme(t)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: p.accent,
                              foregroundColor: p.accentInk,
                            ),
                            onPressed: widget.onClose,
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entry(Creature c, bool found) {
    final p = widget.palette;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: CreatureTile(power: c.power, silhouette: !found),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          found ? c.name : '???',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: found ? p.textPrimary : p.textSecondary,
          ),
        ),
        Text(
          tileValueLabel(c.power),
          style: TextStyle(fontSize: 9, color: p.textSecondary),
        ),
      ],
    );
  }

  Widget _theme(SeaTheme t) {
    final p = widget.palette;
    final unlocked = widget.progress.isThemeUnlocked(t);
    final selected = widget.progress.selectedTheme == t;
    return Tooltip(
      message: unlocked ? t.label : 'Unlocks at Lv ${t.requiredLevel}',
      child: GestureDetector(
        onTap: unlocked ? () => widget.onTheme(t) : null,
        child: Column(
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? p.accent : const Color(0x00000000),
                  width: 3,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SeaScenery(theme: t),
                    if (!unlocked)
                      Container(
                        color: const Color(0x99021C30),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              color: Color(0xFFFFFFFF),
                              size: 18,
                            ),
                            Text(
                              'Lv ${t.requiredLevel}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (selected)
                      const Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: EdgeInsets.all(3),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFFFFFFFF),
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: unlocked ? p.textPrimary : p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
