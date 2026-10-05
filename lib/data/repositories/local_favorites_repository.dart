import 'dart:convert';

import 'package:bilihear/core/models/media_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device favourites, used when no Bilibili session is available.
///
/// A single flat list: Bilibili's multi-folder model only exists server side,
/// so the local fallback keeps things simple.
class LocalFavoritesRepository {
  LocalFavoritesRepository(this._prefs);

  static const String _key = 'local_favorites_v1';
  static const int _limit = 500;

  final SharedPreferences _prefs;

  List<MediaTrack> load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            MediaTrack.fromJson(item.map((k, v) => MapEntry('$k', v))),
      ];
    } on FormatException {
      return const [];
    }
  }

  /// Adds [track] to the front (newest first) and returns the updated list.
  ///
  /// Entries are matched by video part, not by `cid`, so a favourite added
  /// while the part id was still unknown merges with its resolved twin instead
  /// of leaving a duplicate.
  Future<List<MediaTrack>> add(MediaTrack track) async {
    final tracks = [...load()]
      ..removeWhere((item) => item.partKey == track.partKey);
    tracks.insert(0, track);
    if (tracks.length > _limit) {
      tracks.removeRange(_limit, tracks.length);
    }
    await _save(tracks);
    return tracks;
  }

  Future<List<MediaTrack>> remove(MediaTrack track) async {
    final tracks = [...load()]
      ..removeWhere((item) => item.partKey == track.partKey);
    await _save(tracks);
    return tracks;
  }

  Future<void> clear() => _prefs.remove(_key);

  Future<void> _save(List<MediaTrack> tracks) => _prefs.setString(
    _key,
    jsonEncode([for (final track in tracks) track.toJson()]),
  );
}
