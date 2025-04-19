import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../../../data/models/manga_title.dart';
import 'manga_grid.dart';
import 'manga_list_item.dart';

class MangaListScreen extends StatelessWidget {
  final String title;
  final PagingController<int, MangaTitle>? pagingController;
  final List<MangaTitle>? items;
  final bool isLoading;
  final String? errorMessage;
  final Widget? topWidget;
  final IconData emptyIcon;
  final String emptyMessage;
  final Widget? floatingActionButton;
  final bool useInfiniteScroll;

  const MangaListScreen({
    super.key,
    required this.title,
    this.pagingController,
    this.items,
    this.isLoading = false,
    this.errorMessage,
    this.topWidget,
    this.emptyIcon = Icons.list,
    this.emptyMessage = '항목이 없습니다.',
    this.floatingActionButton,
    this.useInfiniteScroll = false,
  }) : assert(
          (useInfiniteScroll && pagingController != null) ||
              (!useInfiniteScroll && items != null),
          'Either provide pagingController for infinite scroll or items for regular list',
        );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Column(
        children: [
          if (topWidget != null) topWidget!,
          Expanded(
            child: _buildBody(context),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!useInfiniteScroll) {
      if (isLoading) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      if (errorMessage != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        );
      }

      if (items == null || items!.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                emptyIcon,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        );
      }

      return MangaGrid(items: items!);
    }

    return PagedGridView<int, MangaTitle>(
      pagingController: pagingController!,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      builderDelegate: PagedChildBuilderDelegate<MangaTitle>(
        itemBuilder: (context, item, index) => MangaGridItem(manga: item),
        firstPageErrorIndicatorBuilder: (_) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '오류가 발생했습니다',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => pagingController!.refresh(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        noItemsFoundIndicatorBuilder: (_) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                emptyIcon,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
      padding: const EdgeInsets.all(8),
    );
  }
} 