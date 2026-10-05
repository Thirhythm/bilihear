import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Implements Bilibili's **WBI** request signature.
///
/// See `docs/misc/sign/wbi.md` for the authoritative description of the
/// algorithm. The signer is stateless apart from the cached `img_key` /
/// `sub_key`, which are refreshed daily by the API client.
class WbiSigner {
  WbiSigner({required this.imgKey, required this.subKey});

  /// Token extracted from `wbi_img.img_url` (the file name without extension).
  final String imgKey;

  /// Token extracted from `wbi_img.sub_url`.
  final String subKey;

  /// Positional permutation applied to `img_key + sub_key`.
  static const List<int> _mixinKeyEncTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, //
    27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, //
    37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, //
    22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
  ];

  /// Derives the 32 character `mixin_key` from the raw key pair.
  static String mixinKey(String rawKey) {
    final buffer = StringBuffer();
    for (final index in _mixinKeyEncTab) {
      if (index < rawKey.length) {
        buffer.write(rawKey[index]);
      }
    }
    final key = buffer.toString();
    return key.length > 32 ? key.substring(0, 32) : key;
  }

  static String _strip(Match _) => '';

  static final RegExp _forbidden = RegExp(r"[!'()*]");

  /// Signs [params] and returns a new map containing `wts` and `w_rid`
  /// alongside the original values (all encoded as strings).
  ///
  /// The returned values are already sanitised, so building the request query
  /// with `Uri.encodeComponent` yields exactly the string that was signed.
  Map<String, String> sign(Map<String, Object?> params) {
    final signed = <String, String>{};
    params.forEach((key, value) {
      if (value == null) return;
      signed[key] = _sanitize(value.toString());
    });

    final wts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    signed['wts'] = wts;

    final keys = signed.keys.toList()..sort();
    final query = keys
        .map((key) => '${Uri.encodeComponent(key)}=${Uri.encodeComponent(signed[key]!)}')
        .join('&');

    final digest = md5.convert(
      utf8.encode('$query${mixinKey(imgKey + subKey)}'),
    );
    signed['w_rid'] = digest.toString();
    return signed;
  }

  /// Mirrors the `!'()*` filtering JavaScript clients apply before encoding.
  static String _sanitize(String value) =>
      value.replaceAllMapped(_forbidden, _strip);
}
