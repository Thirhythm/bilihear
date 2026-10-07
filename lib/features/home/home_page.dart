import 'package:bilihear/core/models/media_track.dart';
import 'package:bilihear/features/player/player_navigation.dart';
import 'package:bilihear/state/auth_controller.dart';
import 'package:bilihear/state/local_history_controller.dart';
import 'package:bilihear/state/player_controller.dart';
import 'package:bilihear/widgets/section_header.dart';
import 'package:bilihear/widgets/track_action_menu.dart';
import 'package:bilihear/widgets/track_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Landing page: the six most recently played tracks.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('哔哩听见')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authControllerProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: const [
            SectionHeader(title: '最近播放'),
            _RecentPlays(),
          ],
        ),
      ),
    );
  }
}

class _RecentPlays extends ConsumerWidget {
  const _RecentPlays();

  /// Home only ever surfaces a short teaser; the full list lives in 媒体库.
  static const int limit = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(localHistoryProvider);
    if (history.isEmpty) {
      return const _EmptyHint('没有播放记录');
    }
    final tracks = history.take(limit).toList();
    return Column(
      children: [
        for (final track in tracks)
          TrackTile(
            track: track,
            onTap: () async {
              await ref
                  .read(playerStateProvider.notifier)
                  .playVideo(track.bvid, page: track.page);
              if (!context.mounted) return;
              await openPlayerIfEnabled(context, ref);
            },
            onLongPress: () => showTrackActions(
              context,
              ref,
              track: track,
              deleteLabel: '删除',
              onDelete: () => _confirmRemove(context, ref, track),
            ),
          ),
      ],
    );
  }

  /// Asks before dropping a single entry from 最近播放.
  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    MediaTrack track,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定删除「${track.displayTitle}」的播放记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(localHistoryProvider.notifier).remove(track);
    }
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}
