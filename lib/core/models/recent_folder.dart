import 'fav_folder.dart';
import 'json_utils.dart';

/// A favourite folder (收藏夹) played from recently.
///
/// The account's folder list only exists server side, so the home page's
/// shortcut keeps just enough of it — identity plus the cover seen when the
/// folder was played — to offer the folder again afterwards.
class RecentFolder {
  const RecentFolder({
    required this.id,
    required this.title,
    required this.cover,
    this.mediaCount = 0,
  });

  final int id;
  final String title;

  /// Cover of the folder's first entry, captured when it was played.
  final String cover;
  final int mediaCount;

  /// The folder this shortcut opens again.
  FavFolder toFolder() =>
      FavFolder(id: id, title: title, mediaCount: mediaCount);

  factory RecentFolder.fromJson(Map<String, dynamic> json) => RecentFolder(
    id: JsonUtils.integer(json['id']),
    title: JsonUtils.string(json['title'], fallback: '未命名收藏夹'),
    cover: JsonUtils.string(json['cover']),
    mediaCount: JsonUtils.integer(json['mediaCount']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'cover': cover,
    'mediaCount': mediaCount,
  };

  @override
  bool operator ==(Object other) => other is RecentFolder && other.id == id;

  @override
  int get hashCode => id;

  @override
  String toString() => 'RecentFolder($id, $title)';
}
