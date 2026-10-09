import 'package:bilihear/core/utils/image_url.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Square cover image with a graceful placeholder.
///
/// The requested resolution follows the rendered size so list thumbnails do not
/// download full sized artwork.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    this.size = 56,
    this.radius = 8,
  });

  final String url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = ImageUrl.resolve(url, width: _requestedWidth);
    // Decode the bitmap at the rendered resolution instead of the downloaded
    // one, so list thumbnails stay tiny inside the image cache.
    final decodeWidth = (size * MediaQuery.devicePixelRatioOf(context)).ceil();

    Widget fallback() => ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.42,
        color: scheme.onSurfaceVariant,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: resolved == null
            ? fallback()
            : CachedNetworkImage(
                imageUrl: resolved,
                fit: BoxFit.cover,
                memCacheWidth: decodeWidth,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, _) => fallback(),
                errorWidget: (_, _, _) => fallback(),
              ),
      ),
    );
  }

  int get _requestedWidth {
    if (size <= 80) return ImageUrl.thumbnailWidth;
    if (size <= 280) return 544;
    return 1024;
  }
}
