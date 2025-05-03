import 'package:freezed_annotation/freezed_annotation.dart';

part 'chapter.freezed.dart';
part 'chapter.g.dart';세

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