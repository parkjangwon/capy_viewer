import 'package:freezed_annotation/freezed_annotation.dart';

part 'manga_detail.freezed.dart';
part 'manga_detail.g.dart';

@freezed
class MangaDetail with _$MangaDetail {
  const factory MangaDetail({
    required String id,
    required String title,
    required String thumbnailUrl,
    @Default('') String author,
    @Default('') String genre,
    @Default('') String releaseStatus,
    @Default(<MangaChapter>[]) List<MangaChapter> chapters,
    @Default('') String previousChapterId, // 전편보기 링크의 만화 ID
  }) = _MangaDetail;

  factory MangaDetail.fromJson(Map<String, dynamic> json) =>
      _$MangaDetailFromJson(json);
}

@freezed
class MangaChapter with _$MangaChapter {
  const factory MangaChapter({
    required String id,
    required String title,
    @Default('') String uploadDate,
    @Default(0) int views,
    @Default(0) int rating,
    @Default(0) int likes,
    @Default(0) int comments,
  }) = _MangaChapter;

  factory MangaChapter.fromJson(Map<String, dynamic> json) =>
      _$MangaChapterFromJson(json);
}
