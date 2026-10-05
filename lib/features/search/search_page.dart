import 'package:bilihear/features/player/player_navigation.dart';
import 'package:bilihear/state/player_controller.dart';
import 'package:bilihear/state/search_controller.dart';
import 'package:bilihear/widgets/track_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Searches Bilibili videos and plays the selected result's audio.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _queryController
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(searchControllerProvider.notifier).loadMore();
    }
  }

  /// The suggestion term is derived from the controller, so every keystroke
  /// must rebuild the page for the list to follow the text.
  void _onQueryChanged() => setState(() {});

  /// Runs a search and closes the suggestion list.
  void _searchWith(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    if (_queryController.text != trimmed) {
      _queryController.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }
    FocusScope.of(context).unfocus();
    ref.read(searchControllerProvider.notifier).search(trimmed);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    // Suggestions replace the results while the query differs from the last
    // executed search.
    final term = _queryController.text.trim();
    final showSuggestions = term.isNotEmpty && term != state.keyword;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _queryController,
          textInputAction: TextInputAction.search,
          onSubmitted: _searchWith,
          decoration: const InputDecoration(
            hintText: '搜索......',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _searchWith(_queryController.text),
          ),
          if (state.results.isNotEmpty || showSuggestions)
            IconButton(
              tooltip: '清除',
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _queryController.clear();
                ref.read(searchControllerProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: showSuggestions
          ? _SuggestionList(term: term, onSelected: _searchWith)
          : _SearchBody(
              state: state,
              scrollController: _scrollController,
              onRetry: () => ref
                  .read(searchControllerProvider.notifier)
                  .search(state.keyword),
              onPlay: (index) async {
                final track = state.results[index];
                await ref
                    .read(playerStateProvider.notifier)
                    .playVideo(track.bvid);
                if (!context.mounted) return;
                await openPlayerIfEnabled(context, ref);
              },
            ),
    );
  }
}

/// Keyword suggestions shown while the user is still typing.
class _SuggestionList extends ConsumerWidget {
  const _SuggestionList({required this.term, required this.onSelected});

  final String term;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(searchSuggestionsProvider(term));

    return suggestions.when(
      // Stay blank rather than flashing a spinner on every keystroke.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => ListTile(
                dense: true,
                leading: const Icon(Icons.search_rounded, size: 20),
                title: Text(
                  items[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onSelected(items[index]),
              ),
            ),
    );
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.state,
    required this.scrollController,
    required this.onRetry,
    required this.onPlay,
  });

  final SearchState state;
  final ScrollController scrollController;
  final VoidCallback onRetry;
  final void Function(int index) onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return _CenteredMessage(
        icon: Icons.error_outline_rounded,
        message: state.error!,
        action: TextButton(onPressed: onRetry, child: const Text('重试')),
      );
    }
    if (state.keyword.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.search_rounded,
        message: '输入关键词搜索',
      );
    }
    if (state.isEmptyResult) {
      return const _CenteredMessage(
        icon: Icons.sentiment_dissatisfied_rounded,
        message: '没有找到相关内容，换个关键词试试',
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: state.results.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.results.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: state.loadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text('上拉加载更多', style: theme.textTheme.bodySmall),
            ),
          );
        }
        return TrackTile(
          track: state.results[index],
          onTap: () => onPlay(index),
        );
      },
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  /// Centred while there is room, scrollable once the on-screen keyboard leaves
  /// less space than the content needs, so the page can never overflow.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
