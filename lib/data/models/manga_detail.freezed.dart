// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'manga_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MangaDetail _$MangaDetailFromJson(Map<String, dynamic> json) {
  return _MangaDetail.fromJson(json);
}

/// @nodoc
mixin _$MangaDetail {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get thumbnailUrl => throw _privateConstructorUsedError;
  String get author => throw _privateConstructorUsedError;
  List<String> get genres => throw _privateConstructorUsedError;
  String get releaseStatus => throw _privateConstructorUsedError;
  List<MangaChapter> get chapters => throw _privateConstructorUsedError;
  String get previousChapterId =>
      throw _privateConstructorUsedError; // 전편보기 링크의 만화 ID
  String? get fullViewUrl => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MangaDetailCopyWith<MangaDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MangaDetailCopyWith<$Res> {
  factory $MangaDetailCopyWith(
          MangaDetail value, $Res Function(MangaDetail) then) =
      _$MangaDetailCopyWithImpl<$Res, MangaDetail>;
  @useResult
  $Res call(
      {String id,
      String title,
      String thumbnailUrl,
      String author,
      List<String> genres,
      String releaseStatus,
      List<MangaChapter> chapters,
      String previousChapterId,
      String? fullViewUrl});
}

/// @nodoc
class _$MangaDetailCopyWithImpl<$Res, $Val extends MangaDetail>
    implements $MangaDetailCopyWith<$Res> {
  _$MangaDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? thumbnailUrl = null,
    Object? author = null,
    Object? genres = null,
    Object? releaseStatus = null,
    Object? chapters = null,
    Object? previousChapterId = null,
    Object? fullViewUrl = freezed,
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
      thumbnailUrl: null == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      genres: null == genres
          ? _value.genres
          : genres // ignore: cast_nullable_to_non_nullable
              as List<String>,
      releaseStatus: null == releaseStatus
          ? _value.releaseStatus
          : releaseStatus // ignore: cast_nullable_to_non_nullable
              as String,
      chapters: null == chapters
          ? _value.chapters
          : chapters // ignore: cast_nullable_to_non_nullable
              as List<MangaChapter>,
      previousChapterId: null == previousChapterId
          ? _value.previousChapterId
          : previousChapterId // ignore: cast_nullable_to_non_nullable
              as String,
      fullViewUrl: freezed == fullViewUrl
          ? _value.fullViewUrl
          : fullViewUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MangaDetailImplCopyWith<$Res>
    implements $MangaDetailCopyWith<$Res> {
  factory _$$MangaDetailImplCopyWith(
          _$MangaDetailImpl value, $Res Function(_$MangaDetailImpl) then) =
      __$$MangaDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String thumbnailUrl,
      String author,
      List<String> genres,
      String releaseStatus,
      List<MangaChapter> chapters,
      String previousChapterId,
      String? fullViewUrl});
}

