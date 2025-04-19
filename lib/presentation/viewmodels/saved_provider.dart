import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/manga_title.dart';
import 'dart:convert';

part 'saved_provider.g.dart';

@Riverpod(keepAlive: true)
class Saved extends _$Saved {
  static const _key = 'saved_manga';

  @override
  Future<List<MangaTitle>> build() async {
    return _loadSavedManga();
  }

  Future<List<MangaTitle>> _loadSavedManga() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getStringList(_key) ?? [];
    return savedJson
        .map((json) => MangaTitle.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> toggleSaved(MangaTitle manga) async {
    final currentState = await future;
    final prefs = await SharedPreferences.getInstance();
    
    final isSaved = currentState.any((item) => item.id == manga.id);
    List<MangaTitle> newState;
    
    if (isSaved) {
      newState = currentState.where((item) => item.id != manga.id).toList();
    } else {
      newState = [...currentState, manga];
    }

    await prefs.setStringList(
      _key,
      newState.map((item) => jsonEncode(item.toJson())).toList(),
    );

    state = AsyncValue.data(newState);
  }

  Future<bool> isSaved(String mangaId) async {
    final currentState = await future;
    return currentState.any((item) => item.id == mangaId);
  }
} 