import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/api_service.dart';

final artistSuggestionsProvider =
    StateNotifierProvider<ArtistSuggestionsNotifier, AsyncValue<List<String>>>(
        (ref) {
  final apiService = ref.watch(apiServiceProvider());
  return ArtistSuggestionsNotifier(apiService);
});

class ArtistSuggestionsNotifier
    extends StateNotifier<AsyncValue<List<String>>> {
  final ApiService _apiService;
  String _lastQuery = '';

  ArtistSuggestionsNotifier(this._apiService)
      : super(const AsyncValue.data([]));

  Future<void> getSuggestions(String query) async {
    if (query.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    if (query == _lastQuery) return;
    _lastQuery = query;

    state = const AsyncValue.loading();
    state =
        await AsyncValue.guard(() => _apiService.fetchArtistSuggestions(query));
  }

  void clear() {
    state = const AsyncValue.data([]);
    _lastQuery = '';
  }
}
