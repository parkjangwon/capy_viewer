import 'package:flutter/material.dart';
import 'recent_added_screen.dart';

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
              title: '최근 추가된 만화',
              onAction: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RecentAddedScreen(),
                  ),
                );
              },
            ),
            _HorizontalCardList(placeholderCount: 6),
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
  const _HorizontalCardList({required this.placeholderCount, this.emptyText});
  @override
  Widget build(BuildContext context) {
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
          child: Center(child: Text('만화 ${idx + 1}')),
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
  static const List<String> kor = ['ㄱ','ㄴ','ㄷ','ㄹ','ㅁ','ㅂ','ㅅ','ㅇ','ㅈ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ'];
  static const List<String> eng = ['A-Z','0-9'];
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        ...kor.map((e) => _ChipButton(label: e)),
        ...eng.map((e) => _ChipButton(label: e)),
      ],
    );
  }
}

class _GenreSelector extends StatelessWidget {
  static const genres = [
    '17', 'BL', 'SF', 'TS', '개그', '게임', '도박', '드라마', '라노벨', '러브코미디', '먹방',
    '백합', '붕탁', '순정', '스릴러', '스포츠', '시대', '애니', '액션', '음악', '이세계',
    '일상', '전생', '추리', '판타지', '학원', '호러',
  ];
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: genres.map((g) => _ChipButton(label: g)).toList(),
    );
  }
}

class _PublishSelector extends StatelessWidget {
  static const publish = ['미분류','주간','격주','월간','단편','단행본','완결'];
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: publish.map((p) => _ChipButton(label: p)).toList(),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  const _ChipButton({required this.label});
  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: () {},
      backgroundColor: Colors.grey[200],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
