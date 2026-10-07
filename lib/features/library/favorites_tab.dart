import 'package:bilihear/core/models/media_track.dart';
import 'package:bilihear/features/player/player_navigation.dart';
import 'package:bilihear/state/auth_controller.dart';
import 'package:bilihear/state/library_controllers.dart';
import 'package:bilihear/state/local_favorites_controller.dart';
import 'package:bilihear/state/player_controller.dart';
import 'package:bilihear/widgets/folder_tile.dart';
import 'package:bilihear/widgets/local_data_banner.dart';
import 'package:bilihear/widgets/track_action_menu.dart';
import 'package:bilihear/widgets/track_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Favourites half of the library: Bilibili folders when signed in, the
/// on-device list otherwise.
class FavoritesTab extends ConsumerWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(
      authControllerProvider.select((state) => state.isLoggedIn),
    );
    return Column(
      children: [
        if (!loggedIn) const LocalDataBanner(message: '未登录，当前显示本地收藏'),
        Expanded(
          child: loggedIn ? const _CloudFolders() : const _LocalFavorites(),
        ),
      ],
    );
  }
}

class _CloudFolders extends ConsumerWidget {
  const _CloudFolders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(favFoldersProvider);
    final reload = ref.read(favFoldersProvider.notifier).reload;

    return RefreshIndicator(
      onRefresh: reload,
      child: folders.when(
        loading: () => const _CenteredList(child: CircularProgressIndicator()),
        error: (error, _) => _CenteredList(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('加载失败：$error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: reload, child: const Text('重试')),
            ],
          ),
        ),
        data: (list) => list.isEmpty
            ? const _CenteredList(child: Text('暂无收藏夹'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) =>
                    FolderTile(folder: list[index]),
              ),
      ),
    );
  }
}

class _LocalFavorites extends ConsumerWidget {
  const _LocalFavorites();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(localFavoritesProvider);

    if (tracks.isEmpty) {
      return const _CenteredList(child: Text('还没有本地收藏，播放时点击收藏即可添加'));
    }

    return ListView.builder(
      itemCount: tracks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _Toolbar(
            count: tracks.length,
            onPlayAll: () =>
                ref.read(playerStateProvider.notifier).playTracks(tracks),
          );
        }
        final track = tracks[index - 1];
        return TrackTile(
          track: track,
          onTap: () async {
            await ref
                .read(playerStateProvider.notifier)
                .playTracks(tracks, startIndex: index - 1);
            if (!context.mounted) return;
            await openPlayerIfEnabled(context, ref);
          },
          onLongPress: () => showTrackActions(
            context,
            ref,
            track: track,
            showFavorite: false,
            deleteLabel: '移出收藏夹',
            onDelete: () => _confirmRemove(context, ref, track),
          ),
        );
      },
    );
  }

  /// Asks before dropping a locally stored favourite.
  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    MediaTrack track,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移出收藏夹'),
        content: Text('确定将「${track.displayTitle}」移出本地收藏夹吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(localFavoritesProvider.notifier).remove(track);
    }
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.count, required this.onPlayAll});

  final int count;
  final VoidCallback onPlayAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '共 $count 首',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: onPlayAll,
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('播放全部'),
        ),
      ],
    ),
  );
}

class _CenteredList extends StatelessWidget {
  const _CenteredList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 140),
      Center(child: child),
    ],
  );
}
