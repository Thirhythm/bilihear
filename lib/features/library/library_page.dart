import 'package:bilihear/features/library/favorites_tab.dart';
import 'package:bilihear/features/library/history_view.dart';
import 'package:flutter/material.dart';

/// Library tab of the app shell: the favourites and the play history, each
/// switching between the Bilibili account and the on-device store.
///
/// The shell already docks a mini player below this page, so the tab body
/// renders none of its own.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('媒体库'),
        bottom: const TabBar(
          tabs: [
            Tab(text: '收藏夹'),
            Tab(text: '播放历史'),
          ],
        ),
      ),
      body: const TabBarView(children: [FavoritesTab(), HistoryView()]),
    ),
  );
}
