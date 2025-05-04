import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/manga/manga_list_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SafeArea(
      child: MangaListScreen(
        title: '',
        items: [],
        emptyIcon: Icons.favorite_outline,
        emptyMessage: '좋아요 한 작품이 없습니다.',
      ),
    );
  }
}
