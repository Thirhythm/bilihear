import 'package:bilihear/core/api/api_exception.dart';
import 'package:bilihear/core/api/bili_client.dart';
import 'package:bilihear/core/api/bili_endpoints.dart';
import 'package:bilihear/core/models/json_utils.dart';
import 'package:bilihear/core/models/media_track.dart';
import 'package:bilihear/core/models/paged_result.dart';
import 'package:bilihear/core/utils/text_utils.dart';

/// Video search sorted by relevance, with pagination.
class SearchRepository {
  SearchRepository(this._client);

  final BiliClient _client;

  static const int pageSize = 20;

  Future<PagedResult<MediaTrack>> searchVideos({
    required String keyword,
    int page = 1,
  }) async {
    final response = await _client.getJson(
      BiliEndpoints.searchType,
      signed: true,
      query: {
        'search_type': 'video',
        'keyword': keyword,
        'page': page,
        'order': 'totalrank',
        'platform': 'pc',
      },
    );
    final data = JsonUtils.map(response['data']);
    final items = <MediaTrack>[
      for (final result in JsonUtils.list(data['result']))
        if (JsonUtils.string(result['bvid']).isNotEmpty) _toTrack(result),
    ];

    final numPages = JsonUtils.integer(data['numPages']);
    return PagedResult(
      items: items,
      page: JsonUtils.integer(data['page'], fallback: page),
      hasMore: page < numPages && items.isNotEmpty,
      total: JsonUtils.integer(data['numResults']),
    );
  }

  /// Fetches up to ten keyword suggestions for a partially typed [term].
  ///
  /// Suggestion failures never surface to the user: the UI simply shows none.
  Future<List<String>> suggest(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final response = await _client.getJson(
        BiliEndpoints.searchSuggest,
        baseUrl: BiliEndpoints.suggestBase,
        query: {
          'term': trimmed,
          'main_ver': 'v1',
          'suggest_type': 'accurate',
          'sub_type': 'tag',
        },
      );
      final result = JsonUtils.map(response['result']);
      final suggestions = <String>[];
      for (final tag in JsonUtils.list(result['tag'])) {
        // `value` is the plain keyword, `name` carries highlight markup.
        final value = JsonUtils.string(tag['value']);
        final text = value.isNotEmpty
            ? value
            : TextUtils.stripHtml(tag['name']);
        if (text.isEmpty || suggestions.contains(text)) continue;
        suggestions.add(text);
      }
      return suggestions;
    } on BiliApiException {
      return const [];
    }
  }

  MediaTrack _toTrack(Map<String, dynamic> json) => MediaTrack(
    bvid: JsonUtils.string(json['bvid']),
    aid: JsonUtils.integer(json['aid']),
    // The part id is unknown until the video detail is loaded.
    cid: 0,
    title: TextUtils.stripHtml(json['title']),
    artist: TextUtils.stripHtml(json['author']),
    cover: JsonUtils.string(json['pic']),
    artistId: JsonUtils.integer(json['mid']),
    duration: JsonUtils.flexibleDuration(json['duration']),
    playCount: JsonUtils.integer(json['play']),
  );
}
