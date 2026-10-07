import 'package:bilihear/core/api/api_exception.dart';
import 'package:bilihear/core/models/fav_folder.dart';
import 'package:bilihear/core/models/media_track.dart';
import 'package:bilihear/features/player/player_navigation.dart';
import 'package:bilihear/state/library_controllers.dart';
import 'package:bilihear/state/player_controller.dart';
import 'package:bilihear/state/providers.dart';
import 'package:bilihear/widgets/player_scaffold.dart';
import 'package:bilihear/widgets/track_action_menu.dart';
import 'package:bilihear/widgets/track_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contents of a single favourite folder, playable as a queue.
class FolderDetailPage extends ConsumerStatefulWidget {
  const FolderDetailPage({super.key, required this.folder});

  final FavFolder folder;

  @override
  ConsumerState<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends ConsumerState<FolderDetailPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(favMediaProvider(widget.folder.id).notifier).loadMore();
    }
  }

  Future<void> _removeTrack(MediaTrack track) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移出收藏夹'),
        content: Text('确定将「${track.title}」移出「${widget.folder.title}」吗？'),
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
    if (!(confirmed ?? false) || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(favRepositoryProvider)
          .removeFromFolder(mediaId: widget.folder.id, aids: [track.aid]);
      ref.invalidate(favMediaProvider(widget.folder.id));
      ref.invalidate(favFoldersProvider);
      ref.invalidate(favStatusProvider(track.aid));
      messenger.showSnackBar(const SnackBar(content: Text('已移出收藏夹')));
    } on BiliApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(favMediaProvider(widget.folder.id));
    final player = ref.read(playerStateProvider.notifier);

    return PlayerScaffold(
      title: Text(
        widget.folder.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        media.maybeWhen(
          data: (page) => page.items.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: '播放全部',
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  onPressed: () => player.playTracks(page.items),
                ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
      body: media.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('加载失败：$error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(favMediaProvider(widget.folder.id)),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        data: (page) => page.items.isEmpty
            ? const Center(child: Text('该收藏夹暂无内容'))
            : ListView.builder(
                controller: _scrollController,
                itemCount: page.items.length + (page.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= page.items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    );
                  }
                  final track = page.items[index];
                  return TrackTile(
                    track: track,
                    onTap: () async {
                      await player.playTracks(page.items, startIndex: index);
                      if (!context.mounted) return;
                      await openPlayerIfEnabled(context, ref);
                    },
                    onLongPress: () => showTrackActions(
                      context,
                      ref,
                      track: track,
                      showFavorite: false,
                      deleteLabel: '移出收藏夹',
                      onDelete: () => _removeTrack(track),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
