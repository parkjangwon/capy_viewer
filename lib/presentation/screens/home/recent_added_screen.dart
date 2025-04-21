import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/recent_added_provider.dart';
import '../../../data/models/recent_added_model.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:fluttertoast/fluttertoast.dart';

class RecentAddedScreen extends ConsumerStatefulWidget {
  const RecentAddedScreen({Key? key}) : super(key: key);
  @override
  ConsumerState<RecentAddedScreen> createState() => _RecentAddedScreenState();
}

class _RecentAddedScreenState extends ConsumerState<RecentAddedScreen> {
  static const _pageSize = 20;
  final PagingController<int, RecentAddedItem> _pagingController = PagingController(firstPageKey: 1);

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final items = await ref.read(recentAddedPagingProvider(pageKey).future);
      final isLastPage = pageKey == 10;
      final nextPageKey = isLastPage ? null : pageKey + 1;
      if (isLastPage) {
        _pagingController.appendLastPage(items);
      } else {
        _pagingController.appendPage(items, nextPageKey);
      }
    } catch (e) {
      _pagingController.error = e;
    }
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
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
      body: PagedListView<int, RecentAddedItem>(
        pagingController: _pagingController,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        builderDelegate: PagedChildBuilderDelegate<RecentAddedItem>(
          itemBuilder: (context, item, idx) => _RecentAddedListItem(item: item),
          noItemsFoundIndicatorBuilder: (context) => const Center(child: Text('작품 없음')),
        ),
      ),
    );
  }
}

class _RecentAddedListItem extends StatelessWidget {
  final RecentAddedItem item;
  const _RecentAddedListItem({required this.item});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Fluttertoast.showToast(
            msg: '클릭됨: ${item.url}',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.thumbnailUrl,
                  width: 80,
                  height: 110,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 110,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          item.date,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.deepPurple),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.comment, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 2),
                        Text('${item.comments ?? 0}', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 8),
                        Icon(Icons.thumb_up_alt_outlined, size: 16, color: Colors.pink),
                        const SizedBox(width: 2),
                        Text('${item.likes ?? 0}', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 8),
                        Icon(Icons.remove_red_eye, size: 16, color: Colors.teal),
                        const SizedBox(width: 2),
                        Text('${item.views ?? 0}', style: Theme.of(context).textTheme.bodySmall),
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
                        children: item.genres.map((g) => Chip(
                          label: Text(g),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 우측: 전편보기 버튼 (높이 꽉차게)
              SizedBox(
                height: 110,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () {
                    Fluttertoast.showToast(
                      msg: '전편보기: ${item.url}',
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                    );
                  },
                  child: const Text('전편보기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
