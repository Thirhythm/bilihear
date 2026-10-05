import 'package:bilihear/core/api/api_exception.dart';
import 'package:bilihear/core/models/media_track.dart';
import 'package:bilihear/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
class SearchState {
  const SearchState({
    this.keyword = '',
    this.results = const [],
    this.page = 1,
    this.hasMore = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final String keyword;
  final List<MediaTrack> results;
  final int page;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;
  final String? error;

  bool get isEmptyResult =>
      !loading && results.isEmpty && error == null && keyword.isNotEmpty;
}

final NotifierProvider<SearchController, SearchState> searchControllerProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);

/// Keyword suggestions for a partially typed term.
///
/// The lookup is debounced by keeping the pending delay inside the provider:
/// as soon as the term changes the provider is disposed, so an abandoned
/// keystroke never reaches the network.
final searchSuggestionsProvider = FutureProvider.family<List<String>, String>((
  ref,
  term,
) async {
  final trimmed = term.trim();
  if (trimmed.isEmpty) return const [];

  await Future<void>.delayed(const Duration(milliseconds: 300));
  if (!ref.mounted) return const [];

  return ref.read(searchRepositoryProvider).suggest(trimmed);
}, isAutoDispose: true);

/// Video search with pagination.
class SearchController extends Notifier<SearchState> {
  bool _loadingMore = false;

  @override
  SearchState build() => const SearchState();

  Future<void> search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      state = const SearchState();
      return;
    }
    state = SearchState(keyword: trimmed, loading: true);
    try {
      final result = await ref
          .read(searchRepositoryProvider)
          .searchVideos(keyword: trimmed);
      if (!ref.mounted) return;
      state = SearchState(
        keyword: trimmed,
        results: result.items,
        page: result.page,
        hasMore: result.hasMore,
      );
    } on BiliApiException catch (error) {
      if (!ref.mounted) return;
      state = SearchState(keyword: trimmed, error: error.message);
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || !state.hasMore || state.loading) return;
    _loadingMore = true;
    state = SearchState(
      keyword: state.keyword,
      results: state.results,
      page: state.page,
      hasMore: state.hasMore,
      loadingMore: true,
    );
    try {
      final result = await ref
          .read(searchRepositoryProvider)
          .searchVideos(keyword: state.keyword, page: state.page + 1);
      if (!ref.mounted) return;
      state = SearchState(
        keyword: state.keyword,
        results: [...state.results, ...result.items],
        page: result.page,
        hasMore: result.hasMore,
      );
    } on BiliApiException catch (error) {
      if (!ref.mounted) return;
      state = SearchState(
        keyword: state.keyword,
        results: state.results,
        page: state.page,
        hasMore: state.hasMore,
        error: error.message,
      );
    } finally {
      _loadingMore = false;
    }
  }

  void clear() => state = const SearchState();
}
