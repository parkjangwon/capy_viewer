import 'package:freezed_annotation/freezed_annotation.dart';

part 'manga_page.freezed.dart';
part 'manga_page.g.dart';

@freezed
class MangaPage with _$MangaPage {
  const factory MangaPage({
    required int index,
    required String imageUrl,
    @Default(false) bool isLoaded,
    @Default(false) bool isLoading,
    @Default(false) bool isError,
  }) = _MangaPage;

  factory MangaPage.fromJson(Map<String, dynamic> json) =>
      _$MangaPageFromJson(json);
}
