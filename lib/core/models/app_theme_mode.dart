/// Brightness preference offered in 设置.
enum AppThemeMode {
  /// Follows the system setting.
  system('跟随系统'),

  /// Always uses the light theme.
  light('浅色'),

  /// Always uses the dark theme.
  dark('深色');

  const AppThemeMode(this.label);

  final String label;

  /// Restores a persisted preference, falling back to [AppThemeMode.system].
  static AppThemeMode fromStorage(String? value) =>
      AppThemeMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => AppThemeMode.system,
      );
}
