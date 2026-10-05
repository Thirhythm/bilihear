/// Generic paginated payload returned by the list repositories.
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.hasMore,
    this.total,
  });

  final List<T> items;
  final int page;
  final bool hasMore;
  final int? total;

  PagedResult<T> copyWith({List<T>? items, int? page, bool? hasMore, int? total}) =>
      PagedResult<T>(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        total: total ?? this.total,
      );
}
