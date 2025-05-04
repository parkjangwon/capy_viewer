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
    @Default(<String>[]) List<String> genres,
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
    String? fullViewUrl,
  }) = _MangaChapter;

  factory MangaChapter.fromJson(Map<String, dynamic> json) =>
      _$MangaChapterFromJson(json);

  static MangaChapter fromMap(Map<String, dynamic> map) {
    return MangaChapter(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      uploadDate: map['date'] ?? '',
      views: map['views'] ?? 0,
      likes: map['likes'] ?? 0,
      rating: map['rating'] ?? 0,
      comments: map['comments'] ?? 0,
      fullViewUrl: map['fullViewUrl'],
    );
  }
}

extension MangaChapterMap on MangaChapter {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': uploadDate,
      'views': views,
      'likes': likes,
      'rating': rating,
      'comments': comments,
      'fullViewUrl': fullViewUrl,
    };
  }
}
