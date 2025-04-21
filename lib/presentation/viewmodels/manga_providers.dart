import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/manga_title.dart';
import '../../data/datasources/api_service.dart';

final recentTitlesProvider = FutureProvider<List<MangaTitle>>((ref) async {
  final apiService = ref.watch(apiServiceProvider());
  return apiService.fetchRecentTitles();
});

final weeklyBestProvider = FutureProvider<List<MangaTitle>>((ref) async {
  final apiService = ref.watch(apiServiceProvider());
  return apiService.fetchWeeklyBest();
}); 