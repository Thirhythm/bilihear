import 'package:bilihear/core/api/api_exception.dart';
import 'package:bilihear/core/models/media_track.dart';
import 'package:bilihear/state/auth_controller.dart';
import 'package:bilihear/state/library_controllers.dart';
import 'package:bilihear/state/local_favorites_controller.dart';
import 'package:bilihear/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets the user store the current track: in a Bilibili folder when signed in,
/// in the on-device favourites otherwise.
class FavoriteSheet extends ConsumerStatefulWidget {
  const FavoriteSheet({super.key, required this.track});

  final MediaTrack track;

  static Future<void> show(BuildContext context, {required MediaTrack track}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => FavoriteSheet(track: track),
      );

  @override
  ConsumerState<FavoriteSheet> createState() => _FavoriteSheetState();
}

class _FavoriteSheetState extends ConsumerState<FavoriteSheet> {
  final Set<int> _selected = {};
  bool _busy = false;

  // --- Local favourites ---------------------------------------------------

  Future<void> _setLocalFavorite(bool favorite) async {
    if (_busy) return;
    setState(() => _busy = true);
    final controller = ref.read(localFavoritesProvider.notifier);
    if (favorite) {
      await controller.add(widget.track);
    } else {
      await controller.remove(widget.track);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(favorite ? '已添加到本地收藏夹' : '已取消收藏');
  }

  // --- Cloud folders ------------------------------------------------------

  Future<void> _addToFolders() async {
    if (_selected.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(favRepositoryProvider)
          .dealResources(aid: widget.track.aid, addTo: _selected.toList());
      ref.invalidate(favFoldersProvider);
      ref.invalidate(favStatusProvider(widget.track.aid));
      if (!mounted) return;
      _toast('已添加到 ${_selected.length} 个收藏夹');
      setState(_selected.clear);
    } on BiliApiException catch (error) {
      if (mounted) _toast(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFromAllFolders() async {
    final folders = ref.read(favFoldersProvider).value ?? const [];
    if (folders.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(favRepositoryProvider)
          .dealResources(
            aid: widget.track.aid,
            removeFrom: [for (final folder in folders) folder.id],
          );
      ref.invalidate(favFoldersProvider);
      ref.invalidate(favStatusProvider(widget.track.aid));
      if (!mounted) return;
      _toast('已取消收藏');
    } on BiliApiException catch (error) {
      if (mounted) _toast(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(
      authControllerProvider.select((state) => state.isLoggedIn),
    );
    return loggedIn ? _buildCloud(context) : _buildLocal(context);
  }

  Widget _buildLocal(BuildContext context) {
    final isFavorite = ref.watch(
      localFavoritesProvider.select(
        (tracks) => tracks.any((item) => item.partKey == widget.track.partKey),
      ),
    );

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, subtitle: isFavorite ? '已在本地收藏夹' : '未收藏'),
          const Divider(height: 1),
          CheckboxListTile(
            value: isFavorite,
            onChanged: _busy
                ? null
                : (checked) => _setLocalFavorite(checked ?? false),
            title: const Text('本地收藏夹'),
            subtitle: const Text('登录后可同步哔哩哔哩云端收藏夹'),
          ),
        ],
      ),
    );
  }

  Widget _buildCloud(BuildContext context) {
    final folders = ref.watch(favFoldersProvider);
    final status = ref.watch(favStatusProvider(widget.track.aid));
    final theme = Theme.of(context);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(
            context,
            subtitle: status.when(
              data: (favoured) => favoured ? '已收藏' : '未收藏',
              loading: () => '正在获取收藏状态…',
              error: (_, _) => '未收藏',
            ),
            trailing: (status.value ?? false)
                ? TextButton(
                    onPressed: _busy ? null : _removeFromAllFolders,
                    child: const Text('取消收藏'),
                  )
                : null,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('添加到收藏夹', style: theme.textTheme.labelLarge),
          ),
          Expanded(
            child: folders.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('收藏夹加载失败：$error')),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('暂无收藏夹'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final folder = list[index];
                        return CheckboxListTile(
                          value: _selected.contains(folder.id),
                          onChanged: (checked) => setState(() {
                            if (checked ?? false) {
                              _selected.add(folder.id);
                            } else {
                              _selected.remove(folder.id);
                            }
                          }),
                          title: Text(
                            folder.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('${folder.mediaCount} 个内容'),
                        );
                      },
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _busy || _selected.isEmpty ? null : _addToFolders,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite_rounded),
                label: Text(_selected.isEmpty ? '请选择收藏夹' : '添加到所选收藏夹'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context, {
    required String subtitle,
    Widget? trailing,
  }) => ListTile(
    title: Text(
      widget.track.displayTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall,
    ),
    subtitle: Text(subtitle),
    trailing: trailing,
  );
}
