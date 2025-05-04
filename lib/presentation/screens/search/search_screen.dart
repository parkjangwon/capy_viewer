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

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  PagingController<int, MangaTitle>? _pagingController;
  late final SearchWebViewController _webViewHelper = SearchWebViewController();
  bool _webViewInitialized = false;
  String _currentQuery = '';

  void _onSearch(String query) {
    setState(() {
      _currentQuery = query.trim();
      _pagingController?.dispose();
      if (_currentQuery.isNotEmpty) {
        _pagingController = PagingController<int, MangaTitle>(firstPageKey: 0)
          ..addPageRequestListener(_fetchPage);
      } else {
        _pagingController = null;
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
    // 검색어가 없으면 절대 캡차/네트워크 요청을 하지 않음
    if (_currentQuery.trim().isEmpty) {
      _pagingController?.appendLastPage([]);
      return;
    }

    try {
      final baseUrl = ref.read(siteUrlServiceProvider);
      await _webViewHelper.loadSearch(baseUrl, _currentQuery);
      final html = await _webViewHelper.getHtml();
      // 캡차 페이지 감지
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
          // 인증 후 재검색
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
      _pagingController?.appendLastPage(newItems);
    } catch (e) {
      _pagingController?.error = e;
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentQuery = '';
    });
    _pagingController?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _pagingController == null
                  ? Center(
                      child: Text(
                        '검색어를 입력하고 검색 버튼을 눌러주세요',
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _pagingController!.refresh();
                      },
                      child: PagedListView<int, MangaTitle>(
                        pagingController: _pagingController!,
                        builderDelegate: PagedChildBuilderDelegate<MangaTitle>(
                          itemBuilder: (context, item, index) => MangaListItem(
                            manga: item,
                            onTap: () => _onMangaSelected(context, item),
                          ),
                          firstPageProgressIndicatorBuilder: (context) =>
                              const Center(
                            child: CircularProgressIndicator(),
                          ),
                          newPageProgressIndicatorBuilder: (context) =>
                              const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          noItemsFoundIndicatorBuilder: (context) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 32),
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 100,
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.8),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  '검색 결과가 없습니다',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.4),
                                  ),
                                ),
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '제목을 입력하세요',
                        border: const OutlineInputBorder(),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _onSearch('');
                                  });
                                },
                              )
                            : null,
                      ),
                      onSubmitted: _onSearch,
                      onChanged: (_) => setState(() {}),
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
