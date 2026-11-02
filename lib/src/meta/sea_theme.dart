/// Cosmetic board themes, unlocked by player level. Themes never change rules.
enum SeaTheme {
  lagoon(requiredLevel: 1, label: 'Lagoon'),
  coral(requiredLevel: 3, label: 'Coral Reef'),
  polar(requiredLevel: 6, label: 'Polar Sea'),
  moonlit(requiredLevel: 10, label: 'Moonlit Deep');

  const SeaTheme({required this.requiredLevel, required this.label});

  /// Player level at which the theme becomes selectable.
  final int requiredLevel;

  /// Short English name shown in the UI.
  final String label;

  /// Parses a stored theme name; unknown values fall back to [lagoon].
  static SeaTheme fromName(String? name) {
    for (final theme in values) {
      if (theme.name == name) return theme;
    }
    return lagoon;
  }
}
