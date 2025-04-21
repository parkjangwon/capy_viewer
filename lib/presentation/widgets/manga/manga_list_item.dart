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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: manga.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        manga.thumbnailUrl,
                        width: 80,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 80,
                          height: 110,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 110,
                        color: Colors.grey[300],
                        child: const Icon(Icons.photo, size: 40, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (manga.author.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              manga.author,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (manga.release.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          manga.release,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.deepPurple),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // 연재 주기(period)
                    if (manga.period != null && manga.period!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              manga.period!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange[800]),
                            ),
                          ],
                        ),
                      ),
                    // 업데이트 날짜
                    if (manga.updateDate != null && manga.updateDate!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.update, size: 14, color: Colors.teal),
                            const SizedBox(width: 4),
                            Text(
                              manga.updateDate!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.teal[800]),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 