/// @nodoc
class __$$MangaDetailImplCopyWithImpl<$Res>
    extends _$MangaDetailCopyWithImpl<$Res, _$MangaDetailImpl>
    implements _$$MangaDetailImplCopyWith<$Res> {
  __$$MangaDetailImplCopyWithImpl(
      _$MangaDetailImpl _value, $Res Function(_$MangaDetailImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? thumbnailUrl = null,
    Object? author = null,
    Object? genres = null,
    Object? releaseStatus = null,
    Object? chapters = null,
    Object? previousChapterId = null,
    Object? fullViewUrl = freezed,
  }) {
    return _then(_$MangaDetailImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailUrl: null == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      genres: null == genres
          ? _value._genres
          : genres // ignore: cast_nullable_to_non_nullable
              as List<String>,
      releaseStatus: null == releaseStatus
          ? _value.releaseStatus
          : releaseStatus // ignore: cast_nullable_to_non_nullable
              as String,
      chapters: null == chapters
          ? _value._chapters
          : chapters // ignore: cast_nullable_to_non_nullable
              as List<MangaChapter>,
      previousChapterId: null == previousChapterId
          ? _value.previousChapterId
          : previousChapterId // ignore: cast_nullable_to_non_nullable
              as String,
      fullViewUrl: freezed == fullViewUrl
          ? _value.fullViewUrl
          : fullViewUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MangaDetailImpl implements _MangaDetail {
  const _$MangaDetailImpl(
      {required this.id,
      required this.title,
      required this.thumbnailUrl,
      this.author = '',
      final List<String> genres = const <String>[],
      this.releaseStatus = '',
      final List<MangaChapter> chapters = const <MangaChapter>[],
      this.previousChapterId = '',
      this.fullViewUrl})
      : _genres = genres,
        _chapters = chapters;

  factory _$MangaDetailImpl.fromJson(Map<String, dynamic> json) =>
      _$$MangaDetailImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String thumbnailUrl;
  @override
  @JsonKey()
  final String author;
  final List<String> _genres;
  @override
  @JsonKey()
  List<String> get genres {
    if (_genres is EqualUnmodifiableListView) return _genres;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_genres);
  }

  @override
  @JsonKey()
  final String releaseStatus;
  final List<MangaChapter> _chapters;
  @override
  @JsonKey()
  List<MangaChapter> get chapters {
    if (_chapters is EqualUnmodifiableListView) return _chapters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapters);
  }

  @override
  @JsonKey()
  final String previousChapterId;
// 전편보기 링크의 만화 ID
  @override
  final String? fullViewUrl;

  @override
  String toString() {
    return 'MangaDetail(id: $id, title: $title, thumbnailUrl: $thumbnailUrl, author: $author, genres: $genres, releaseStatus: $releaseStatus, chapters: $chapters, previousChapterId: $previousChapterId, fullViewUrl: $fullViewUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MangaDetailImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.author, author) || other.author == author) &&
            const DeepCollectionEquality().equals(other._genres, _genres) &&
            (identical(other.releaseStatus, releaseStatus) ||
                other.releaseStatus == releaseStatus) &&
            const DeepCollectionEquality().equals(other._chapters, _chapters) &&
            (identical(other.previousChapterId, previousChapterId) ||
                other.previousChapterId == previousChapterId) &&
            (identical(other.fullViewUrl, fullViewUrl) ||
                other.fullViewUrl == fullViewUrl));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      thumbnailUrl,
      author,
      const DeepCollectionEquality().hash(_genres),
      releaseStatus,
      const DeepCollectionEquality().hash(_chapters),
      previousChapterId,
      fullViewUrl);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MangaDetailImplCopyWith<_$MangaDetailImpl> get copyWith =>
      __$$MangaDetailImplCopyWithImpl<_$MangaDetailImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MangaDetailImplToJson(
      this,
    );
  }
}

abstract class _MangaDetail implements MangaDetail {
  const factory _MangaDetail(
      {required final String id,
      required final String title,
      required final String thumbnailUrl,
      final String author,
      final List<String> genres,
      final String releaseStatus,
      final List<MangaChapter> chapters,
      final String previousChapterId,
      final String? fullViewUrl}) = _$MangaDetailImpl;

