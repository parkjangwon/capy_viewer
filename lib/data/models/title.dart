import 'package:freezed_annotation/freezed_annotation.dart';

part 'title.freezed.dart';
part 'title.g.dart';

@freezed
class Title with _$Title {
  const factory Title({
    required String id,
    required String title,
    required String thumbnailUrl,
    String? author,
    String? date,
  }) = _Title;

  factory Title.fromJson(Map<String, dynamic> json) => _$TitleFromJson(json);
} 