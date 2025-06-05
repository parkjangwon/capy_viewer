import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../data/models/manga_title.dart';

import '../../../utils/html_manga_parser.dart';
import 'search_webview_controller.dart';
import '../../widgets/manga/manga_list_item.dart';
import '../../viewmodels/global_cookie_provider.dart';
import '../../viewmodels/cookie_sync_utils.dart';
import '../../../data/providers/site_url_provider.dart';
import '../settings/settings_screen.dart';
import '../manga/manga_navigation.dart';

const _publishOptions = ['전체', '주간', '격주', '월간', '단편', '단행본', '완결'];
const _jaumOptions = [
  '전체',
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
  'a-z',
  '0-9'
];
const _genreOptions = [
  '전체',
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
const _sortOptions = [
  {'label': '기본', 'value': 'wr_datetime'},
  {'label': '인기순', 'value': 'as_view'},
  {'label': '추천순', 'value': 'wr_good'},
  {'label': '댓글순', 'value': 'as_comment'},
  {'label': '북마크순', 'value': 'as_bookmark'},
];

const _searchTypeOptions = [
  {'label': '제목', 'value': 'title'},
];

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  String _searchType = 'title';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
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
  late final AnimationController _filterAnimationController;
  bool _isFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    _filterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // WebView 쿠키 → Dio 쿠키 동기화 (최초 진입 시)
    Future.microtask(() async {
      final jar = ref.read(globalCookieJarProvider);
      final url = ref.read(siteUrlServiceProvider);
      await syncWebViewCookiesToDio(url, jar);
    });
  }

  @override
  void dispose() {
    _filterAnimationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pagingController?.dispose();
    super.dispose();
  }

  void _onSearch() {
    print('[DEBUG] 검색 시작');

    // 현재 검색 상태 업데이트
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

    print('[DEBUG] 검색 파라미터:');
    print('- 검색어: $_currentSearch');
    print('- 검색 타입: $_currentSearchType');
    print('- 발행 상태: $_currentPublish');
    print('- 초성: $_currentJaum');
    print('- 장르: $_currentGenre');
    print('- 정렬: $_currentSort');

    // WebView 상태 초기화
    _webViewInitialized = false;
    _searchSession++;

    // 기존 페이징 컨트롤러 정리
    _pagingController?.dispose();

    // 새로운 페이징 컨트롤러 생성 및 초기화
    if (_currentSearch.isNotEmpty ||
        _currentPublish.isNotEmpty ||
        _currentJaum.isNotEmpty ||
        _currentGenre.isNotEmpty) {
      _pagingController = PagingController<int, MangaTitle>(firstPageKey: 0);
      _pagingController!.addPageRequestListener((pageKey) {
        if (mounted) {
          _fetchPage(pageKey);
        }
      });
    } else {
      _pagingController = null;
    }

    // UI 업데이트
    setState(() {});
  }

  Future<void> _fetchPage(int pageKey) async {
    print('[DEBUG] 페이지 로드 시작: pageKey=$pageKey');

    if (!mounted) {
      print('[DEBUG] 위젯이 dispose된 상태');
      return;
    }

    try {
      if (!_webViewInitialized) {
        print('[DEBUG] WebView 초기화 시작');
        await _webViewHelper.initialize();

        // WebView 쿠키 → Dio 쿠키 동기화
        final baseUrl = ref.read(siteUrlServiceProvider);
        final jar = ref.read(globalCookieJarProvider);
        await syncWebViewCookiesToDio(baseUrl, jar);

        _webViewInitialized = true;
        print('[DEBUG] WebView 초기화 완료');
      }

      if (!mounted) return;

      final baseUrl = ref.read(siteUrlServiceProvider);
      print('[DEBUG] 검색 요청 전송');

      await _webViewHelper.loadSearch(
        baseUrl,
        title: _currentSearch,
        publish: _currentPublish,
        jaum: _currentJaum,
        tag: _currentGenre,
        sort: _currentSort,
      );

      if (!mounted) return;

      print('[DEBUG] HTML 콘텐츠 가져오기');
      final html = await _webViewHelper.getHtml();
      print('[DEBUG] HTML 길이: ${html.length}');

      // 캡차 감지 키워드 확장
      final captchaKeywords = [
        'captcha-bypass',
        'challenge-form',
        'cloudflare-challenge',
        'turnstile_',
        '_cf_chl_opt',
        'cf-spinner',
        'cf-browser-verification',
        'cf_captcha_kind',
        '캡차 인증',
        'kcaptcha',
        'captcha.php',
      ];

      if (captchaKeywords.any((k) => html.contains(k)) || html.length < 1000) {
        print('[DEBUG] 캡차 감지됨 또는 비정상적인 응답');
        if (!mounted) return;

        final siteUrl = ref.read(siteUrlServiceProvider);
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CaptchaWebViewPage(
              url: siteUrl,
              onCookiesExtracted: (dynamic cookies) async {
                // 캡차 인증 후 쿠키 동기화
                final jar = ref.read(globalCookieJarProvider);
                if (cookies is List<WebViewCookie>) {
                  await jar.saveFromResponse(
                    Uri.parse(siteUrl),
                    cookies.map((c) => Cookie(c.name, c.value)).toList(),
                  );
                }
              },
            ),
          ),
        );

        if (result != null) {
          print('[DEBUG] 캡차 인증 성공, 검색 재시도');
          // 캡차 인증 성공 후 WebView 재초기화
          _webViewInitialized = false;
          if (mounted) {
            await _fetchPage(pageKey);
          }
          return;
        } else {
          print('[DEBUG] 캡차 인증 실패');
          if (mounted) {
            _pagingController?.error = Exception('캡차 인증이 필요합니다.');
          }
          return;
        }
      }

      print('[DEBUG] 검색 결과 파싱 시작');
      final parsed = parseMangaListFromHtml(html);
      print('[DEBUG] 파싱된 결과 수: ${parsed.length}');

      if (parsed.isEmpty && html.length > 1000) {
        print('[DEBUG] 결과가 없지만 HTML이 존재함. HTML 내용 확인:');
        print(html.substring(0, 500)); // 처음 500자만 출력
      }

      final newItems = parsed
          .map((item) => MangaTitle(
                id: item.href,
                title: item.title,
                thumbnailUrl: item.thumbnailUrl,
                author: item.author,
                release: '',
                period: item.period,
                updateDate: item.updateDate,
              ))
          .toList();
      print('[DEBUG] 변환된 아이템 수: ${newItems.length}');

      if (mounted) {
        _pagingController?.appendLastPage(newItems);
      }
    } catch (e, stack) {
      print('[ERROR] 검색 중 오류 발생: $e');
      print(stack);
      if (mounted) {
        _pagingController?.error = e;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 검색 결과
            if (_pagingController != null)
              Positioned.fill(
                bottom: 80, // 검색바 높이만큼 패딩
                child: PagedListView<int, MangaTitle>(
                  padding: const EdgeInsets.only(bottom: 16),
                  pagingController: _pagingController!,
                  builderDelegate: PagedChildBuilderDelegate<MangaTitle>(
                    itemBuilder: (context, item, index) => MangaListItem(
                      manga: item,
                      onTap: () => navigateToMangaDetail(context, item),
                    ),
                    firstPageErrorIndicatorBuilder: (context) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _pagingController!.error.toString(),
                            style: theme.textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              _webViewInitialized = false;
                              _pagingController!.refresh();
                            },
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                    noItemsFoundIndicatorBuilder: (context) => Center(
                      child: Text(
                        '검색 결과가 없습니다.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
              ),

            // 검색바 (하단 고정)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                elevation: 8,
                color: theme.colorScheme.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 필터 영역
                    SizeTransition(
                      sizeFactor: _filterAnimationController,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 발행 상태 필터
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _publishOptions.map((option) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ActionChip(
                                      label: Text(option),
                                      onPressed: () {
                                        setState(() => _publishValue = option);
                                      },
                                      backgroundColor: _publishValue == option
                                          ? theme.colorScheme.primaryContainer
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 초성 필터
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _jaumOptions.map((option) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ActionChip(
                                      label: Text(option),
                                      onPressed: () {
                                        setState(() => _jaumValue = option);
                                      },
                                      backgroundColor: _jaumValue == option
                                          ? theme.colorScheme.primaryContainer
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 장르 필터
                            Row(
                              children: [
                                ActionChip(
                                  label: Text(
                                    _selectedGenres.isEmpty ||
                                            _selectedGenres.contains('전체')
                                        ? '장르: 전체'
                                        : '장르: ${_selectedGenres.length}개 선택',
                                  ),
                                  onPressed: () async {
                                    final result = await showModalBottomSheet<
                                        List<String>>(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (context) => GenreSelectSheet(
                                        allGenres: _genreOptions,
                                        selected: _selectedGenres,
                                      ),
                                    );
                                    if (result != null) {
                                      setState(() => _selectedGenres = result);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 검색바
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          // 검색창
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: const InputDecoration(
                                hintText: '제목 검색...',
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(16)),
                                ),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onSubmitted: (_) => _onSearch(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 필터 토글 버튼
                          IconButton(
                            icon: const Icon(Icons.filter_list),
                            onPressed: _toggleFilter,
                          ),
                          // 검색 버튼
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _onSearch,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFilter() {
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
      if (_isFilterExpanded) {
        _filterAnimationController.forward();
      } else {
        _filterAnimationController.reverse();
      }
    });
  }

  void navigateToMangaDetail(BuildContext context, MangaTitle manga) {
    MangaNavigation.navigateToMangaDetail(
      context,
      manga.id,
      title: manga.title,
      isChapterUrl: true,
    );
  }
}

class GenreSelectSheet extends StatefulWidget {
  final List<String> allGenres;
  final List<String> selected;
  const GenreSelectSheet({
    required this.allGenres,
    required this.selected,
    super.key,
  });

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
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '장르 선택',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, _tempSelected),
                child: const Text('확인'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.allGenres.map((genre) {
                  final selected = _tempSelected.contains(genre) ||
                      (_tempSelected.isEmpty && genre == '전체');
                  return FilterChip(
                    label: Text(genre),
                    selected: selected,
                    onSelected: (v) {
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
          ),
        ],
      ),
    );
  }
}
