import 'package:flutter/material.dart';
import '../../../data/models/manga_title.dart';

class MangaListItem extends StatelessWidget {
  final MangaTitle manga;
  final VoidCallback? onTap;

  const MangaListItem({
    super.key,
    required this.manga,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: manga.thumbnailUrl.isNotEmpty
          ? Image.network(
              manga.thumbnailUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.error),
            )
          : const Icon(Icons.book),
      title: Text(manga.title),
      subtitle: Text('${manga.author} • ${manga.release}'),
      onTap: onTap,
    );
  }
} 