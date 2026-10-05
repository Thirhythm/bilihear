import 'package:bilihear/core/models/media_track.dart';
import 'package:bilihear/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Locally stored favourites, shown while no Bilibili session is active.
final NotifierProvider<LocalFavoritesController, List<MediaTrack>>
localFavoritesProvider =
    NotifierProvider<LocalFavoritesController, List<MediaTrack>>(
      LocalFavoritesController.new,
    );

class LocalFavoritesController extends Notifier<List<MediaTrack>> {
  @override
  List<MediaTrack> build() =>
      ref.watch(localFavoritesRepositoryProvider).load();

  Future<void> add(MediaTrack track) async {
    final updated = await ref.read(localFavoritesRepositoryProvider).add(track);
    if (ref.mounted) state = updated;
  }

  Future<void> remove(MediaTrack track) async {
    final updated = await ref
        .read(localFavoritesRepositoryProvider)
        .remove(track);
    if (ref.mounted) state = updated;
  }

  /// Adds when absent, removes when present.
  Future<void> clear() async {
    await ref.read(localFavoritesRepositoryProvider).clear();
    if (ref.mounted) state = const [];
  }
}
