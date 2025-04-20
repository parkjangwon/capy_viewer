import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'dart:async';
import '../../../data/models/manga_title.dart';
import '../../../data/datasources/api_service.dart';
import '../../viewmodels/manga_providers.dart';
import '../../widgets/manga/manga_grid.dart';
import '../../widgets/manga/manga_list_item.dart';
import '../../widgets/search/search_bar.dart';
import '../../widgets/search/search_filters.dart';
import '../../widgets/captcha/cloudflare_captcha.dart';
import '../../screens/captcha/captcha_screen.dart';
import '../../../data/datasources/site_url_service.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  PagingController<int, MangaTitle>? _pagingController;
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
  void dispose() {
    _searchController.dispose();
    _pagingController?.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    // 검색어가 없으면 절대 캡차/네트워크 요청을 하지 않음
    if (_currentQuery.trim().isEmpty) {
      _pagingController?.appendLastPage([]);
      return;
    }

    // 1. 캡차 인증 유효성 검사
    final isCaptchaValid = await CloudflareCaptcha.isCaptchaValid();
    if (!isCaptchaValid) {
      // 캡차 인증 필요: 인증 성공 시 검색 재시작
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CaptchaScreen(url: ref.read(siteUrlServiceProvider)),
        ),
      );
      if (result != null && mounted) {
        await _fetchPage(pageKey);
      } else if (mounted) {
        _pagingController?.error = '캡차 인증이 필요합니다.';
      }
      return;
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      final newItems = await apiService.search(_currentQuery, offset: pageKey);
      
      final isLastPage = newItems.isEmpty;
      if (isLastPage) {
        _pagingController?.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + newItems.length;
        _pagingController?.appendPage(newItems, nextPageKey);
      }
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
                          color: theme.colorScheme.onBackground.withOpacity(0.4),
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
                          firstPageProgressIndicatorBuilder: (context) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          newPageProgressIndicatorBuilder: (context) => const Padding(
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
                                  color: theme.colorScheme.primary.withOpacity(0.8),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  '검색 결과가 없습니다',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onBackground.withOpacity(0.4),
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
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _onSearch,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.search),
                    onPressed: () => _onSearch(_searchController.text),
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
    context.push('/detail/${manga.id}');
  }
} 