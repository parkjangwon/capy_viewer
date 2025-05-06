import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'dart:async';
import '../../../data/models/manga_title.dart';

import '../../../utils/html_manga_parser.dart';
import 'search_webview_controller.dart';
import '../../widgets/manga/manga_list_item.dart';
import '../../viewmodels/global_cookie_provider.dart';
import '../../viewmodels/cookie_sync_utils.dart';
import '../../../data/providers/site_url_provider.dart';
import '../settings/settings_screen.dart';
import '../manga/manga_navigation.dart';
import '../../viewmodels/recent_added_provider.dart';
import '../home/home_screen.dart';
import '../../../data/models/recent_added_model.dart';

const _publishOptions = [
  '전체', '주간', '격주', '월간', '단편', '단행본', '완결'
];
const _jaumOptions = [
  '전체', 'ㄱ', 'ㄴ', 'ㄷ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅅ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ', 'a-z', '0-9'
];
const _genreOptions = [
  '전체', '17', 'BL', 'SF', 'TS', '개그', '게임', '도박', '드라마', '라노벨', '러브코미디', '먹방', '백합', '붕탁', '순정', '스릴러', '스포츠', '시대', '애니화', '액션', '음악', '이세계', '일상', '전생', '추리', '판타지', '학원', '호러'
];
const _sortOptions = [
  {'label': '기본', 'value': 'wr_datetime'},
  {'label': '인기순', 'value': 'as_view'},
  {'label': '추천순', 'value': 'wr_good'},
  {'label': '댓글순', 'value': 'as_comment'},
  {'label': '북마크순', 'value': 'as_bookmark'},
];

