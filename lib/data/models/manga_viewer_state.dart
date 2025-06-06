import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'manga_page.dart';

part 'manga_viewer_state.freezed.dart';

// 캡챠 타입 enum
enum CaptchaType {
  none,
  manatoki,
  cloudflare,
}

// 뷰 모드 enum
enum ViewMode {
  basic,
  single,
  double,
}

// 읽기 방향 enum
enum ReadingDirection {
  ltr, // 왼쪽에서 오른쪽
  rtl, // 오른쪽에서 왼쪽
}

@freezed
class Chapter with _$Chapter {
  const factory Chapter({
    required String id,
    required String title,
    @Default('') String url,
  }) = _Chapter;
}

@freezed
class MangaViewerState with _$MangaViewerState {
  const factory MangaViewerState({
    @Default(false) bool isLoading,
    @Default(false) bool hasError,
    @Default('') String errorMessage,
    @Default([]) List<MangaPage> pages,
    @Default(0) int currentPageIndex,
    @Default(ViewMode.basic) ViewMode viewMode,
    @Default(ReadingDirection.rtl) ReadingDirection readingDirection,
    @Default(CaptchaType.none) CaptchaType captchaType,
    Map<String, dynamic>? captchaInfo,
    @Default('') String seriesTitle,
    @Default('') String chapterTitle,
    @Default('') String prevChapterUrl,
    @Default('') String nextChapterUrl,
    @Default([]) List<Chapter> chapters,
    @Default('') String currentChapterId,
  }) = _MangaViewerState;
}
