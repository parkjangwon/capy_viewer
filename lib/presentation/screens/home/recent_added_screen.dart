import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'dart:async';
import '../../viewmodels/recent_added_provider.dart';
import '../../../data/models/recent_added_model.dart';
import '../../viewmodels/global_cookie_provider.dart';
import '../../viewmodels/cookie_sync_utils.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../../utils/content_filter.dart';
import '../../../utils/network_image_with_headers.dart';
import '../manga/manga_navigation.dart';
import '../viewer/manga_viewer_screen.dart';
import '../../providers/tab_provider.dart';

class RecentAddedScreen extends ConsumerStatefulWidget {
  const RecentAddedScreen({super.key});
  @override
  ConsumerState<RecentAddedScreen> createState() => _RecentAddedScreenState();
}

class _RecentAddedScreenState extends ConsumerState<RecentAddedScreen> {
  static const _pageSize = 20;
  final PagingController<int, RecentAddedItem> _pagingController =
      PagingController(firstPageKey: 1);
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // WebView 쿠키 → Dio 쿠키 동기화 (최초 진입 시)
    Future.microtask(() async {
      final jar = ref.read(globalCookieJarProvider);
      final url = ref.read(siteUrlServiceProvider);
      await syncWebViewCookiesToDio(url, jar);
    });
    _pagingController.addPageRequestListener(_fetchPage);
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final items = await ref.read(recentAddedPagingProvider(pageKey).future);
      final isSafeMode = await ContentFilter.isSafeModeEnabled();

      List<RecentAddedItem> filteredItems = items;
      if (isSafeMode) {
        filteredItems = await Future.wait(
          items.map((item) async {
            final tags = item.genres.join(' ');
            final isAllowed =
                await ContentFilter.isContentAllowed(item.title, tags);
            return isAllowed ? item : null;
          }),
        ).then((results) => results
            .where((item) => item != null)
            .cast<RecentAddedItem>()
            .toList());
      }

      final isLastPage = pageKey == 10;
      final nextPageKey = isLastPage ? null : pageKey + 1;
      if (isLastPage) {
        _pagingController.appendLastPage(filteredItems);
      } else {
        _pagingController.appendPage(filteredItems, nextPageKey);
      }
    } catch (e) {
      _pagingController.error = e;
    }
  }

  Future<void> _refresh() async {
    // Provider를 무효화하여 새로운 데이터를 가져오도록 함
    ref.invalidate(recentAddedPagingProvider(1));
    _pagingController.refresh();
  }

  @override
  void dispose() {
    _pagingController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      // 먼저 탭 상태를 변경
      ref.read(selectedTabProvider.notifier).state = index;
      // 그 다음 네비게이션 수행
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            PagedSliverList<int, RecentAddedItem>(
              pagingController: _pagingController,
              builderDelegate: PagedChildBuilderDelegate<RecentAddedItem>(
                itemBuilder: (context, item, idx) =>
                    _RecentAddedListItem(item: item),
                noItemsFoundIndicatorBuilder: (context) =>
                    const Center(child: Text('작품 없음')),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: '검색',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '최근',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: '좋아요',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: '저장',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

Future<String?> getCookieString(CookieJar jar, String url) async {
  try {
    final cookies = await jar.loadForRequest(Uri.parse(url));
    if (cookies.isEmpty) return null;
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  } catch (_) {
    return null;
  }
}

class _RecentAddedListItem extends ConsumerWidget {
  final RecentAddedItem item;
  const _RecentAddedListItem({required this.item});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          final baseUrl = ref.read(siteUrlServiceProvider);
          final viewerUrl =
              item.url.startsWith('http') ? item.url : '$baseUrl${item.url}';
          debugPrint('[최근추가] 뷰어로 이동: url=$viewerUrl');
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
                      width: 80,
                      height: 110,
                      cookie: snapshot.data,
                      errorWidget: Container(
                        width: 80,
                        height: 110,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image,
                            size: 40, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              // 텍스트 영역을 Expanded로 감싸 overflow 방지
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // 날짜/댓글/좋아요/조회수 한 줄, 넘칠 경우 줄바꿈
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          item.date,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.deepPurple),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.comment,
                                size: 16, color: Colors.blueGrey),
                            const SizedBox(width: 2),
                            Text('${item.comments ?? 0}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.thumb_up_alt_outlined,
                                size: 16, color: Colors.pink),
                            const SizedBox(width: 2),
                            Text('${item.likes ?? 0}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.remove_red_eye,
                                size: 16, color: Colors.teal),
                            const SizedBox(width: 2),
                            Text('${item.views ?? 0}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.author,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 4,
                        children: item.genres
                            .map((g) => Chip(
                                  label: Text(g),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 버튼 영역 고정 폭으로 overflow 방지
              SizedBox(
                width: 55,
                height: 110,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                  ),
                  onPressed: () {
                    // 상세보기 버튼 클릭 시 전편보기 링크로 직접 이동
                    // 전체 URL을 전달하여 해당 페이지의 HTML에서 전편보기 링크 추출
                    if (item.url.isNotEmpty) {
                      print(
                          '상세보기 진입: item.fullViewUrl=${item.fullViewUrl}, item.title=${item.title}');
                      MangaNavigation.navigateToMangaDetail(
                        context,
                        item.fullViewUrl,
                        title: item.title,
                        isChapterUrl: true,
                        parseFullPage: true, // 전체 페이지를 파싱하여 전편보기 링크 추출
                      );
                    } else {
                      Fluttertoast.showToast(
                        msg: '잘못된 URL 형식입니다',
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                      );
                    }
                  },
                  child: const Text('상세보기', textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
