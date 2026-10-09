/// Helpers for Bilibili image URLs.
abstract final class ImageUrl {
  /// Ensures the URL uses HTTPS and optionally appends a BFS image processing
  /// suffix so covers are downloaded at the size actually displayed.
  ///
  /// [height] defaults to [width]; pass it for artwork that is rendered in a
  /// non-square box so the download matches the displayed ratio.
  static String? resolve(String? url, {int? width, int? height}) {
    if (url == null || url.isEmpty) return null;
    var result = url.startsWith('//')
        ? 'https:$url'
        : url.replaceFirst(RegExp(r'^http://'), 'https://');
    if (width != null && !result.contains('@')) {
      result = '$result@${width}w_${height ?? width}h_1c.webp';
    }
    return result;
  }

  /// Requested pixel size for list thumbnails.
  static const int thumbnailWidth = 360;
}
