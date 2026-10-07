import 'package:bilihear/core/models/app_theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App preferences that are not tied to a Bilibili session.
class SettingsRepository {
  SettingsRepository(this._prefs);

  static const String _autoOpenPlayerKey = 'settings_auto_open_player_v1';
  static const String _themeModeKey = 'settings_theme_mode_v1';

  final SharedPreferences _prefs;

  /// Whether tapping a track should open the full screen player right away.
  bool loadAutoOpenPlayer() => _prefs.getBool(_autoOpenPlayerKey) ?? false;

  Future<void> setAutoOpenPlayer(bool value) =>
      _prefs.setBool(_autoOpenPlayerKey, value);

  /// Brightness the app should use; follows the system until changed.
  AppThemeMode loadThemeMode() =>
      AppThemeMode.fromStorage(_prefs.getString(_themeModeKey));

  Future<void> setThemeMode(AppThemeMode mode) =>
      _prefs.setString(_themeModeKey, mode.name);
}
