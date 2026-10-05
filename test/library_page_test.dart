import 'package:bilihear/core/models/media_track.dart';
import 'package:bilihear/data/repositories/local_favorites_repository.dart';
import 'package:bilihear/data/repositories/local_history_repository.dart';
import 'package:bilihear/features/library/library_page.dart';
import 'package:bilihear/state/auth_controller.dart';
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

Widget _wrap(SharedPreferences prefs, Widget home) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authControllerProvider.overrideWith(_SignedOutAuth.new),
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
    // Removal is by long press, so no per-row delete button is shown.
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

  testWidgets('long pressing a local favourite removes it after confirming', (
    tester,
  ) async {
    final prefs = await _seedPrefs();
    await tester.pumpWidget(_wrap(prefs, const LibraryPage()));
    await tester.pumpAndSettle();

    await tester.longPress(find.text(_favorite.title));
    await tester.pumpAndSettle();

    // The confirmation names the track that would be dropped.
    expect(find.text('取消收藏'), findsWidgets);
    expect(find.text('确定将「${_favorite.title}」移出本地收藏夹吗？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '移出'));
    await tester.pumpAndSettle();

    expect(find.text(_favorite.title), findsNothing);
    expect(LocalFavoritesRepository(prefs).load(), isEmpty);
  });

  testWidgets('long pressing a local history entry deletes it', (tester) async {
    final prefs = await _seedPrefs();
    await tester.pumpWidget(_wrap(prefs, const LibraryPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('播放历史'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text(_played.title));
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
