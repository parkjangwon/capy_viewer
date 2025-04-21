import 'package:flutter/material.dart';
import 'recent_added_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/recent_added_model.dart';
import '../../viewmodels/recent_added_provider.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onRecentTap;
  const HomeScreen({Key? key, this.onRecentTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                final asyncValue = ref.watch(recentAddedPreviewProvider);
                return asyncValue.when(
                  data: (items) => _HorizontalCardList(
                    items: items,
                    placeholderCount: 6,
                  ),
                  loading: () => _HorizontalCardList(placeholderCount: 6),
                  error: (e, st) => Center(child: Text('불러오기 실패')),
                );
              },
            ),
            const SizedBox(height: 16),
            _SectionTitleWithAction(
              title: '최근에 본 작품',
              onAction: onRecentTap,
            ),
            _HorizontalCardList(placeholderCount: 6, emptyText: '결과 없음'),
            const SizedBox(height: 16),
            _SectionTitle('주간 베스트'),
            _VerticalList(placeholderCount: 10),
            const SizedBox(height: 16),
            _SectionTitle('일본만화 베스트'),
            _VerticalList(placeholderCount: 6),
            const SizedBox(height: 16),
            _SectionTitle('이름'),
            _NameSelector(),
            const SizedBox(height: 16),
            _SectionTitle('장르'),
            _GenreSelector(),
            const SizedBox(height: 16),
            _SectionTitle('발행'),
            _PublishSelector(),
            const SizedBox(height: 24),
          ],
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
              constraints: BoxConstraints(),
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
            return SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.thumbnailUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 32, color: Colors.grey),
                      ),
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
            );
          },
        ),
      );
    }
    if (placeholderCount == 0 && emptyText != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(emptyText!, style: TextStyle(color: Colors.grey)),
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
        subtitle: Text('설명 또는 회차'),
        dense: true,
        onTap: () {},
      ),
    );
  }
}

class _NameSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final names = ['ㄱ', 'ㄴ', 'ㄷ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅅ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ', '0-9', 'A-Z'];
    return Wrap(
      children: names.map((n) => _ChipButton(label: n)).toList(),
    );
  }
}

class _GenreSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final genres = ['17', 'BL', 'SF', 'TS', '개그', '게임', '도박', '드라마', '라노벨', '러브코미디', '먹방', '백합', '붕탁', '순정', '스릴러', '스포츠', '시대', '애니화', '액션', '음악', '이세계', '일상', '전생', '추리', '판타지', '학원', '호러'];
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
        side: BorderSide(color: isDark ? Colors.deepPurple[300]! : Colors.deepPurple[200]!),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
    );
  }
}
