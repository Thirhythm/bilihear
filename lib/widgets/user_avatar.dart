import 'package:bilihear/core/utils/image_url.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Circular account avatar with a placeholder for logged-out users.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.url, this.size = 48});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = ImageUrl.resolve(url, width: size <= 96 ? 180 : 512);

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.surfaceContainerHighest,
      foregroundImage: resolved == null ? null : CachedNetworkImageProvider(resolved),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.6,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
