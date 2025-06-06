import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/database_helper.dart';
import '../manga/manga_detail_screen.dart';
import '../../../utils/network_image_with_headers.dart';

class LikedMangaScreen extends ConsumerStatefulWidget {
  const LikedMangaScreen({super.key});

  @override
  ConsumerState<LikedMangaScreen> createState() => _LikedMangaScreenState();
}

class _LikedMangaScreenState extends ConsumerState<LikedMangaScreen> {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _likedManga = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLikedManga();
  }

  Future<void> _loadLikedManga() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final likedManga = await _db.getLikedManga();
      if (mounted) {
        setState(() {
          _likedManga = likedManga;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('좋아요 목록을 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '좋아요한 작품이 없습니다.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '작품 상세 화면에서 하트를 눌러보세요!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMangaGrid(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadLikedManga,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: _likedManga.length,
        itemBuilder: (context, index) {
          final manga = _likedManga[index];
          final genres = (manga['genres'] as String?)?.split('|') ?? [];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MangaDetailScreen(
                      mangaId: manga['id'],
                      title: manga['title'],
                    ),
                  ),
                ).then((_) => _loadLikedManga());
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 썸네일
                    if (manga['thumbnail_url']?.isNotEmpty ?? false)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: NetworkImageWithHeaders(
                          url: manga['thumbnail_url'],
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            manga['title'],
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  manga['author'] ?? '작가 미상',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (genres.isNotEmpty)
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: genres
                                  .map((genre) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme.primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          genre,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                    // Like Button
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: IconButton(
                        icon: const Icon(Icons.favorite),
                        color: Colors.red,
                        onPressed: () async {
                          await _db.removeLike(manga['id']);
                          _loadLikedManga();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('좋아요한 작품'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _likedManga.isEmpty
                ? _buildEmptyState(theme)
                : _buildMangaGrid(theme),
      ),
    );
  }
}
