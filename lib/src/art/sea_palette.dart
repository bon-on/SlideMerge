import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../meta/sea_theme.dart';

/// Colors of one [SeaTheme] shared by the scenery, the board and the HUD.
///
/// Creature colors never change with the theme, so a creature is always
/// recognizable; only the water around it does.
@immutable
class SeaPalette {
  const SeaPalette._({
    required this.theme,
    required this.waterTop,
    required this.waterBottom,
    required this.ray,
    required this.sand,
    required this.sandShade,
    required this.weed,
    required this.weedLight,
    required this.rock,
    required this.bubble,
    required this.board,
    required this.boardBorder,
    required this.cell,
    required this.cellShade,
    required this.panel,
    required this.panelBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentInk,
    required this.danger,
  });

  static SeaPalette of(SeaTheme theme) => switch (theme) {
    SeaTheme.lagoon => _lagoon,
    SeaTheme.coral => _coral,
    SeaTheme.polar => _polar,
    SeaTheme.moonlit => _moonlit,
  };

  final SeaTheme theme;

  /// Water gradient, surface (top of the screen) to depth.
  final Color waterTop;
  final Color waterBottom;

  /// Light rays from the surface.
  final Color ray;

  /// Sea floor.
  final Color sand;
  final Color sandShade;

  /// Seaweed silhouettes.
  final Color weed;
  final Color weedLight;

  /// Rocks / coral heads on the floor.
  final Color rock;

  /// Floating bubbles.
  final Color bubble;

  /// Board glass and its rim.
  final Color board;
  final Color boardBorder;

  /// Empty cell well.
  final Color cell;
  final Color cellShade;

  /// HUD card fill and outline.
  final Color panel;
  final Color panelBorder;
  final Color textPrimary;
  final Color textSecondary;

  /// Buttons, progress bars, highlights; [accentInk] is text on [accent].
  final Color accent;
  final Color accentInk;

  /// Near-failure vignette.
  final Color danger;

  static const SeaPalette _lagoon = SeaPalette._(
    theme: SeaTheme.lagoon,
    waterTop: Color(0xFF5FD8E6),
    waterBottom: Color(0xFF1677A8),
    ray: Color(0x33FFFFFF),
    sand: Color(0xFFF2D59A),
    sandShade: Color(0xFFD9B574),
    weed: Color(0xFF1E8C6E),
    weedLight: Color(0xFF39B88A),
    rock: Color(0xFF5F8FA3),
    bubble: Color(0x88FFFFFF),
    board: Color(0x5A0B4F7A),
    boardBorder: Color(0xAAE6FBFF),
    cell: Color(0x4D06385A),
    cellShade: Color(0x33FFFFFF),
    panel: Color(0xD9FFFFFF),
    panelBorder: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0B3954),
    textSecondary: Color(0xFF4F7A8F),
    accent: Color(0xFFFF8A5B),
    accentInk: Color(0xFFFFFFFF),
    danger: Color(0xFFFF4D6D),
  );

  static const SeaPalette _coral = SeaPalette._(
    theme: SeaTheme.coral,
    waterTop: Color(0xFF7FE0D6),
    waterBottom: Color(0xFF2E7FA6),
    ray: Color(0x2EFFF4E0),
    sand: Color(0xFFF7DDB0),
    sandShade: Color(0xFFE5BE86),
    weed: Color(0xFFE2557A),
    weedLight: Color(0xFFFF8FA8),
    rock: Color(0xFFF2A65A),
    bubble: Color(0x88FFFFFF),
    board: Color(0x55174E78),
    boardBorder: Color(0xAAFFE8EE),
    cell: Color(0x4D0A3655),
    cellShade: Color(0x33FFFFFF),
    panel: Color(0xDBFFF8F3),
    panelBorder: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF5A1F3A),
    textSecondary: Color(0xFF9A5A70),
    accent: Color(0xFFE2557A),
    accentInk: Color(0xFFFFFFFF),
    danger: Color(0xFFFF3B3B),
  );

  static const SeaPalette _polar = SeaPalette._(
    theme: SeaTheme.polar,
    waterTop: Color(0xFFD6F3FF),
    waterBottom: Color(0xFF4A86B8),
    ray: Color(0x40FFFFFF),
    sand: Color(0xFFF4FAFF),
    sandShade: Color(0xFFC9DDEE),
    weed: Color(0xFF6FA8C9),
    weedLight: Color(0xFFA9D6EE),
    rock: Color(0xFFE6F2FA),
    bubble: Color(0xAAFFFFFF),
    board: Color(0x552B5D8A),
    boardBorder: Color(0xCCFFFFFF),
    cell: Color(0x4D1B4670),
    cellShade: Color(0x40FFFFFF),
    panel: Color(0xE0FFFFFF),
    panelBorder: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF173B5C),
    textSecondary: Color(0xFF557A99),
    accent: Color(0xFF3D8BFF),
    accentInk: Color(0xFFFFFFFF),
    danger: Color(0xFFFF4D6D),
  );

  static const SeaPalette _moonlit = SeaPalette._(
    theme: SeaTheme.moonlit,
    waterTop: Color(0xFF1E2D6B),
    waterBottom: Color(0xFF070B24),
    ray: Color(0x1FB8C6FF),
    sand: Color(0xFF2A2F5C),
    sandShade: Color(0xFF1B1F45),
    weed: Color(0xFF173E5C),
    weedLight: Color(0xFF3FE0C5),
    rock: Color(0xFF242A55),
    bubble: Color(0x6698F5FF),
    board: Color(0x66060A2A),
    boardBorder: Color(0x9978E8FF),
    cell: Color(0x66141B4D),
    cellShade: Color(0x2298F5FF),
    panel: Color(0xD9161D48),
    panelBorder: Color(0x6698F5FF),
    textPrimary: Color(0xFFEAF2FF),
    textSecondary: Color(0xFF9DB0E0),
    accent: Color(0xFF3FE0C5),
    accentInk: Color(0xFF07112E),
    danger: Color(0xFFFF5E8A),
  );
}
