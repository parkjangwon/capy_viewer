// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'manga_viewer_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Chapter {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ChapterCopyWith<Chapter> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChapterCopyWith<$Res> {
  factory $ChapterCopyWith(Chapter value, $Res Function(Chapter) then) =
      _$ChapterCopyWithImpl<$Res, Chapter>;
  @useResult
  $Res call({String id, String title, String url});
}

/// @nodoc
class _$ChapterCopyWithImpl<$Res, $Val extends Chapter>
    implements $ChapterCopyWith<$Res> {
  _$ChapterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? url = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChapterImplCopyWith<$Res> implements $ChapterCopyWith<$Res> {
  factory _$$ChapterImplCopyWith(
          _$ChapterImpl value, $Res Function(_$ChapterImpl) then) =
      __$$ChapterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title, String url});
}

/// @nodoc
class __$$ChapterImplCopyWithImpl<$Res>
    extends _$ChapterCopyWithImpl<$Res, _$ChapterImpl>
    implements _$$ChapterImplCopyWith<$Res> {
  __$$ChapterImplCopyWithImpl(
      _$ChapterImpl _value, $Res Function(_$ChapterImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? url = null,
  }) {
    return _then(_$ChapterImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$ChapterImpl with DiagnosticableTreeMixin implements _Chapter {
  const _$ChapterImpl({required this.id, required this.title, this.url = ''});

  @override
  final String id;
  @override
  final String title;
  @override
  @JsonKey()
  final String url;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'Chapter(id: $id, title: $title, url: $url)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'Chapter'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('title', title))
      ..add(DiagnosticsProperty('url', url));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChapterImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.url, url) || other.url == url));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, title, url);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChapterImplCopyWith<_$ChapterImpl> get copyWith =>
      __$$ChapterImplCopyWithImpl<_$ChapterImpl>(this, _$identity);
}

abstract class _Chapter implements Chapter {
  const factory _Chapter(
      {required final String id,
      required final String title,
      final String url}) = _$ChapterImpl;

