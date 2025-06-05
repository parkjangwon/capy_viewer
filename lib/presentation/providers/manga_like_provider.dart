import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database_helper.dart';

final mangaLikeProvider =
    StateNotifierProvider<MangaLikeNotifier, Map<String, bool>>((ref) {
  return MangaLikeNotifier();
});

class MangaLikeNotifier extends StateNotifier<Map<String, bool>> {
  MangaLikeNotifier() : super({});
  final _db = DatabaseHelper.instance;

  Future<void> init() async {
    final likedChapters = await _db.getLikedChapters();
    state = {for (var id in likedChapters) id: true};
  }

  Future<void> toggleLike(String mangaId) async {
    final isLiked = state[mangaId] ?? false;
    if (isLiked) {
      await _db.removeLikedChapter(mangaId);
      state = {...state}..remove(mangaId);
    } else {
      await _db.addLikedChapter(mangaId);
      state = {...state, mangaId: true};
    }
  }

  bool isLiked(String mangaId) {
    return state[mangaId] ?? false;
  }
}
