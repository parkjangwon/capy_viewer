import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/manga_detail.dart';
import '../../data/database/database_helper.dart';

final likeProvider =
    StateNotifierProvider<LikeNotifier, Map<String, bool>>((ref) {
  return LikeNotifier();
});

class LikeNotifier extends StateNotifier<Map<String, bool>> {
  LikeNotifier() : super({});
  final _db = DatabaseHelper.instance;

  Future<void> init() async {
    final likedChapters = await _db.getLikedChapters();
    state = {for (var id in likedChapters) id: true};
  }

  Future<void> toggleLike(MangaChapter chapter) async {
    if (state[chapter.id] ?? false) {
      // 좋아요 취소
      await _db.removeLikedChapter(chapter.id);
      state = {...state}..remove(chapter.id);
    } else {
      // 좋아요 추가
      await _db.addLikedChapter(chapter.id);
      state = {...state, chapter.id: true};
    }
  }

  bool isLiked(String chapterId) {
    return state[chapterId] ?? false;
  }
}
