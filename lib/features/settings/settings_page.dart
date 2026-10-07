import 'package:bilihear/core/models/app_theme_mode.dart';
import 'package:bilihear/features/settings/about_page.dart';
import 'package:bilihear/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App preferences, reachable from 我的.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoOpenPlayer = ref.watch(autoOpenPlayerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.play_circle_outline_rounded),
            title: const Text('点击曲目后自动打开播放器'),
            value: autoOpenPlayer,
            onChanged: (value) =>
                ref.read(autoOpenPlayerProvider.notifier).setEnabled(value),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '深色模式',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          for (final mode in AppThemeMode.values)
            ListTile(
              leading: Icon(_iconFor(mode)),
              title: Text(mode.label),
              trailing: mode == themeMode
                  ? const Icon(Icons.check_rounded)
                  : null,
              selected: mode == themeMode,
              onTap: () => ref.read(themeModeProvider.notifier).setMode(mode),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('关于'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const AboutPage())),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => Icons.brightness_auto_outlined,
  AppThemeMode.light => Icons.light_mode_outlined,
  AppThemeMode.dark => Icons.dark_mode_outlined,
};
