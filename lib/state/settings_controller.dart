import 'package:bilihear/core/models/app_theme_mode.dart';
import 'package:bilihear/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether tapping a track opens the full screen player automatically.
final NotifierProvider<AutoOpenPlayerController, bool> autoOpenPlayerProvider =
    NotifierProvider<AutoOpenPlayerController, bool>(
      AutoOpenPlayerController.new,
    );

class AutoOpenPlayerController extends Notifier<bool> {
  @override
  bool build() => ref.watch(settingsRepositoryProvider).loadAutoOpenPlayer();

  Future<void> setEnabled(bool value) async {
    await ref.read(settingsRepositoryProvider).setAutoOpenPlayer(value);
    if (ref.mounted) state = value;
  }
}

/// Brightness preference chosen in 设置, applied to the whole app.
final NotifierProvider<ThemeModeController, AppThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeController, AppThemeMode>(
      ThemeModeController.new,
    );

class ThemeModeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => ref.watch(settingsRepositoryProvider).loadThemeMode();

  Future<void> setMode(AppThemeMode mode) async {
    await ref.read(settingsRepositoryProvider).setThemeMode(mode);
    if (ref.mounted) state = mode;
  }
}
