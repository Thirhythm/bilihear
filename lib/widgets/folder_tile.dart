import 'package:bilihear/core/models/fav_folder.dart';
import 'package:bilihear/features/library/folder_detail_page.dart';
import 'package:flutter/material.dart';

/// Row describing a favourite folder; tapping opens its contents.
class FolderTile extends StatelessWidget {
  const FolderTile({super.key, required this.folder});

  final FavFolder folder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(
          Icons.folder_rounded,
          color: scheme.onSecondaryContainer,
        ),
      ),
      title: Text(folder.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${folder.mediaCount} 个内容'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FolderDetailPage(folder: folder),
        ),
      ),
    );
  }
}
