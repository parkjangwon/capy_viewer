import 'package:freezed_annotation/freezed_annotation.dart';

part 'manga_title.freezed.dart';
part 'manga_title.g.dart';

@freezed
class MangaTitle with _$MangaTitle {
  const factory MangaTitle({
    required String id,
    required String title,
    required String thumbnailUrl,
    @Default('') String author,
    @Default('') String release,
    @Default('manga') String type,
  }) = _MangaTitle;

  factory MangaTitle.fromJson(Map<String, dynamic> json) =>
      _$MangaTitleFromJson(json);
} 