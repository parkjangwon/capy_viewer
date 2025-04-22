import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/recent_added_model.dart';
import '../../data/datasources/api_service.dart';
import '../../data/parsers/recent_added_parser.dart';
import '../../utils/content_filter.dart';

/// 홈 화면: 최신 6개만
final recentAddedPreviewProvider = FutureProvider<List<RecentAddedItem>>((ref) async {
  final api = ref.read(apiServiceProvider());
  final html = await api.fetchRecentAddedPage(1);
  final items = RecentAddedParser.parseRecentAddedList(html);
  final isSafeMode = await ContentFilter.isSafeModeEnabled();
  
  if (!isSafeMode) {
    return items.take(6).toList();
  }

  final filteredItems = await Future.wait(
    items.map((item) async {
      final tags = item.genres.join(' ');
      final isAllowed = await ContentFilter.isContentAllowed(item.title, tags);
      return isAllowed ? item : null;
    }),
  ).then((results) => results.where((item) => item != null).cast<RecentAddedItem>().toList());

  return filteredItems.take(6).toList();
});

/// 더보기(전체): 페이지네이션 (20개씩)
final recentAddedPagingProvider = FutureProvider.family<List<RecentAddedItem>, int>((ref, page) async {
  final api = ref.read(apiServiceProvider());
  final html = await api.fetchRecentAddedPage(page);
  final items = RecentAddedParser.parseRecentAddedList(html);
  final isSafeMode = await ContentFilter.isSafeModeEnabled();
  
  if (!isSafeMode) {
    return items;
  }

  return await Future.wait(
    items.map((item) async {
      final tags = item.genres.join(' ');
      final isAllowed = await ContentFilter.isContentAllowed(item.title, tags);
      return isAllowed ? item : null;
    }),
  ).then((results) => results.where((item) => item != null).cast<RecentAddedItem>().toList());
});
