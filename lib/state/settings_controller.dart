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
