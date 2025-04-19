import 'package:freezed_annotation/freezed_annotation.dart';

part 'manga.freezed.dart';
part 'manga.g.dart';

enum MangaMode {
  vertical,
  horizontal,
}

@freezed
class Manga with _$Manga {
  const factory Manga({
    required int id,
    required String name,
    required String url,
    @Default([]) List<String> thumbnails,
    @Default(MangaMode.vertical) MangaMode mode,
    @Default([]) List<String> images,
    required String date,
  }) = _Manga;

  factory Manga.fromJson(Map<String, dynamic> json) => _$MangaFromJson(json);
} 