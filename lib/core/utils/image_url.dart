/// Helpers for Bilibili image URLs.
abstract final class ImageUrl {
  /// Ensures the URL uses HTTPS and optionally appends a BFS image processing
  /// suffix so covers are downloaded at the size actually displayed.
  static String? resolve(String? url, {int? width}) {
    if (url == null || url.isEmpty) return null;
    var result = url.startsWith('//')
        ? 'https:$url'
        : url.replaceFirst(RegExp(r'^http://'), 'https://');
    if (width != null && !result.contains('@')) {
      result = '$result@${width}w_${width}h_1c.webp';
    }
    return result;
  }

  /// Requested pixel size for list thumbnails.
  static const int thumbnailWidth = 360;
}
