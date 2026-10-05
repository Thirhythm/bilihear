/// Text cleanup for API values that embed HTML markup.
abstract final class TextUtils {
  static final RegExp _tags = RegExp(r'<[^>]*>');

  /// Removes HTML tags (search results highlight matches with `<em>`) and
  /// decodes the handful of entities Bilibili actually emits.
  static String stripHtml(Object? value) {
    if (value == null) return '';
    final text = value is String ? value : '$value';
    return text
        .replaceAll(_tags, '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
