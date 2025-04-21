import 'package:flutter/material.dart';
import '../../widgets/manga/manga_list_item.dart';

class RecentAddedScreen extends StatelessWidget {
  const RecentAddedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('최근 추가된 작품'),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        itemCount: 20,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          // 더미 데이터 생성
          final dummyManga = DummyMangaTitle(
            title: '작품 제목 ${idx + 1}',
            author: '작가명',
            release: '2024-04-21',
            genres: ['액션', '판타지', if (idx % 2 == 0) '로맨스'],
            thumbnailUrl: '',
          );
          return DummyMangaListItem(manga: dummyManga);
        },
      ),
    );
  }
}

// 더미용 모델 및 위젯
class DummyMangaTitle {
  final String title;
  final String author;
  final String release;
  final List<String> genres;
  final String thumbnailUrl;
  DummyMangaTitle({
    required this.title,
    required this.author,
    required this.release,
    required this.genres,
    required this.thumbnailUrl,
  });
}

class DummyMangaListItem extends StatelessWidget {
  final DummyMangaTitle manga;
  const DummyMangaListItem({super.key, required this.manga});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
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
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      manga.release,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.deepPurple),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 4,
                      children: manga.genres.map((g) => Chip(
                        label: Text(g),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
