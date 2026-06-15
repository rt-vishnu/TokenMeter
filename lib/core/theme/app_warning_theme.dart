import 'package:flutter/material.dart';

/// Theme extension that carries amber warning colors that are
/// dark-mode aware but not derived from the green seed color.
///
/// Use [AppWarningTheme.of] to look up the current values.
class AppWarningTheme extends ThemeExtension<AppWarningTheme> {
  const AppWarningTheme({
    required this.color,
    required this.onColor,
    required this.container,
    required this.onContainer,
  });

  final Color color;
  final Color onColor;
  final Color container;
  final Color onContainer;

  static const _lightMode = AppWarningTheme(
    color: Color(0xFFF59E0B),
    onColor: Color(0xFF451A03),
    container: Color(0xFFFFF3CD),
    onContainer: Color(0xFF664D03),
  );

  static const _darkMode = AppWarningTheme(
    color: Color(0xFFFBBF24),
    onColor: Color(0xFF451A03),
    container: Color(0xFF4D3200),
    onContainer: Color(0xFFFDE68A),
  );

  static AppWarningTheme light() => _lightMode;
  static AppWarningTheme dark() => _darkMode;

  /// Convenience accessor — throws if extension is not registered in the theme.
  static AppWarningTheme of(BuildContext context) =>
      Theme.of(context).extension<AppWarningTheme>()!;

  @override
  AppWarningTheme copyWith({
    Color? color,
    Color? onColor,
    Color? container,
    Color? onContainer,
  }) =>
      AppWarningTheme(
        color: color ?? this.color,
        onColor: onColor ?? this.onColor,
        container: container ?? this.container,
        onContainer: onContainer ?? this.onContainer,
      );

  @override
  AppWarningTheme lerp(AppWarningTheme? other, double t) {
    if (other == null) return this;
    return AppWarningTheme(
      color: Color.lerp(color, other.color, t)!,
      onColor: Color.lerp(onColor, other.onColor, t)!,
      container: Color.lerp(container, other.container, t)!,
      onContainer: Color.lerp(onContainer, other.onContainer, t)!,
    );
  }
}