  factory _MangaDetail.fromJson(Map<String, dynamic> json) =
      _$MangaDetailImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get thumbnailUrl;
  @override
  String get author;
  @override
  List<String> get genres;
  @override
  String get releaseStatus;
  @override
  List<MangaChapter> get chapters;
  @override
  String get previousChapterId;
  @override // 전편보기 링크의 만화 ID
  String? get fullViewUrl;
  @override
  @JsonKey(ignore: true)
  _$$MangaDetailImplCopyWith<_$MangaDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MangaChapter _$MangaChapterFromJson(Map<String, dynamic> json) {
  return _MangaChapter.fromJson(json);
}

/// @nodoc
mixin _$MangaChapter {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get uploadDate => throw _privateConstructorUsedError;
  int get views => throw _privateConstructorUsedError;
  int get rating => throw _privateConstructorUsedError;
  int get likes => throw _privateConstructorUsedError;
  int get comments => throw _privateConstructorUsedError;
  String? get fullViewUrl => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MangaChapterCopyWith<MangaChapter> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MangaChapterCopyWith<$Res> {
  factory $MangaChapterCopyWith(
          MangaChapter value, $Res Function(MangaChapter) then) =
      _$MangaChapterCopyWithImpl<$Res, MangaChapter>;
  @useResult
  $Res call(
      {String id,
      String title,
      String uploadDate,
      int views,
      int rating,
      int likes,
      int comments,
      String? fullViewUrl});
}

/// @nodoc
class _$MangaChapterCopyWithImpl<$Res, $Val extends MangaChapter>
    implements $MangaChapterCopyWith<$Res> {
  _$MangaChapterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? uploadDate = null,
    Object? views = null,
    Object? rating = null,
    Object? likes = null,
    Object? comments = null,
    Object? fullViewUrl = freezed,
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
      uploadDate: null == uploadDate
          ? _value.uploadDate
          : uploadDate // ignore: cast_nullable_to_non_nullable
              as String,
      views: null == views
          ? _value.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as int,
      likes: null == likes
          ? _value.likes
          : likes // ignore: cast_nullable_to_non_nullable
              as int,
      comments: null == comments
          ? _value.comments
          : comments // ignore: cast_nullable_to_non_nullable
              as int,
      fullViewUrl: freezed == fullViewUrl
          ? _value.fullViewUrl
          : fullViewUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MangaChapterImplCopyWith<$Res>
    implements $MangaChapterCopyWith<$Res> {
  factory _$$MangaChapterImplCopyWith(
          _$MangaChapterImpl value, $Res Function(_$MangaChapterImpl) then) =
      __$$MangaChapterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String uploadDate,
      int views,
      int rating,
      int likes,
      int comments,
      String? fullViewUrl});
}

/// @nodoc
class __$$MangaChapterImplCopyWithImpl<$Res>
    extends _$MangaChapterCopyWithImpl<$Res, _$MangaChapterImpl>
    implements _$$MangaChapterImplCopyWith<$Res> {
  __$$MangaChapterImplCopyWithImpl(
      _$MangaChapterImpl _value, $Res Function(_$MangaChapterImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? uploadDate = null,
    Object? views = null,
    Object? rating = null,
    Object? likes = null,
    Object? comments = null,
    Object? fullViewUrl = freezed,
  }) {
    return _then(_$MangaChapterImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      uploadDate: null == uploadDate
          ? _value.uploadDate
          : uploadDate // ignore: cast_nullable_to_non_nullable
              as String,
      views: null == views
          ? _value.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as int,
      likes: null == likes
          ? _value.likes
          : likes // ignore: cast_nullable_to_non_nullable
              as int,
      comments: null == comments
          ? _value.comments
          : comments // ignore: cast_nullable_to_non_nullable
              as int,
      fullViewUrl: freezed == fullViewUrl
          ? _value.fullViewUrl
          : fullViewUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MangaChapterImpl implements _MangaChapter {
  const _$MangaChapterImpl(
      {required this.id,
      required this.title,
      this.uploadDate = '',
      this.views = 0,
      this.rating = 0,
      this.likes = 0,
      this.comments = 0,
      this.fullViewUrl});

  factory _$MangaChapterImpl.fromJson(Map<String, dynamic> json) =>
      _$$MangaChapterImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  @JsonKey()
  final String uploadDate;
  @override
  @JsonKey()
  final int views;
  @override
  @JsonKey()
  final int rating;
  @override
  @JsonKey()
  final int likes;
  @override
  @JsonKey()
  final int comments;
  @override
  final String? fullViewUrl;

  @override
  String toString() {
    return 'MangaChapter(id: $id, title: $title, uploadDate: $uploadDate, views: $views, rating: $rating, likes: $likes, comments: $comments, fullViewUrl: $fullViewUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MangaChapterImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.uploadDate, uploadDate) ||
                other.uploadDate == uploadDate) &&
            (identical(other.views, views) || other.views == views) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.likes, likes) || other.likes == likes) &&
            (identical(other.comments, comments) ||
                other.comments == comments) &&
            (identical(other.fullViewUrl, fullViewUrl) ||
                other.fullViewUrl == fullViewUrl));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, uploadDate, views,
      rating, likes, comments, fullViewUrl);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MangaChapterImplCopyWith<_$MangaChapterImpl> get copyWith =>
      __$$MangaChapterImplCopyWithImpl<_$MangaChapterImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MangaChapterImplToJson(
      this,
    );
  }
}

abstract class _MangaChapter implements MangaChapter {
  const factory _MangaChapter(
      {required final String id,
      required final String title,
      final String uploadDate,
      final int views,
      final int rating,
      final int likes,
      final int comments,
      final String? fullViewUrl}) = _$MangaChapterImpl;

  factory _MangaChapter.fromJson(Map<String, dynamic> json) =
      _$MangaChapterImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get uploadDate;
  @override
  int get views;
  @override
  int get rating;
  @override
  int get likes;
  @override
  int get comments;
  @override
  String? get fullViewUrl;
  @override
  @JsonKey(ignore: true)
  _$$MangaChapterImplCopyWith<_$MangaChapterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
