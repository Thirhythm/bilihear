import 'dart:convert';

import 'package:bilihear/core/models/media_track.dart';
import 'package:bilihear/data/repositories/local_favorites_repository.dart';
import 'package:bilihear/data/repositories/local_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MediaTrack _track(String bvid, int cid, {String? title}) => MediaTrack(
  bvid: bvid,
  aid: 7,
  cid: cid,
  title: title ?? '曲目$cid',
  artist: 'UP主',
  cover: '',
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('LocalFavoritesRepository', () {
    test('stores newest first and survives a reload', () async {
      final repository = LocalFavoritesRepository(prefs);
      await repository.add(_track('BV1', 1, title: '第一首'));
      await repository.add(_track('BV2', 2, title: '第二首'));

      final reloaded = LocalFavoritesRepository(prefs).load();
      expect(reloaded.map((track) => track.title), ['第二首', '第一首']);
      expect(reloaded.first.cid, 2);
    });

    test('re-adding a track moves it to the front without duplicating', () async {
      final repository = LocalFavoritesRepository(prefs);
      await repository.add(_track('BV1', 1));
      await repository.add(_track('BV2', 2));
      await repository.add(_track('BV1', 1));

      final tracks = repository.load();
      expect(tracks, hasLength(2));
      expect(tracks.map((track) => track.id), ['BV1:1', 'BV2:2']);
    });

    test('merges a placeholder with its resolved twin', () async {
      final repository = LocalFavoritesRepository(prefs);
      // Favourited before the player resolved the part id …
      await repository.add(_track('BV1', 0));
      // … then again as the real part.
      await repository.add(_track('BV1', 999));

      final tracks = repository.load();
      expect(tracks, hasLength(1), reason: '同一个分P不应收藏两次');
      expect(tracks.single.cid, 999);
    });

    test('remove and clear', () async {
      final repository = LocalFavoritesRepository(prefs);
      await repository.add(_track('BV1', 1));
      await repository.add(_track('BV2', 2));

      await repository.remove(_track('BV1', 1));
      expect(repository.load().map((track) => track.id), ['BV2:2']);

      await repository.clear();
      expect(repository.load(), isEmpty);
    });

    test('starts empty and tolerates a corrupted payload', () async {
      expect(LocalFavoritesRepository(prefs).load(), isEmpty);
      await prefs.setString('local_favorites_v1', 'not-json');
      expect(LocalFavoritesRepository(prefs).load(), isEmpty);
    });
  });

  group('LocalHistoryRepository', () {
    test('moves a replayed track to the front', () async {
      final repository = LocalHistoryRepository(prefs);
      await repository.record(_track('BV1', 1, title: 'A'));
      await repository.record(_track('BV2', 2, title: 'B'));
      await repository.record(_track('BV1', 1, title: 'A'));

      expect(repository.load().map((track) => track.title), ['A', 'B']);
    });

    test('caps the list so storage cannot grow without bound', () async {
      final repository = LocalHistoryRepository(prefs);
      for (var index = 0; index < 130; index++) {
        await repository.record(_track('BV$index', index));
      }

      final tracks = repository.load();
      expect(tracks, hasLength(100));
      expect(tracks.first.id, 'BV129:129');
    });

    test('remove and clear', () async {
      final repository = LocalHistoryRepository(prefs);
      await repository.record(_track('BV1', 1));
      await repository.record(_track('BV2', 2));

      await repository.remove('BV2:2');
      expect(repository.load().map((track) => track.id), ['BV1:1']);

      await repository.clear();
      expect(repository.load(), isEmpty);
    });

    test('never stores a track whose part id is still unknown', () async {
      final repository = LocalHistoryRepository(prefs);

      // A placeholder (cid 0) comes from search / favourites and is expanded by
      // the player into real parts afterwards.
      await repository.record(_track('BV1', 0, title: '同一首歌'));

      expect(repository.load(), isEmpty);
      expect(prefs.getString('local_history_v1'), isNull);
    });

    test('drops already stored placeholders so the list has no duplicates', () async {
      // Mirrors the payload an older build produced for one played song: the
      // resolved part plus the placeholder it was expanded from.
      await prefs.setString(
        'local_history_v1',
        jsonEncode([
          {
            'bvid': 'BV1',
            'aid': 7,
            'cid': 999,
            'title': '同一首歌',
            'artist': 'UP主',
            'cover': '',
            'durationMs': 133000,
            'page': 1,
            'partTitle': '可视化',
            'playCount': 0,
          },
          {
            'bvid': 'BV1',
            'aid': 7,
            'cid': 0,
            'title': '同一首歌',
            'artist': 'UP主',
            'cover': '',
            'durationMs': 266000,
            'page': 1,
            'partTitle': null,
            'playCount': 0,
          },
        ]),
      );

      final tracks = LocalHistoryRepository(prefs).load();

      expect(tracks, hasLength(1), reason: '同一首歌不应出现两条记录');
      expect(tracks.single.cid, 999);
      expect(tracks.single.partTitle, '可视化');
    });
  });
}
