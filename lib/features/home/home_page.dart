import 'package:bilihear/features/player/player_navigation.dart';
import 'package:bilihear/state/auth_controller.dart';
import 'package:bilihear/state/local_history_controller.dart';
import 'package:bilihear/state/player_controller.dart';
import 'package:bilihear/widgets/section_header.dart';
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
          ),
      ],
    );
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
