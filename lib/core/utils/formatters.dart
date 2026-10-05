/// Presentation helpers shared across the UI.
abstract final class Formatters {
  /// `mm:ss`, or `h:mm:ss` for content longer than an hour.
  static String duration(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  /// Compact play count using Chinese units (1.2万 / 3.4亿).
  static String count(int value) {
    if (value >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}亿';
    }
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    }
    return '$value';
  }

  /// Relative time such as `刚刚`, `3分钟前`, `2天前`.
  static String relativeTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inSeconds < 60) return '刚刚';
    if (difference.inMinutes < 60) return '${difference.inMinutes}分钟前';
    if (difference.inHours < 24) return '${difference.inHours}小时前';
    if (difference.inDays < 30) return '${difference.inDays}天前';
    if (difference.inDays < 365) return '${(difference.inDays / 30).floor()}个月前';
    return '${(difference.inDays / 365).floor()}年前';
  }
}
