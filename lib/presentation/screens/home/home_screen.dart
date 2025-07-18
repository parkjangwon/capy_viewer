import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cookie_jar/cookie_jar.dart';

import '../../../data/models/recent_added_model.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../../utils/network_image_with_headers.dart';
import '../../viewmodels/recent_added_provider.dart';
import '../../viewmodels/weekly_best_provider.dart';
import '../../viewmodels/global_cookie_provider.dart';
import '../../viewmodels/cookie_sync_utils.dart';
import '../../providers/recent_chapters_provider.dart';
import '../viewer/manga_viewer_screen.dart';
import 'recent_added_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onRecentTap;
  const HomeScreen({super.key, this.onRecentTap});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

// getCookieString 함수 추가
Future<String?> getCookieString(CookieJar jar, String url) async {
  try {
    final cookies = await jar.loadForRequest(Uri.parse(url));
    if (cookies.isEmpty) return null;
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  } catch (_) {
    return null;
  }
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // WebView 쿠키 → Dio 쿠키 동기화 (최초 진입 시)
    Future.microtask(() async {
      final jar = ref.read(globalCookieJarProvider);
      final url = ref.read(siteUrlServiceProvider);
      await syncWebViewCookiesToDio(url, jar);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recentAddedPreviewProvider);
            ref.read(recentChaptersPreviewProvider.notifier).refresh();
            setState(() {});
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _SectionTitleWithAction(
                      title: '최근 추가된 작품',
                      onAction: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RecentAddedScreen(),
                          ),
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final asyncValue =
                            ref.watch(recentAddedPreviewProvider);
                        return asyncValue.when(
                          data: (items) => _HorizontalCardList(
                            items: items,
                            placeholderCount: 6,
                          ),
                          loading: () =>
                              const _HorizontalCardList(placeholderCount: 6),
                          error: (e, st) =>
                              const Center(child: Text('불러오기 실패')),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _SectionTitleWithAction(
                      title: '최근에 본 작품',
                      onAction: widget.onRecentTap,
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final asyncValue =
                            ref.watch(recentChaptersPreviewProvider);
                        return asyncValue.when(
                          data: (chapters) {
                            if (chapters.isEmpty) {
                              return const _HorizontalCardList(
                                placeholderCount: 0,
                                emptyText: '최근에 본 작품이 없습니다.',
                              );
                            }
                            return SizedBox(
                              height: 180,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: chapters.length,
                                itemBuilder: (context, index) {
                                  final chapter = chapters[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: InkWell(
                                      onTap: () {
                                        print('[홈] 최근 본 작품 클릭');
                                        print(
                                            '[홈] 작품 정보: ${chapter.toString()}');
                                        print(
                                            '[홈] 마지막 페이지: ${chapter['last_page']}');
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                MangaViewerScreen(
                                              title: chapter['manga_id'],
                                              chapterId: chapter['id'],
                                              initialPage:
                                                  chapter['last_page'] ?? 0,
                                              thumbnailUrl:
                                                  chapter['thumbnail_url'],
                                            ),
                                          ),
                                        );
                                      },
                                      child: SizedBox(
                                        width: 120,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: chapter['thumbnail_url']
                                                          ?.isNotEmpty ??
                                                      false
                                                  ? NetworkImageWithHeaders(
                                                      url: chapter[
                                                          'thumbnail_url'],
                                                      width: 120,
                                                      height: 120,
                                                      fit: BoxFit.cover,
                                                      errorWidget: Container(
                                                        width: 120,
                                                        height: 120,
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Colors.grey[300],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: const Icon(
                                                            Icons.menu_book,
                                                            size: 32),
                                                      ),
                                                    )
                                                  : Container(
                                                      width: 120,
                                                      height: 120,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[300],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: const Icon(
                                                          Icons.menu_book,
                                                          size: 32),
                                                    ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              chapter['manga_id'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              chapter['chapter_title'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color,
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
                          },
                          loading: () =>
                              const _HorizontalCardList(placeholderCount: 6),
                          error: (e, st) =>
                              const Center(child: Text('불러오기 실패')),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const _SectionTitle('주간 베스트'),
                    const _WeeklyBestList(),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      // bottomNavigationBar 제거 (실제 네비게이션은 부모에서 관리)
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SectionTitleWithAction extends StatelessWidget {
  final String title;
  final VoidCallback? onAction;
  const _SectionTitleWithAction({required this.title, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (onAction != null)
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              onPressed: onAction,
              tooltip: '더 보기',
              padding: const EdgeInsets.only(left: 4),
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class _HorizontalCardList extends StatelessWidget {
  final int placeholderCount;
  final String? emptyText;
  final List<RecentAddedItem>? items;
  const _HorizontalCardList(
      {this.placeholderCount = 0, this.emptyText, this.items});
  @override
  Widget build(BuildContext context) {
    if (items != null && items!.isNotEmpty) {
      return SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items!.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, idx) {
            final item = items![idx];
            return Consumer(
              builder: (context, ref, child) {
                return InkWell(
                  onTap: () {
                    final baseUrl = ref.read(siteUrlServiceProvider);
                    final viewerUrl = item.url.startsWith('http')
                        ? item.url
                        : '$baseUrl${item.url}';
                    debugPrint('[썸네일] 뷰어로 이동: url=$viewerUrl');
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MangaViewerScreen(
                          chapterId: viewerUrl,
                          title: item.title,
                          thumbnailUrl: item.thumbnailUrl,
                        ),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<String?>(
                            future: getCookieString(
                                ref.read(globalCookieJarProvider), item.url),
                            builder: (context, snapshot) {
                              return NetworkImageWithHeaders(
                                url: item.thumbnailUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                cookie: snapshot.data,
                                errorWidget: Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image,
                                      size: 32, color: Colors.grey),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.title,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    }
    if (placeholderCount == 0 && emptyText != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(emptyText!)),
      );
    }
    return const SizedBox.shrink();
  }
}

class _WeeklyBestList extends ConsumerWidget {
  const _WeeklyBestList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyBestAsync = ref.watch(weeklyBestProvider);

    return weeklyBestAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('주간 베스트 목록이 없습니다')),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, idx) {
            final item = items[idx];
            return ListTile(
              leading: Text(
                '${idx + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(item.title),
              dense: true,
              onTap: () {
                final chapterId = item.url.split('/').last;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MangaViewerScreen(
                      chapterId: chapterId,
                      title: item.title,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 10,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, idx) => ListTile(
          title: Container(
            height: 16,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          subtitle: Container(
            height: 12,
            width: 100,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          dense: true,
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
              '주간 베스트 로딩 오류: ${error.toString().substring(0, error.toString().length > 50 ? 50 : error.toString().length)}...'),
        ),
      ),
    );
  }
}

class _VerticalList extends StatelessWidget {
  final int placeholderCount;
  const _VerticalList({required this.placeholderCount});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: placeholderCount,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, idx) => ListTile(
        title: Text('작품 ${idx + 1}'),
        subtitle: const Text('설명 또는 회차'),
        dense: true,
        onTap: () {},
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _ChipButton({required this.label, this.selected = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[850] : Colors.grey[200],
        shape: const StadiumBorder(),
        side: BorderSide(
            color: isDark ? Colors.deepPurple[300]! : Colors.deepPurple[200]!),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
    );
  }
}
