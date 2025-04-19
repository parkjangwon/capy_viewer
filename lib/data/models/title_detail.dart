import 'package:freezed_annotation/freezed_annotation.dart';
import 'chapter.dart';

part 'title_detail.freezed.dart';
part 'title_detail.g.dart';

@freezed
class TitleDetail with _$TitleDetail {
  const factory TitleDetail({
    required String id,
    required String title,
    required String thumbnailUrl,
    required String url,
    @Default([]) List<Chapter> chapters,
    String? description,
    String? author,
    String? status,
  }) = _TitleDetail;

  factory TitleDetail.fromJson(Map<String, dynamic> json) => _$TitleDetailFromJson(json);
}

@freezed
class Chapter with _$Chapter {
  const factory Chapter({
    required String id,
    required String title,
    required String url,
    required DateTime uploadDate,
  }) = _Chapter;

  factory Chapter.fromJson(Map<String, dynamic> json) => _$ChapterFromJson(json);
} 