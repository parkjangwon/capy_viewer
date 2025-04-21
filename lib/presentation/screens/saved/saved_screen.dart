import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/manga/manga_list_screen.dart';
import '../../viewmodels/saved_provider.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: const MangaListScreen(
        title: '',
        items: [],
        emptyIcon: Icons.bookmark_outline,
        emptyMessage: '저장한 작품이 없습니다.',
      ),
    );
  }
}
