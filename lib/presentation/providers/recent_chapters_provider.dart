import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database_helper.dart';

class RecentChaptersNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _loadChapters();
  }

  Future<List<Map<String, dynamic>>> _loadChapters() async {
    final db = DatabaseHelper.instance;
    return await db.getRecentChapters();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final chapters = await _loadChapters();
      state = AsyncValue.data(chapters);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteChapter(String chapterId) async {
    final db = DatabaseHelper.instance;
    await db.deleteRecentChapter(chapterId);
    refresh();
  }
}

final recentChaptersProvider =
    AsyncNotifierProvider<RecentChaptersNotifier, List<Map<String, dynamic>>>(
  () => RecentChaptersNotifier(),
);

// 홈 화면용 프리뷰 프로바이더 (최근 6개만)
class RecentChaptersPreviewNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _loadPreviewChapters();
  }

  Future<List<Map<String, dynamic>>> _loadPreviewChapters() async {
    final db = DatabaseHelper.instance;
    return await db.getRecentChapters(limit: 6);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final chapters = await _loadPreviewChapters();
      state = AsyncValue.data(chapters);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final recentChaptersPreviewProvider = AsyncNotifierProvider<
    RecentChaptersPreviewNotifier, List<Map<String, dynamic>>>(
  () => RecentChaptersPreviewNotifier(),
);