  @override
  String get id;
  @override
  String get title;
  @override
  String get url;
  @override
  @JsonKey(ignore: true)
  _$$ChapterImplCopyWith<_$ChapterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MangaViewerState {
  bool get isLoading => throw _privateConstructorUsedError;
  bool get hasError => throw _privateConstructorUsedError;
  String get errorMessage => throw _privateConstructorUsedError;
  List<MangaPage> get pages => throw _privateConstructorUsedError;
  int get currentPageIndex => throw _privateConstructorUsedError;
  ViewMode get viewMode => throw _privateConstructorUsedError;
  ReadingDirection get readingDirection => throw _privateConstructorUsedError;
  CaptchaType get captchaType => throw _privateConstructorUsedError;
  Map<String, dynamic>? get captchaInfo => throw _privateConstructorUsedError;
  String get seriesTitle => throw _privateConstructorUsedError;
  String get chapterTitle => throw _privateConstructorUsedError;
  String get prevChapterUrl => throw _privateConstructorUsedError;
  String get nextChapterUrl => throw _privateConstructorUsedError;
  List<Chapter> get chapters => throw _privateConstructorUsedError;
  String get currentChapterId => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MangaViewerStateCopyWith<MangaViewerState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MangaViewerStateCopyWith<$Res> {
  factory $MangaViewerStateCopyWith(
          MangaViewerState value, $Res Function(MangaViewerState) then) =
      _$MangaViewerStateCopyWithImpl<$Res, MangaViewerState>;
  @useResult
  $Res call(
      {bool isLoading,
      bool hasError,
      String errorMessage,
      List<MangaPage> pages,
      int currentPageIndex,
      ViewMode viewMode,
      ReadingDirection readingDirection,
      CaptchaType captchaType,
      Map<String, dynamic>? captchaInfo,
      String seriesTitle,
      String chapterTitle,
      String prevChapterUrl,
      String nextChapterUrl,
      List<Chapter> chapters,
      String currentChapterId});
}

/// @nodoc
class _$MangaViewerStateCopyWithImpl<$Res, $Val extends MangaViewerState>
    implements $MangaViewerStateCopyWith<$Res> {
  _$MangaViewerStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isLoading = null,
    Object? hasError = null,
    Object? errorMessage = null,
    Object? pages = null,
    Object? currentPageIndex = null,
    Object? viewMode = null,
    Object? readingDirection = null,
    Object? captchaType = null,
    Object? captchaInfo = freezed,
    Object? seriesTitle = null,
    Object? chapterTitle = null,
    Object? prevChapterUrl = null,
    Object? nextChapterUrl = null,
    Object? chapters = null,
    Object? currentChapterId = null,
  }) {
    return _then(_value.copyWith(
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      hasError: null == hasError
          ? _value.hasError
          : hasError // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: null == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String,
      pages: null == pages
          ? _value.pages
          : pages // ignore: cast_nullable_to_non_nullable
              as List<MangaPage>,
      currentPageIndex: null == currentPageIndex
          ? _value.currentPageIndex
          : currentPageIndex // ignore: cast_nullable_to_non_nullable
              as int,
      viewMode: null == viewMode
          ? _value.viewMode
          : viewMode // ignore: cast_nullable_to_non_nullable
              as ViewMode,
      readingDirection: null == readingDirection
          ? _value.readingDirection
          : readingDirection // ignore: cast_nullable_to_non_nullable
              as ReadingDirection,
      captchaType: null == captchaType
          ? _value.captchaType
          : captchaType // ignore: cast_nullable_to_non_nullable
              as CaptchaType,
      captchaInfo: freezed == captchaInfo
          ? _value.captchaInfo
          : captchaInfo // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      seriesTitle: null == seriesTitle
          ? _value.seriesTitle
          : seriesTitle // ignore: cast_nullable_to_non_nullable
              as String,
      chapterTitle: null == chapterTitle
          ? _value.chapterTitle
          : chapterTitle // ignore: cast_nullable_to_non_nullable
              as String,
      prevChapterUrl: null == prevChapterUrl
          ? _value.prevChapterUrl
          : prevChapterUrl // ignore: cast_nullable_to_non_nullable
              as String,
      nextChapterUrl: null == nextChapterUrl
          ? _value.nextChapterUrl
          : nextChapterUrl // ignore: cast_nullable_to_non_nullable
              as String,
      chapters: null == chapters
          ? _value.chapters
          : chapters // ignore: cast_nullable_to_non_nullable
              as List<Chapter>,
      currentChapterId: null == currentChapterId
          ? _value.currentChapterId
          : currentChapterId // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MangaViewerStateImplCopyWith<$Res>
    implements $MangaViewerStateCopyWith<$Res> {
  factory _$$MangaViewerStateImplCopyWith(_$MangaViewerStateImpl value,
          $Res Function(_$MangaViewerStateImpl) then) =
      __$$MangaViewerStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isLoading,
      bool hasError,
      String errorMessage,
      List<MangaPage> pages,
      int currentPageIndex,
      ViewMode viewMode,
      ReadingDirection readingDirection,
      CaptchaType captchaType,
      Map<String, dynamic>? captchaInfo,
      String seriesTitle,
      String chapterTitle,
      String prevChapterUrl,
      String nextChapterUrl,
      List<Chapter> chapters,
      String currentChapterId});
}

/// @nodoc
class __$$MangaViewerStateImplCopyWithImpl<$Res>
    extends _$MangaViewerStateCopyWithImpl<$Res, _$MangaViewerStateImpl>
    implements _$$MangaViewerStateImplCopyWith<$Res> {
  __$$MangaViewerStateImplCopyWithImpl(_$MangaViewerStateImpl _value,
      $Res Function(_$MangaViewerStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isLoading = null,
    Object? hasError = null,
    Object? errorMessage = null,
    Object? pages = null,
    Object? currentPageIndex = null,
    Object? viewMode = null,
    Object? readingDirection = null,
    Object? captchaType = null,
    Object? captchaInfo = freezed,
    Object? seriesTitle = null,
    Object? chapterTitle = null,
    Object? prevChapterUrl = null,
    Object? nextChapterUrl = null,
    Object? chapters = null,
    Object? currentChapterId = null,
  }) {
    return _then(_$MangaViewerStateImpl(
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      hasError: null == hasError
          ? _value.hasError
          : hasError // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: null == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String,
      pages: null == pages
          ? _value._pages
          : pages // ignore: cast_nullable_to_non_nullable
              as List<MangaPage>,
      currentPageIndex: null == currentPageIndex
          ? _value.currentPageIndex
          : currentPageIndex // ignore: cast_nullable_to_non_nullable
              as int,
      viewMode: null == viewMode
          ? _value.viewMode
          : viewMode // ignore: cast_nullable_to_non_nullable
              as ViewMode,
      readingDirection: null == readingDirection
          ? _value.readingDirection
          : readingDirection // ignore: cast_nullable_to_non_nullable
              as ReadingDirection,
      captchaType: null == captchaType
          ? _value.captchaType
          : captchaType // ignore: cast_nullable_to_non_nullable
              as CaptchaType,
      captchaInfo: freezed == captchaInfo
          ? _value._captchaInfo
          : captchaInfo // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      seriesTitle: null == seriesTitle
          ? _value.seriesTitle
          : seriesTitle // ignore: cast_nullable_to_non_nullable
              as String,
      chapterTitle: null == chapterTitle
          ? _value.chapterTitle
          : chapterTitle // ignore: cast_nullable_to_non_nullable
              as String,
      prevChapterUrl: null == prevChapterUrl
          ? _value.prevChapterUrl
          : prevChapterUrl // ignore: cast_nullable_to_non_nullable
              as String,
      nextChapterUrl: null == nextChapterUrl
          ? _value.nextChapterUrl
          : nextChapterUrl // ignore: cast_nullable_to_non_nullable
              as String,
      chapters: null == chapters
          ? _value._chapters
          : chapters // ignore: cast_nullable_to_non_nullable
              as List<Chapter>,
      currentChapterId: null == currentChapterId
          ? _value.currentChapterId
          : currentChapterId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$MangaViewerStateImpl
    with DiagnosticableTreeMixin
    implements _MangaViewerState {
  const _$MangaViewerStateImpl(
      {this.isLoading = false,
      this.hasError = false,
      this.errorMessage = '',
      final List<MangaPage> pages = const [],
      this.currentPageIndex = 0,
      this.viewMode = ViewMode.basic,
      this.readingDirection = ReadingDirection.rtl,
      this.captchaType = CaptchaType.none,
      final Map<String, dynamic>? captchaInfo,
      this.seriesTitle = '',
      this.chapterTitle = '',
      this.prevChapterUrl = '',
      this.nextChapterUrl = '',
      final List<Chapter> chapters = const [],
      this.currentChapterId = ''})
      : _pages = pages,
        _captchaInfo = captchaInfo,
        _chapters = chapters;

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool hasError;
  @override
  @JsonKey()
  final String errorMessage;
  final List<MangaPage> _pages;
  @override
  @JsonKey()
  List<MangaPage> get pages {
    if (_pages is EqualUnmodifiableListView) return _pages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pages);
  }

  @override
  @JsonKey()
  final int currentPageIndex;
  @override
  @JsonKey()
  final ViewMode viewMode;
  @override
  @JsonKey()
  final ReadingDirection readingDirection;
  @override
  @JsonKey()
  final CaptchaType captchaType;
  final Map<String, dynamic>? _captchaInfo;
  @override
  Map<String, dynamic>? get captchaInfo {
    final value = _captchaInfo;
    if (value == null) return null;
    if (_captchaInfo is EqualUnmodifiableMapView) return _captchaInfo;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey()
  final String seriesTitle;
  @override
  @JsonKey()
  final String chapterTitle;
  @override
  @JsonKey()
  final String prevChapterUrl;
  @override
  @JsonKey()
  final String nextChapterUrl;
  final List<Chapter> _chapters;
  @override
  @JsonKey()
  List<Chapter> get chapters {
    if (_chapters is EqualUnmodifiableListView) return _chapters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapters);
  }

  @override
  @JsonKey()
  final String currentChapterId;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'MangaViewerState(isLoading: $isLoading, hasError: $hasError, errorMessage: $errorMessage, pages: $pages, currentPageIndex: $currentPageIndex, viewMode: $viewMode, readingDirection: $readingDirection, captchaType: $captchaType, captchaInfo: $captchaInfo, seriesTitle: $seriesTitle, chapterTitle: $chapterTitle, prevChapterUrl: $prevChapterUrl, nextChapterUrl: $nextChapterUrl, chapters: $chapters, currentChapterId: $currentChapterId)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'MangaViewerState'))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('hasError', hasError))
      ..add(DiagnosticsProperty('errorMessage', errorMessage))
      ..add(DiagnosticsProperty('pages', pages))
      ..add(DiagnosticsProperty('currentPageIndex', currentPageIndex))
      ..add(DiagnosticsProperty('viewMode', viewMode))
      ..add(DiagnosticsProperty('readingDirection', readingDirection))
      ..add(DiagnosticsProperty('captchaType', captchaType))
      ..add(DiagnosticsProperty('captchaInfo', captchaInfo))
      ..add(DiagnosticsProperty('seriesTitle', seriesTitle))
      ..add(DiagnosticsProperty('chapterTitle', chapterTitle))
      ..add(DiagnosticsProperty('prevChapterUrl', prevChapterUrl))
      ..add(DiagnosticsProperty('nextChapterUrl', nextChapterUrl))
      ..add(DiagnosticsProperty('chapters', chapters))
      ..add(DiagnosticsProperty('currentChapterId', currentChapterId));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MangaViewerStateImpl &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.hasError, hasError) ||
                other.hasError == hasError) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            const DeepCollectionEquality().equals(other._pages, _pages) &&
            (identical(other.currentPageIndex, currentPageIndex) ||
                other.currentPageIndex == currentPageIndex) &&
            (identical(other.viewMode, viewMode) ||
                other.viewMode == viewMode) &&
            (identical(other.readingDirection, readingDirection) ||
                other.readingDirection == readingDirection) &&
            (identical(other.captchaType, captchaType) ||
                other.captchaType == captchaType) &&
            const DeepCollectionEquality()
                .equals(other._captchaInfo, _captchaInfo) &&
            (identical(other.seriesTitle, seriesTitle) ||
                other.seriesTitle == seriesTitle) &&
            (identical(other.chapterTitle, chapterTitle) ||
                other.chapterTitle == chapterTitle) &&
            (identical(other.prevChapterUrl, prevChapterUrl) ||
                other.prevChapterUrl == prevChapterUrl) &&
            (identical(other.nextChapterUrl, nextChapterUrl) ||
                other.nextChapterUrl == nextChapterUrl) &&
            const DeepCollectionEquality().equals(other._chapters, _chapters) &&
            (identical(other.currentChapterId, currentChapterId) ||
                other.currentChapterId == currentChapterId));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      isLoading,
      hasError,
      errorMessage,
      const DeepCollectionEquality().hash(_pages),
      currentPageIndex,
      viewMode,
      readingDirection,
      captchaType,
      const DeepCollectionEquality().hash(_captchaInfo),
      seriesTitle,
      chapterTitle,
      prevChapterUrl,
      nextChapterUrl,
      const DeepCollectionEquality().hash(_chapters),
      currentChapterId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MangaViewerStateImplCopyWith<_$MangaViewerStateImpl> get copyWith =>
      __$$MangaViewerStateImplCopyWithImpl<_$MangaViewerStateImpl>(
          this, _$identity);
}

abstract class _MangaViewerState implements MangaViewerState {
  const factory _MangaViewerState(
      {final bool isLoading,
      final bool hasError,
      final String errorMessage,
      final List<MangaPage> pages,
      final int currentPageIndex,
      final ViewMode viewMode,
      final ReadingDirection readingDirection,
      final CaptchaType captchaType,
      final Map<String, dynamic>? captchaInfo,
      final String seriesTitle,
      final String chapterTitle,
      final String prevChapterUrl,
      final String nextChapterUrl,
      final List<Chapter> chapters,
      final String currentChapterId}) = _$MangaViewerStateImpl;

  @override
  bool get isLoading;
  @override
  bool get hasError;
  @override
  String get errorMessage;
  @override
  List<MangaPage> get pages;
  @override
  int get currentPageIndex;
  @override
  ViewMode get viewMode;
  @override
  ReadingDirection get readingDirection;
  @override
  CaptchaType get captchaType;
  @override
  Map<String, dynamic>? get captchaInfo;
  @override
  String get seriesTitle;
  @override
  String get chapterTitle;
  @override
  String get prevChapterUrl;
  @override
  String get nextChapterUrl;
  @override
  List<Chapter> get chapters;
  @override
  String get currentChapterId;
  @override
  @JsonKey(ignore: true)
  _$$MangaViewerStateImplCopyWith<_$MangaViewerStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
