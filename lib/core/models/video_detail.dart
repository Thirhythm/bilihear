import 'json_utils.dart';
import 'media_track.dart';

/// One part (`P`) of a video.
class VideoPart {
  const VideoPart({
    required this.cid,
    required this.page,
    required this.title,
    required this.duration,
  });

  final int cid;
  final int page;
  final String title;
  final Duration duration;
}

/// Full metadata for a Bilibili video (`/x/web-interface/view`).
class VideoDetail {
  const VideoDetail({
    required this.bvid,
    required this.aid,
    required this.title,
    required this.cover,
    required this.description,
    required this.ownerName,
    required this.ownerId,
    required this.ownerFace,
    required this.parts,
    this.viewCount = 0,
    this.publishedAt,
  });

  final String bvid;
  final int aid;
  final String title;
  final String cover;
  final String description;
  final String ownerName;
  final int ownerId;
  final String ownerFace;
  final List<VideoPart> parts;
  final int viewCount;
  final DateTime? publishedAt;

  factory VideoDetail.fromJson(Map<String, dynamic> json) {
    final owner = JsonUtils.map(json['owner']);
    final stat = JsonUtils.map(json['stat']);
    final pages = JsonUtils.list(json['pages']);
    final fallbackDuration = JsonUtils.durationFromSeconds(json['duration']);
    final parts = pages.isEmpty
        ? <VideoPart>[
            VideoPart(
              cid: JsonUtils.integer(json['cid']),
              page: 1,
              title: JsonUtils.string(json['title']),
              duration: fallbackDuration,
            ),
          ]
        : [
            for (final page in pages)
              VideoPart(
                cid: JsonUtils.integer(page['cid']),
                page: JsonUtils.integer(page['page'], fallback: 1),
                title: JsonUtils.string(page['part'], fallback: 'P${page['page']}'),
                duration: JsonUtils.durationFromSeconds(page['duration']),
              ),
          ];

    final pubdate = JsonUtils.integer(json['pubdate']);
    return VideoDetail(
      bvid: JsonUtils.string(json['bvid']),
      aid: JsonUtils.integer(json['aid']),
      title: JsonUtils.string(json['title']),
      cover: JsonUtils.string(json['pic']),
      description: JsonUtils.string(json['desc']),
      ownerName: JsonUtils.string(owner['name'], fallback: '未知作者'),
      ownerId: JsonUtils.integer(owner['mid']),
      ownerFace: JsonUtils.string(owner['face']),
      parts: parts,
      viewCount: JsonUtils.integer(stat['view']),
      publishedAt: pubdate > 0
          ? DateTime.fromMillisecondsSinceEpoch(pubdate * 1000)
          : null,
    );
  }

  /// Expands every video part into a playable [MediaTrack].
  List<MediaTrack> toTracks() => [
    for (final part in parts)
      MediaTrack(
        bvid: bvid,
        aid: aid,
        cid: part.cid,
        title: title,
        artist: ownerName,
        cover: cover,
        artistId: ownerId,
        duration: part.duration,
        page: part.page,
        partTitle: parts.length > 1 ? part.title : null,
        playCount: viewCount,
      ),
  ];
}
