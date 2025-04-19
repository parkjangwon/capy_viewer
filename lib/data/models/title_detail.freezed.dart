// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'title_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TitleDetail _$TitleDetailFromJson(Map<String, dynamic> json) {
  return _TitleDetail.fromJson(json);
}

/// @nodoc
mixin _$TitleDetail {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get thumbnailUrl => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  List<Chapter> get chapters => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get author => throw _privateConstructorUsedError;
  String? get status => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $TitleDetailCopyWith<TitleDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TitleDetailCopyWith<$Res> {
  factory $TitleDetailCopyWith(
          TitleDetail value, $Res Function(TitleDetail) then) =
      _$TitleDetailCopyWithImpl<$Res, TitleDetail>;
  @useResult
  $Res call(
      {String id,
      String title,
      String thumbnailUrl,
      String url,
      List<Chapter> chapters,
      String? description,
      String? author,
      String? status});
}

/// @nodoc
class _$TitleDetailCopyWithImpl<$Res, $Val extends TitleDetail>
    implements $TitleDetailCopyWith<$Res> {
  _$TitleDetailCopyWithImpl(this._value, this._then);

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
    Object? url = null,
    Object? chapters = null,
    Object? description = freezed,
    Object? author = freezed,
    Object? status = freezed,
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
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      chapters: null == chapters
          ? _value.chapters
          : chapters // ignore: cast_nullable_to_non_nullable
              as List<Chapter>,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      author: freezed == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TitleDetailImplCopyWith<$Res>
    implements $TitleDetailCopyWith<$Res> {
  factory _$$TitleDetailImplCopyWith(
          _$TitleDetailImpl value, $Res Function(_$TitleDetailImpl) then) =
      __$$TitleDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String thumbnailUrl,
      String url,
      List<Chapter> chapters,
      String? description,
      String? author,
      String? status});
}

/// @nodoc
class __$$TitleDetailImplCopyWithImpl<$Res>
    extends _$TitleDetailCopyWithImpl<$Res, _$TitleDetailImpl>
    implements _$$TitleDetailImplCopyWith<$Res> {
  __$$TitleDetailImplCopyWithImpl(
      _$TitleDetailImpl _value, $Res Function(_$TitleDetailImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? thumbnailUrl = null,
    Object? url = null,
    Object? chapters = null,
    Object? description = freezed,
    Object? author = freezed,
    Object? status = freezed,
  }) {
    return _then(_$TitleDetailImpl(
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
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      chapters: null == chapters
          ? _value._chapters
          : chapters // ignore: cast_nullable_to_non_nullable
              as List<Chapter>,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      author: freezed == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TitleDetailImpl implements _TitleDetail {
  const _$TitleDetailImpl(
      {required this.id,
      required this.title,
      required this.thumbnailUrl,
      required this.url,
      final List<Chapter> chapters = const [],
      this.description,
      this.author,
      this.status})
      : _chapters = chapters;

  factory _$TitleDetailImpl.fromJson(Map<String, dynamic> json) =>
      _$$TitleDetailImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String thumbnailUrl;
  @override
  final String url;
  final List<Chapter> _chapters;
  @override
  @JsonKey()
  List<Chapter> get chapters {
    if (_chapters is EqualUnmodifiableListView) return _chapters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapters);
  }

  @override
  final String? description;
  @override
  final String? author;
  @override
  final String? status;

  @override
  String toString() {
    return 'TitleDetail(id: $id, title: $title, thumbnailUrl: $thumbnailUrl, url: $url, chapters: $chapters, description: $description, author: $author, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TitleDetailImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.url, url) || other.url == url) &&
            const DeepCollectionEquality().equals(other._chapters, _chapters) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      thumbnailUrl,
      url,
      const DeepCollectionEquality().hash(_chapters),
      description,
      author,
      status);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TitleDetailImplCopyWith<_$TitleDetailImpl> get copyWith =>
      __$$TitleDetailImplCopyWithImpl<_$TitleDetailImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TitleDetailImplToJson(
      this,
    );
  }
}

abstract class _TitleDetail implements TitleDetail {
  const factory _TitleDetail(
      {required final String id,
      required final String title,
      required final String thumbnailUrl,
      required final String url,
      final List<Chapter> chapters,
      final String? description,
      final String? author,
      final String? status}) = _$TitleDetailImpl;

  factory _TitleDetail.fromJson(Map<String, dynamic> json) =
      _$TitleDetailImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get thumbnailUrl;
  @override
  String get url;
  @override
  List<Chapter> get chapters;
  @override
  String? get description;
  @override
  String? get author;
  @override
  String? get status;
  @override
  @JsonKey(ignore: true)
  _$$TitleDetailImplCopyWith<_$TitleDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Chapter _$ChapterFromJson(Map<String, dynamic> json) {
  return _Chapter.fromJson(json);
}

/// @nodoc
mixin _$Chapter {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  DateTime get uploadDate => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ChapterCopyWith<Chapter> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChapterCopyWith<$Res> {
  factory $ChapterCopyWith(Chapter value, $Res Function(Chapter) then) =
      _$ChapterCopyWithImpl<$Res, Chapter>;
  @useResult
  $Res call({String id, String title, String url, DateTime uploadDate});
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
    Object? uploadDate = null,
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
      uploadDate: null == uploadDate
          ? _value.uploadDate
          : uploadDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
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
  $Res call({String id, String title, String url, DateTime uploadDate});
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
    Object? uploadDate = null,
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
      uploadDate: null == uploadDate
          ? _value.uploadDate
          : uploadDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChapterImpl implements _Chapter {
  const _$ChapterImpl(
      {required this.id,
      required this.title,
      required this.url,
      required this.uploadDate});

  factory _$ChapterImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChapterImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String url;
  @override
  final DateTime uploadDate;

  @override
  String toString() {
    return 'Chapter(id: $id, title: $title, url: $url, uploadDate: $uploadDate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChapterImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.uploadDate, uploadDate) ||
                other.uploadDate == uploadDate));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, url, uploadDate);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChapterImplCopyWith<_$ChapterImpl> get copyWith =>
      __$$ChapterImplCopyWithImpl<_$ChapterImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChapterImplToJson(
      this,
    );
  }
}

abstract class _Chapter implements Chapter {
  const factory _Chapter(
      {required final String id,
      required final String title,
      required final String url,
      required final DateTime uploadDate}) = _$ChapterImpl;

  factory _Chapter.fromJson(Map<String, dynamic> json) = _$ChapterImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get url;
  @override
  DateTime get uploadDate;
  @override
  @JsonKey(ignore: true)
  _$$ChapterImplCopyWith<_$ChapterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
