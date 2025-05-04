import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/manga/manga_list_screen.dart';

class RecentScreen extends ConsumerWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SafeArea(
      child: MangaListScreen(
        title: '',
        items: [],
        emptyIcon: Icons.history_outlined,
        emptyMessage: '최근에 본 작품이 없습니다.',
      ),
    );
  }
}
