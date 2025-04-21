import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/recent_added_model.dart';
import '../../data/datasources/api_service.dart';
import '../../data/parsers/recent_added_parser.dart';

/// 홈 화면: 최신 6개만
final recentAddedPreviewProvider = FutureProvider<List<RecentAddedItem>>((ref) async {
  final api = ref.read(apiServiceProvider());
  final html = await api.fetchRecentAddedPage(1);
  final items = RecentAddedParser.parseRecentAddedList(html);
  return items.take(6).toList();
});

/// 더보기(전체): 페이지네이션 (20개씩)
final recentAddedPagingProvider = FutureProvider.family<List<RecentAddedItem>, int>((ref, page) async {
  final api = ref.read(apiServiceProvider());
  final html = await api.fetchRecentAddedPage(page);
  final items = RecentAddedParser.parseRecentAddedList(html);
  return items;
});