const _searchTypeOptions = [
  {'label': '제목', 'value': 'title'},
  {'label': '작가', 'value': 'artist'},
];

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _searchType = 'title';
  final TextEditingController _searchController = TextEditingController();
  String _sortValue = 'wr_datetime';
  String _publishValue = '전체';
  String _jaumValue = '전체';
  List<String> _selectedGenres = [];
  PagingController<int, MangaTitle>? _pagingController;
  late final SearchWebViewController _webViewHelper = SearchWebViewController();
  bool _webViewInitialized = false;
  String _currentSearch = '';
  String _currentSearchType = 'title';
  String _currentPublish = '';
  String _currentJaum = '';
  String _currentGenre = '';
  String _currentSort = 'wr_datetime';
  int _searchSession = 0;

  void _onSearch() {
    setState(() {
      _currentSearch = _searchController.text.trim();
      _currentSearchType = _searchType;
      _currentPublish = _publishValue == '전체' ? '' : _publishValue;
      _currentJaum = _jaumValue == '전체' ? '' : _jaumValue;
      if (_selectedGenres.isEmpty || _selectedGenres.contains('전체')) {
        _currentGenre = '';
      } else {
        _currentGenre = _selectedGenres.join(',');
      }
      _currentSort = _sortValue;

      _pagingController?.dispose();
      _pagingController = null;
      _webViewInitialized = false;
      _searchSession++;

      if (_currentSearch.isNotEmpty || _currentPublish.isNotEmpty || _currentJaum.isNotEmpty || _currentGenre.isNotEmpty) {
        _pagingController = PagingController<int, MangaTitle>(firstPageKey: 0)
          ..addPageRequestListener(_fetchPage);
      }
    });
  }

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
    _searchController.dispose();
    _pagingController?.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    if (!_webViewInitialized) {
      await _webViewHelper.initialize();
      _webViewInitialized = true;
    }
    if (_currentSearch.isEmpty && _currentPublish.isEmpty && _currentJaum.isEmpty && _currentGenre.isEmpty) {
      _pagingController?.appendLastPage([]);
      return;
    }
    try {
      final baseUrl = ref.read(siteUrlServiceProvider);
      await _webViewHelper.loadSearch(
        baseUrl,
        title: _currentSearchType == 'title' ? _currentSearch : null,
        artist: _currentSearchType == 'artist' ? _currentSearch : null,
        publish: _currentPublish,
        jaum: _currentJaum,
        tag: _currentGenre,
        sort: _currentSort,
      );
      final html = await _webViewHelper.getHtml();
      final captchaKeywords = [
        'captcha-bypass',
        'challenge-form',
        'cloudflare-challenge',
        'turnstile_',
        '_cf_chl_opt',
        'cf-spinner',
      ];
      final isCaptcha = captchaKeywords.any((k) => html.contains(k));
      if (isCaptcha) {
        if (context.mounted) {
          final siteUrl = ref.read(siteUrlServiceProvider);
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CaptchaWebViewPage(
                url: siteUrl,
                onCookiesExtracted: (cookies) {},
              ),
            ),
          );
          if (result != null) {
            await _fetchPage(pageKey);
            return;
          } else {
            _pagingController?.error = Exception('캡차 인증이 필요합니다.');
            return;
          }
        }
      }
      final parsed = parseMangaListFromHtml(html);
      final newItems = parsed.map((item) => MangaTitle(
        id: item.href,
        title: item.title,
        thumbnailUrl: item.thumbnailUrl,
        author: item.author,
        release: '',
        period: item.period,
        updateDate: item.updateDate,
      )).toList();
      _pagingController?.appendLastPage(newItems);
    } catch (e) {
      _pagingController?.error = e;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _FilterDropdown(
                  label: '발행',
                  value: _publishValue,
                  items: _publishOptions,
                  onChanged: (v) => setState(() => _publishValue = v!),
                ),
                _FilterDropdown(
                  label: '초성',
                  value: _jaumValue,
                  items: _jaumOptions,
                  onChanged: (v) => setState(() => _jaumValue = v!),
                ),
                _FilterDropdown(
                  label: '정렬',
                  value: _sortValue,
                  optionMapList: _sortOptions,
                  onChanged: (v) => setState(() => _sortValue = v!),
                  minWidth: 110,
                ),
                OutlinedButton(
                  onPressed: () async {
                    final result = await showModalBottomSheet<List<String>>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => GenreSelectSheet(
                        allGenres: _genreOptions,
                        selected: _selectedGenres,
                      ),
                    );
                    if (result != null) setState(() => _selectedGenres = result);
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Theme.of(context).colorScheme.outline),
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
                    minimumSize: const Size(120, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    alignment: Alignment.center,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.standard,
                  ),
                  child: SizedBox(
                    height: 24,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.category_outlined, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          _selectedGenres.isEmpty || _selectedGenres.contains('전체')
                            ? '장르 전체'
                            : '장르: ' + _selectedGenres.join(', '),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _searchType,
                  items: _searchTypeOptions.map((e) => DropdownMenuItem(value: e['value']!, child: Text(e['label']!))).toList(),
                  onChanged: (v) => setState(() => _searchType = v!),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: '검색어 입력',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _onSearch,
                  child: const Text('검색'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _pagingController == null
                ? Center(child: Text('검색 조건을 입력하세요', style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.4))))
                : RefreshIndicator(
                    onRefresh: () async {
                      _pagingController!.refresh();
                    },
                    child: PagedListView<int, MangaTitle>(
                      key: ValueKey(_searchSession),
                      pagingController: _pagingController!,
                      builderDelegate: PagedChildBuilderDelegate<MangaTitle>(
                        itemBuilder: (context, item, index) => MangaListItem(
                          manga: item,
                          onTap: () => _onMangaSelected(context, item),
                        ),
                        firstPageProgressIndicatorBuilder: (context) => const Center(child: CircularProgressIndicator()),
                        newPageProgressIndicatorBuilder: (context) => const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator())),
                        noItemsFoundIndicatorBuilder: (context) => Center(child: Text('검색 결과가 없습니다', style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.4)))),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _onMangaSelected(BuildContext context, MangaTitle manga) {
    // 검색 결과 아이템 클릭 시 만화 상세 보기 페이지로 이동
    MangaNavigation.navigateToMangaDetail(
      context,
      manga.id,  // id 필드에 URL 경로가 저장되어 있음
      title: manga.title,
      isChapterUrl: true,  // URL 경로를 전달하므로 true로 설정
    );
  }
}

