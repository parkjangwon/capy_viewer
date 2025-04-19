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

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final _pagingController = PagingController<int, MangaTitle>(firstPageKey: 0);
  String _currentQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pagingController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    if (_currentQuery.isEmpty) {
      _pagingController.appendLastPage([]);
      return;
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      final newItems = await apiService.search(_currentQuery, offset: pageKey);
      
      final isLastPage = newItems.isEmpty;
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + newItems.length;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (e) {
      _pagingController.error = e;
    }
  }

  void _onSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _currentQuery = query;
      });
      _pagingController.refresh();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentQuery = '';
    });
    _pagingController.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _currentQuery.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 32),
                          Icon(
                            Icons.search_rounded,
                            size: 100,
                            color: theme.colorScheme.primary.withOpacity(0.8),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '검색어를 입력해주세요',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onBackground.withOpacity(0.4),
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _pagingController.refresh();
                      },
                      child: PagedListView<int, MangaTitle>(
                        pagingController: _pagingController,
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
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: '제목을 입력하세요',
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                      : null,
                ),
                onChanged: _onSearch,
                onSubmitted: _onSearch,
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