import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/database_helper.dart';
import '../viewer/manga_viewer_screen.dart';
import '../../../utils/network_image_with_headers.dart';
import '../../providers/recent_chapters_provider.dart';

class RecentChaptersScreen extends ConsumerWidget {
  const RecentChaptersScreen({super.key});

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '최근에 본 작품이 없습니다.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chaptersAsync = ref.watch(recentChaptersProvider);
    final previewNotifier = ref.read(recentChaptersPreviewProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('최근에 본 작품'),
      ),
      body: SafeArea(
        child: chaptersAsync.when(
          data: (chapters) => chapters.isEmpty
              ? _buildEmptyState(theme)
              : RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      ref.read(recentChaptersProvider.notifier).refresh(),
                      ref
                          .read(recentChaptersPreviewProvider.notifier)
                          .refresh(),
                    ]);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MangaViewerScreen(
                                  chapterId: chapter['id'],
                                  title: chapter['manga_id'],
                                  initialPage: chapter['last_page'],
                                ),
                              ),
                            ).then((_) async {
                              await Future.wait([
                                ref
                                    .read(recentChaptersProvider.notifier)
                                    .refresh(),
                                ref
                                    .read(
                                        recentChaptersPreviewProvider.notifier)
                                    .refresh(),
                              ]);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 썸네일
                                if (chapter['thumbnail_url']?.isNotEmpty ??
                                    false)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: NetworkImageWithHeaders(
                                      url: chapter['thumbnail_url'],
                                      width: 80,
                                      height: 110,
                                      fit: BoxFit.cover,
                                      errorWidget: Container(
                                        width: 80,
                                        height: 110,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image,
                                            size: 40, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        chapter['chapter_title'],
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        chapter['manga_id'],
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: theme
                                              .textTheme.bodyMedium?.color
                                              ?.withOpacity(0.7),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.5),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDate(chapter['last_read']),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.5),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(
                                            Icons.bookmark,
                                            size: 16,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.5),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${chapter['last_page']} 페이지',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // 삭제 버튼
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    await DatabaseHelper.instance
                                        .deleteRecentChapter(chapter['id']);
                                    ref
                                        .read(recentChaptersProvider.notifier)
                                        .refresh();
                                    previewNotifier.refresh();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text('오류가 발생했습니다: $error'),
          ),
        ),
      ),
    );
  }
}
