import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game_logic.dart';
import '../art/creature_art.dart';
import '../art/sea_palette.dart';
import '../meta/missions.dart';
import '../meta/sea_progress.dart';
import 'board_fx.dart';

/// Rounded frosted card used by every HUD block.
class SeaCard extends StatelessWidget {
  const SeaCard({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.opaque = false,
  });

  final SeaPalette palette;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Modal cards (summary, album) must not show the board through them.
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: opaque ? palette.panel.withValues(alpha: 1) : palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.panelBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26021C30),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Small label over a big number. The label/value pair is one [Column] with
/// exactly two [Text] children (tests read the value as the last one).
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.palette,
    this.highlight = false,
  });

  final String label;
  final String value;
  final SeaPalette palette;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: highlight ? palette.accent : palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.panelBorder, width: 1.2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: highlight ? palette.accentInk : palette.textSecondary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: highlight ? palette.accentInk : palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White round icon button with a tooltip.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.palette,
    this.size = 42,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final SeaPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: palette.panel,
        shape: CircleBorder(
          side: BorderSide(color: palette.panelBorder, width: 1.5),
        ),
        elevation: 2,
        shadowColor: const Color(0x55021C30),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, color: palette.textPrimary, size: size * 0.52),
          ),
        ),
      ),
    );
  }
}

/// Classic / Relaxed pill toggle.
class ModeToggle extends StatelessWidget {
  const ModeToggle({
    super.key,
    required this.mode,
    required this.onMode,
    required this.palette,
  });

  final GameMode mode;
  final ValueChanged<GameMode> onMode;
  final SeaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.panelBorder, width: 1.2),
      ),
      child: Row(
        children: [
          for (final m in GameMode.all)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onMode(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: m.id == mode.id
                        ? palette.accent
                        : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: m.id == mode.id
                              ? palette.accentInk
                              : palette.textSecondary,
                        ),
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
}

/// Undo with its charge state ("Undo" or merges until the next charge).
class UndoButton extends StatelessWidget {
  const UndoButton({
    super.key,
    required this.charges,
    required this.progress,
    required this.canUndo,
    required this.onUndo,
    required this.palette,
  });

  final int charges;
  final int progress;
  final bool canUndo;
  final VoidCallback onUndo;
  final SeaPalette palette;

  @override
  Widget build(BuildContext context) {
    final enabled = canUndo;
    final fg = enabled ? palette.accentInk : palette.textSecondary;
    return Tooltip(
      message: charges > 0
          ? 'Undo last move'
          : 'Next charge in ${SlideMergeGame.mergesPerCharge - progress} merges',
      child: Material(
        color: enabled ? palette.accent : palette.panel,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onUndo : null,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.panelBorder, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.undo_rounded, size: 18, color: fg),
                const SizedBox(width: 4),
                Text(
                  charges > 0
                      ? 'Undo'
                      : '$progress/${SlideMergeGame.mergesPerCharge}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin rounded progress bar.
class SeaBar extends StatelessWidget {
  const SeaBar({
    super.key,
    required this.value,
    required this.color,
    required this.track,
    this.height = 8,
  });

  final double value;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: track)),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: c.maxWidth * value.clamp(0.0, 1.0),
                child: ColoredBox(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Lv 3" badge with the XP bar.
class LevelCard extends StatelessWidget {
  const LevelCard({
    super.key,
    required this.progress,
    required this.palette,
    this.compact = false,
  });

  final SeaProgress progress;
  final SeaPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bar = SeaBar(
      value: progress.levelFraction,
      color: palette.accent,
      track: palette.textSecondary.withValues(alpha: 0.2),
      height: compact ? 6 : 8,
    );
    if (compact) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.panelBorder, width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Lv ${progress.level}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            bar,
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Lv ${progress.level}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: palette.accentInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${progress.xpIntoLevel} / ${progress.xpForNextLevel} XP',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        bar,
      ],
    );
  }
}

/// The three missions of the run.
class MissionList extends StatelessWidget {
  const MissionList({
    super.key,
    required this.missions,
    required this.palette,
    this.compact = false,
  });

  final List<Mission> missions;
  final SeaPalette palette;

  /// Narrow layout: three chips in a row.
  final bool compact;

  IconData _icon(Mission m) => switch (m.kind) {
    MissionKind.reachTile => Icons.auto_awesome_rounded,
    MissionKind.merges => Icons.merge_rounded,
    MissionKind.combo => Icons.bolt_rounded,
    MissionKind.score => Icons.star_rounded,
    MissionKind.moves => Icons.swipe_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          for (var i = 0; i < missions.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _chip(missions[i])),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < missions.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _row(missions[i]),
        ],
      ],
    );
  }

  Widget _badge(Mission m, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: m.completed
          ? const Color(0xFF2FBF85)
          : palette.textSecondary.withValues(alpha: 0.15),
    ),
    child: Icon(
      m.completed ? Icons.check_rounded : _icon(m),
      size: size * 0.62,
      color: m.completed ? const Color(0xFFFFFFFF) : palette.textPrimary,
    ),
  );

  Widget _row(Mission m) {
    return Row(
      children: [
        _badge(m, 30),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                  decoration: m.completed ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: SeaBar(
                      value: m.fraction,
                      color: m.completed
                          ? const Color(0xFF2FBF85)
                          : palette.accent,
                      track: palette.textSecondary.withValues(alpha: 0.18),
                      height: 6,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+${m.xp} XP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(Mission m) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.panelBorder, width: 1.2),
      ),
      child: Row(
        children: [
          _badge(m, 22),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating banners (combo, discovery, mission, XP) above the board.
class FxBanners extends StatelessWidget {
  const FxBanners({super.key, required this.fx, required this.palette});

  final BoardFx fx;
  final SeaPalette palette;

  Color _color(BannerStyle style) => switch (style) {
    BannerStyle.combo => const Color(0xFFFF8A5B),
    BannerStyle.discover => const Color(0xFFFFB627),
    BannerStyle.mission => const Color(0xFF2FBF85),
    BannerStyle.record => const Color(0xFF7C5CFF),
    BannerStyle.info => const Color(0xFF3D8BFF),
  };

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: fx,
        builder: (context, _) {
          final banners = fx.banners;
          if (banners.isEmpty) return const SizedBox.shrink();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [for (final b in banners.reversed) _banner(b)],
          );
        },
      ),
    );
  }

  Widget _banner(FxBanner b) {
    final f = fx.bannerProgress(b);
    final appear = Curves.easeOutBack.transform((f / 0.15).clamp(0.0, 1.0));
    final fade = f > 0.8 ? (1 - f) / 0.2 : 1.0;
    final big = b.style == BannerStyle.discover;
    final color = _color(b.style);
    return Opacity(
      opacity: fade.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, -12 * (1 - appear) - 10 * math.max(0, f - 0.8)),
        child: Transform.scale(
          scale: 0.6 + 0.4 * appear,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: EdgeInsets.symmetric(
              horizontal: big ? 16 : 14,
              vertical: big ? 8 : 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xF2FFFFFF),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (b.power != null) ...[
                  SizedBox.square(
                    dimension: big ? 44 : 30,
                    child: CustomPaint(
                      painter: CreatureTilePainter(
                        power: b.power!,
                        showBadge: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: big ? 20 : 16,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                      if (b.subtitle != null)
                        Text(
                          b.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0B3954),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
