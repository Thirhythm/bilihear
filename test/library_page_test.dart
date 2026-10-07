import 'package:bilihear/core/models/media_track.dart';
import 'package:bilihear/core/models/player_state.dart';
import 'package:bilihear/data/repositories/local_favorites_repository.dart';
import 'package:bilihear/data/repositories/local_history_repository.dart';
import 'package:bilihear/features/library/library_page.dart';
import 'package:bilihear/state/auth_controller.dart';
import 'package:bilihear/state/player_controller.dart';
import 'package:bilihear/state/providers.dart';
import 'package:bilihear/widgets/favorite_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signed-out session: the library must fall back to the on-device stores.
class _SignedOutAuth extends AuthController {
  @override
  AuthState build() => const AuthState(initialized: true);
}

const _favorite = MediaTrack(
  bvid: 'BV1',
  aid: 11,
  cid: 101,
  title: '本地收藏的歌曲',
  artist: 'UP主',
  cover: '',
);

const _played = MediaTrack(
  bvid: 'BV2',
  aid: 22,
  cid: 202,
  title: '本机播放过的歌曲',
  artist: 'UP主',
  cover: '',
);

Future<SharedPreferences> _seedPrefs() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await LocalFavoritesRepository(prefs).add(_favorite);
  await LocalHistoryRepository(prefs).record(_played);
  return prefs;
}

/// Reports [_played] as the queue without touching the audio service, and
/// answers 添加到下一首播放 the way the player would.
class _FakePlayer extends PlayerController {
  _FakePlayer({required this.queued});

  /// Whether the request found something to queue, i.e. the track was not
  /// already playing.
  final bool queued;

  @override
  PlayerState build() =>
      const PlayerState(queue: [_played], currentIndex: 0, playing: true);

  @override
  Future<bool> addToNext(MediaTrack track) async => queued;
}

Widget _wrap(
  SharedPreferences prefs,
  Widget home, {
  PlayerController Function()? player,
}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authControllerProvider.overrideWith(_SignedOutAuth.new),
    if (player != null) playerStateProvider.overrideWith(player),
  ],
  child: MaterialApp(home: home),
);

void main() {
  testWidgets('signed out, the library shows local favourites and history', (
    tester,
  ) async {
    final prefs = await _seedPrefs();
    await tester.pumpWidget(_wrap(prefs, const LibraryPage()));
    await tester.pumpAndSettle();

    expect(find.text('媒体库'), findsOneWidget);
    expect(find.text('收藏夹'), findsOneWidget);
    expect(find.text('播放历史'), findsOneWidget);
    expect(find.text('未登录，当前显示本地收藏'), findsOneWidget);

    // Local favourites are listed with a play-all action.
    expect(find.text(_favorite.title), findsOneWidget);
    expect(find.textContaining('共 1 首'), findsOneWidget);
    expect(find.text('播放全部'), findsOneWidget);
    // Actions live behind a long press, so no per-row buttons are shown.
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    // Switching tabs shows the on-device play history.
    await tester.tap(find.text('播放历史'));
    await tester.pumpAndSettle();

    expect(find.text('未登录，当前显示本地播放记录'), findsOneWidget);
    expect(find.text(_played.title), findsOneWidget);
    expect(find.textContaining('共 1 条'), findsOneWidget);
    expect(find.text('清空'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('long pressing a local favourite offers only removal', (
    tester,
  ) async {
    final prefs = await _seedPrefs();
    await tester.pumpWidget(_wrap(prefs, const LibraryPage()));
    await tester.pumpAndSettle();

    await tester.longPress(find.text(_favorite.title));
    await tester.pumpAndSettle();

    // A favourite is already stored, so only removal is offered.
    expect(find.text('添加到下一首播放'), findsOneWidget);
    expect(find.text('移出收藏夹'), findsOneWidget);
    expect(find.text('收藏'), findsNothing);
    expect(find.text('取消收藏'), findsNothing);

    await tester.tap(find.text('移出收藏夹'));
    await tester.pumpAndSettle();

    // The confirmation names the track that would be dropped.
    expect(find.text('确定将「${_favorite.title}」移出本地收藏夹吗？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '移出'));
    await tester.pumpAndSettle();

    expect(find.text(_favorite.title), findsNothing);
    expect(LocalFavoritesRepository(prefs).load(), isEmpty);
  });

  testWidgets('the history menu toggles 收藏 and 取消收藏', (tester) async {
    final prefs = await _seedPrefs();
    await tester.pumpWidget(_wrap(prefs, const LibraryPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('播放历史'));
    await tester.pumpAndSettle();

    // The entry is not stored yet, so the menu offers 收藏.
    await tester.longPress(find.text(_played.title));
    await tester.pumpAndSettle();
    expect(find.text('收藏'), findsOneWidget);

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(LocalFavoritesRepository(prefs).load().map((track) => track.id), [
      _played.id,
      _favorite.id,
    ]);

    // Stored now, so the very same entry flips to 取消收藏.
    await tester.longPress(find.text(_played.title));
    await tester.pumpAndSettle();
    expect(find.text('取消收藏'), findsOneWidget);
    expect(find.text('收藏'), findsNothing);

    await tester.tap(find.text('取消收藏'));
    await tester.pumpAndSettle();
    expect(LocalFavoritesRepository(prefs).load().map((track) => track.id), [
      _favorite.id,
    ]);
  });

  testWidgets('queuing a track that is not playing is confirmed', (
    tester,
  ) async {
    final prefs = await _seedPrefs();
    await tester.pumpWidget(
      _wrap(
        prefs,
        const LibraryPage(),
        player: () => _FakePlayer(queued: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('播放历史'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text(_played.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加到下一首播放'));
    await tester.pumpAndSettle();

    expect(find.text('已添加到下一首播放'), findsOneWidget);
  });

  testWidgets('queuing the track that is playing reports it instead', (
    tester,
  ) async {
    final prefs = await _seedPrefs();
    await tester.pumpWidget(
      _wrap(
        prefs,
        const LibraryPage(),
        player: () => _FakePlayer(queued: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('播放历史'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text(_played.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加到下一首播放'));
    await tester.pumpAndSettle();

    // A queue holding only this entry has no next to move it ahead of.
    expect(find.text('该视频正在播放'), findsOneWidget);
  });

  testWidgets('long pressing a local history entry deletes it', (tester) async {
    final prefs = await _seedPrefs();
    await tester.pumpWidget(_wrap(prefs, const LibraryPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('播放历史'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text(_played.title));
    await tester.pumpAndSettle();

    // History adds a delete entry on top of the shared actions.
    expect(find.text('添加到下一首播放'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除记录'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text(_played.title), findsNothing);
    expect(LocalHistoryRepository(prefs).load(), isEmpty);
  });

  testWidgets('signed out, favouriting from the player stores locally', (
    tester,
  ) async {
    final prefs = await _seedPrefs();

    // `_played` is not among the seeded favourites, so the sheet starts unset.
    await tester.pumpWidget(
      _wrap(prefs, const Scaffold(body: FavoriteSheet(track: _played))),
    );
    await tester.pumpAndSettle();

    expect(find.text('本地收藏夹'), findsOneWidget);
    expect(find.text('未收藏'), findsOneWidget);

    await tester.tap(find.text('本地收藏夹'));
    await tester.pumpAndSettle();

    expect(find.text('已在本地收藏夹'), findsOneWidget);
    // Newest first, and the previously seeded favourite is untouched.
    final stored = LocalFavoritesRepository(prefs).load();
    expect(stored.map((track) => track.id), [_played.id, _favorite.id]);
  });
}