// 홈 주요 섹션 위젯 (최근 추가, 최근 본, 주간 베스트 등)
class _HomeSections extends StatelessWidget {
  final WidgetRef ref;
  const _HomeSections({required this.ref});
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // 최근 추가된 작품
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('최근 추가된 작품', style: Theme.of(context).textTheme.titleMedium),
              // ... 더보기 버튼 등 필요시 추가 ...
            ],
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final asyncValue = ref.watch(recentAddedPreviewProvider);
            return asyncValue.when(
              data: (items) => _HorizontalCardList(items: items),
              loading: () => _HorizontalCardList(placeholderCount: 6),
              error: (e, st) => Center(child: Text('불러오기 실패')),
            );
          },
        ),
        // 최근 본 작품, 주간 베스트 등도 동일하게 추가 가능
        // ...
      ],
    );
  }
}

// 최근 추가된 작품 가로 리스트 위젯 (복사)
class _HorizontalCardList extends StatelessWidget {
  final int placeholderCount;
  final String? emptyText;
  final List<RecentAddedItem>? items;
  const _HorizontalCardList({this.placeholderCount = 0, this.emptyText, this.items});
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
                      child: Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[300],
                        child: item.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                item.thumbnailUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image, size: 32, color: Colors.grey),
                                ),
                              )
                            : const Icon(Icons.photo, size: 32, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
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

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<Map<String, String>>? optionMapList; // 정렬 옵션용
  final List<String>? items; // 일반 옵션용
  final void Function(String?) onChanged;
  final double minWidth;
  const _FilterDropdown({
    required this.label,
    required this.value,
    this.optionMapList,
    this.items,
    required this.onChanged,
    this.minWidth = 90,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
        ),
        onPressed: null,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            icon: const Icon(Icons.arrow_drop_down),
            onChanged: onChanged,
            borderRadius: BorderRadius.circular(12),
            style: Theme.of(context).textTheme.bodyMedium,
            dropdownColor: Theme.of(context).colorScheme.surface,
            items: optionMapList != null
                ? optionMapList!.map((e) => DropdownMenuItem(
                      value: e['value'],
                      child: Row(
                        children: [
                          Text('$label: ', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                          Text(e['label']!),
                        ],
                      ),
                    )).toList()
                : items!.map((e) => DropdownMenuItem(
                      value: e,
                      child: Row(
                        children: [
                          Text('$label: ', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                          Text(e),
                        ],
                      ),
                    )).toList(),
          ),
        ),
      ),
    );
  }
}

class GenreSelectSheet extends StatefulWidget {
  final List<String> allGenres;
  final List<String> selected;
  const GenreSelectSheet({required this.allGenres, required this.selected, super.key});
  @override
  State<GenreSelectSheet> createState() => _GenreSelectSheetState();
}

class _GenreSelectSheetState extends State<GenreSelectSheet> {
  late List<String> _tempSelected;
  @override
  void initState() {
    super.initState();
    _tempSelected = List<String>.from(widget.selected);
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('장르 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => Navigator.pop(context, _tempSelected),
                  child: const Text('확인'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: widget.allGenres.map((genre) {
                  final selected = _tempSelected.contains(genre) || (_tempSelected.isEmpty && genre == '전체');
                  return CheckboxListTile(
                    value: selected,
                    title: Text(genre),
                    onChanged: (v) {
                      setState(() {
                        if (genre == '전체') {
                          _tempSelected.clear();
                        } else {
                          if (selected) {
                            _tempSelected.remove(genre);
                          } else {
                            _tempSelected.add(genre);
                            _tempSelected.remove('전체');
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
