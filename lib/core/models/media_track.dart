import 'json_utils.dart';

/// A single playable entry in the app: one video part (`P`) of a Bilibili
/// video, played as audio only.
///
/// The model is intentionally serialisable so the current queue can be
/// restored after the app is restarted.
class MediaTrack {
  const MediaTrack({
    required this.bvid,
    required this.aid,
    required this.cid,
    required this.title,
    required this.artist,
    required this.cover,
    this.artistId = 0,
    this.duration = Duration.zero,
    this.page = 1,
    this.partTitle,
    this.playCount = 0,
  });

  final String bvid;
  final int aid;
  final int cid;
  final String title;
  final String artist;
  final String cover;
  final int artistId;
  final Duration duration;

  /// Part index inside a multi-part video (`pages[].page`).
  final int page;

  /// Part name (`pages[].part`) when the video has multiple parts.
  final String? partTitle;

  final int playCount;

  /// A stable identity for a queue entry.
  String get id => '$bvid:$cid';

  /// Identity of the video part, available even before the part id is known.
  ///
  /// Queue entries coming from search or a favourite folder only carry a
  /// [bvid]; the player fills in [cid] once the video detail is loaded, so
  /// comparing parts must not depend on [cid].
  String get partKey => '$bvid:$page';

  /// `true` once the part id is known, i.e. the entry can be played directly.
  bool get isResolved => cid > 0;

  bool get hasParts => partTitle != null && partTitle!.isNotEmpty;

  /// Title including the part name when it adds information.
  String get displayTitle => hasParts && partTitle != title
      ? '$title · $partTitle'
      : title;

  factory MediaTrack.fromJson(Map<String, dynamic> json) => MediaTrack(
    bvid: JsonUtils.string(json['bvid']),
    aid: JsonUtils.integer(json['aid']),
    cid: JsonUtils.integer(json['cid']),
    title: JsonUtils.string(json['title']),
    artist: JsonUtils.string(json['artist']),
    cover: JsonUtils.string(json['cover']),
    artistId: JsonUtils.integer(json['artistId']),
    duration: Duration(milliseconds: JsonUtils.integer(json['durationMs'])),
    page: JsonUtils.integer(json['page'], fallback: 1),
    partTitle: JsonUtils.nullableString(json['partTitle']),
    playCount: JsonUtils.integer(json['playCount']),
  );

  Map<String, dynamic> toJson() => {
    'bvid': bvid,
    'aid': aid,
    'cid': cid,
    'title': title,
    'artist': artist,
    'cover': cover,
    'artistId': artistId,
    'durationMs': duration.inMilliseconds,
    'page': page,
    'partTitle': partTitle,
    'playCount': playCount,
  };

  MediaTrack copyWith({
    String? bvid,
    int? aid,
    int? cid,
    String? title,
    String? artist,
    String? cover,
    int? artistId,
    Duration? duration,
    int? page,
    String? partTitle,
    int? playCount,
  }) => MediaTrack(
    bvid: bvid ?? this.bvid,
    aid: aid ?? this.aid,
    cid: cid ?? this.cid,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    cover: cover ?? this.cover,
    artistId: artistId ?? this.artistId,
    duration: duration ?? this.duration,
    page: page ?? this.page,
    partTitle: partTitle ?? this.partTitle,
    playCount: playCount ?? this.playCount,
  );

  @override
  bool operator ==(Object other) =>
      other is MediaTrack && other.bvid == bvid && other.cid == cid;

  @override
  int get hashCode => Object.hash(bvid, cid);

  @override
  String toString() => 'MediaTrack($bvid/$cid, $title)';
}
