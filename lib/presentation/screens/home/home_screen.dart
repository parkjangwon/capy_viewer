import 'package:flutter/material.dart';
import 'recent_added_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/recent_added_model.dart';
import '../../../data/models/weekly_best_model.dart';
import '../../viewmodels/recent_added_provider.dart';
import '../../viewmodels/weekly_best_provider.dart';
import '../../viewmodels/global_cookie_provider.dart';
import '../../viewmodels/cookie_sync_utils.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../../utils/network_image_with_headers.dart';
import 'package:cookie_jar/cookie_jar.dart';
import '../manga/manga_navigation.dart';

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
                    const _HorizontalCardList(
                        placeholderCount: 6, emptyText: '결과 없음'),
                    const SizedBox(height: 16),
                    const _SectionTitle('주간 베스트'),
                    const _WeeklyBestList(),
                    const SizedBox(height: 16),
                    const _SectionTitle('이름'),
                    _NameSelector(),
                    const SizedBox(height: 16),
                    const _SectionTitle('장르'),
                    _GenreSelector(),
                    const SizedBox(height: 16),
                    const _SectionTitle('발행'),
                    _PublishSelector(),
                    const SizedBox(height: 24),
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
            return InkWell(
              onTap: () {
                // 홈 화면의 최근 추가된 작품 클릭 시 만화 읽기 알림 표시
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('알림'),
                    content: const Text('만화 읽기'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('확인'),
                      ),
                    ],
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
                      child: Consumer(builder: (context, ref, _) {
                        return FutureBuilder<String?>(
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
                        );
                      }),
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
        ),
      );
    }
    if (placeholderCount == 0 && emptyText != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(emptyText!, style: const TextStyle(color: Colors.grey)),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: placeholderCount,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) => Container(
          width: 80,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
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
                // 만화 읽기 알림창 표시
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('만화 읽기'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('제목: ${item.title}'),
                        const SizedBox(height: 8),
                        Text('URL: ${item.url}'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('확인'),
                      ),
                    ],
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
          child: Text('주간 베스트 로딩 오류: ${error.toString().substring(0, error.toString().length > 50 ? 50 : error.toString().length)}...'),
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

class _NameSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final names = [
      'ㄱ',
      'ㄴ',
      'ㄷ',
      'ㄹ',
      'ㅁ',
      'ㅂ',
      'ㅅ',
      'ㅇ',
      'ㅈ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ',
      '0-9',
      'A-Z'
    ];
    return Wrap(
      children: names.map((n) => _ChipButton(label: n)).toList(),
    );
  }
}

class _GenreSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final genres = [
      '17',
      'BL',
      'SF',
      'TS',
      '개그',
      '게임',
      '도박',
      '드라마',
      '라노벨',
      '러브코미디',
      '먹방',
      '백합',
      '붕탁',
      '순정',
      '스릴러',
      '스포츠',
      '시대',
      '애니화',
      '액션',
      '음악',
      '이세계',
      '일상',
      '전생',
      '추리',
      '판타지',
      '학원',
      '호러'
    ];
    return Wrap(
      children: genres.map((g) => _ChipButton(label: g)).toList(),
    );
  }
}

class _PublishSelector extends StatelessWidget {
  static const publish = ['미분류', '주간', '격주', '월간', '단편', '단행본', '완결'];
  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: publish.map((p) => _ChipButton(label: p)).toList(),
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
