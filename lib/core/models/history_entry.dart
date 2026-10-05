import 'json_utils.dart';
import 'media_track.dart';

/// One entry of the watch history (`/x/web-interface/history/cursor`).
class HistoryEntry {
  const HistoryEntry({
    required this.track,
    required this.viewedAt,
    this.progress = Duration.zero,
    this.avid = 0,
  });

  final MediaTrack track;
  final DateTime viewedAt;

  /// Playback position reached during the last visit.
  final Duration progress;

  /// `avid` of the video (`history.oid`), used when deleting the entry.
  final int avid;

  /// Identifier accepted by `/x/v2/history/delete` for archive entries.
  String? get deleteKid =>
      track.bvid.isNotEmpty && avid > 0 ? 'archive_$avid' : null;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    final viewAt = JsonUtils.integer(json['view_at']);
    // The playable video identity lives in the nested `history` object.
    final history = JsonUtils.map(json['history']);
    return HistoryEntry(
      track: MediaTrack(
        bvid: JsonUtils.string(history['bvid']),
        aid: JsonUtils.integer(history['oid']),
        cid: JsonUtils.integer(history['cid']),
        title: JsonUtils.string(json['title'], fallback: '未知内容'),
        artist: JsonUtils.string(json['author_name'], fallback: '未知作者'),
        cover: JsonUtils.string(json['cover']),
        artistId: JsonUtils.integer(json['author_mid']),
        duration: JsonUtils.durationFromSeconds(json['duration']),
        page: JsonUtils.integer(history['page'], fallback: 1),
        partTitle: JsonUtils.nullableString(json['show_title']),
      ),
      viewedAt: viewAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(viewAt * 1000)
          : DateTime.fromMillisecondsSinceEpoch(0),
      progress: JsonUtils.durationFromSeconds(json['progress']),
      avid: JsonUtils.integer(history['oid']),
    );
  }

  Map<String, dynamic> toJson() => {
    'track': track.toJson(),
    'viewedAt': viewedAt.millisecondsSinceEpoch,
    'progressSec': progress.inSeconds,
    'avid': avid,
  };

  factory HistoryEntry.fromCacheJson(Map<String, dynamic> json) => HistoryEntry(
    track: MediaTrack.fromJson(JsonUtils.map(json['track'])),
    viewedAt: DateTime.fromMillisecondsSinceEpoch(
      JsonUtils.integer(json['viewedAt']),
    ),
    progress: JsonUtils.durationFromSeconds(json['progressSec']),
    avid: JsonUtils.integer(json['avid']),
  );

  /// History items without a resolvable video cannot be played.
  bool get isValid => track.bvid.isNotEmpty && track.cid > 0;
}
