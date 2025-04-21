// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'manga_title.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MangaTitle _$MangaTitleFromJson(Map<String, dynamic> json) {
  return _MangaTitle.fromJson(json);
}

/// @nodoc
mixin _$MangaTitle {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get thumbnailUrl => throw _privateConstructorUsedError;
  String get author => throw _privateConstructorUsedError;
  String get release => throw _privateConstructorUsedError;
  String? get period => throw _privateConstructorUsedError;
  String? get updateDate => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MangaTitleCopyWith<MangaTitle> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MangaTitleCopyWith<$Res> {
  factory $MangaTitleCopyWith(
          MangaTitle value, $Res Function(MangaTitle) then) =
      _$MangaTitleCopyWithImpl<$Res, MangaTitle>;
  @useResult
  $Res call(
      {String id,
      String title,
      String thumbnailUrl,
      String author,
      String release,
      String? period,
      String? updateDate});
}

/// @nodoc
class _$MangaTitleCopyWithImpl<$Res, $Val extends MangaTitle>
    implements $MangaTitleCopyWith<$Res> {
  _$MangaTitleCopyWithImpl(this._value, this._then);

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
    Object? release = null,
    Object? period = freezed,
    Object? updateDate = freezed,
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
      release: null == release
          ? _value.release
          : release // ignore: cast_nullable_to_non_nullable
              as String,
      period: freezed == period
          ? _value.period
          : period // ignore: cast_nullable_to_non_nullable
              as String?,
      updateDate: freezed == updateDate
          ? _value.updateDate
          : updateDate // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MangaTitleImplCopyWith<$Res>
    implements $MangaTitleCopyWith<$Res> {
  factory _$$MangaTitleImplCopyWith(
          _$MangaTitleImpl value, $Res Function(_$MangaTitleImpl) then) =
      __$$MangaTitleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String thumbnailUrl,
      String author,
      String release,
      String? period,
      String? updateDate});
}

/// @nodoc
class __$$MangaTitleImplCopyWithImpl<$Res>
    extends _$MangaTitleCopyWithImpl<$Res, _$MangaTitleImpl>
    implements _$$MangaTitleImplCopyWith<$Res> {
  __$$MangaTitleImplCopyWithImpl(
      _$MangaTitleImpl _value, $Res Function(_$MangaTitleImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? thumbnailUrl = null,
    Object? author = null,
    Object? release = null,
    Object? period = freezed,
    Object? updateDate = freezed,
  }) {
    return _then(_$MangaTitleImpl(
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
      release: null == release
          ? _value.release
          : release // ignore: cast_nullable_to_non_nullable
              as String,
      period: freezed == period
          ? _value.period
          : period // ignore: cast_nullable_to_non_nullable
              as String?,
      updateDate: freezed == updateDate
          ? _value.updateDate
          : updateDate // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MangaTitleImpl implements _MangaTitle {
  const _$MangaTitleImpl(
      {required this.id,
      required this.title,
      required this.thumbnailUrl,
      this.author = '',
      this.release = '',
      this.period,
      this.updateDate});

  factory _$MangaTitleImpl.fromJson(Map<String, dynamic> json) =>
      _$$MangaTitleImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String thumbnailUrl;
  @override
  @JsonKey()
  final String author;
  @override
  @JsonKey()
  final String release;
  @override
  final String? period;
  @override
  final String? updateDate;

  @override
  String toString() {
    return 'MangaTitle(id: $id, title: $title, thumbnailUrl: $thumbnailUrl, author: $author, release: $release, period: $period, updateDate: $updateDate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MangaTitleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.release, release) || other.release == release) &&
            (identical(other.period, period) || other.period == period) &&
            (identical(other.updateDate, updateDate) ||
                other.updateDate == updateDate));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, thumbnailUrl, author,
      release, period, updateDate);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MangaTitleImplCopyWith<_$MangaTitleImpl> get copyWith =>
      __$$MangaTitleImplCopyWithImpl<_$MangaTitleImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MangaTitleImplToJson(
      this,
    );
  }
}

abstract class _MangaTitle implements MangaTitle {
  const factory _MangaTitle(
      {required final String id,
      required final String title,
      required final String thumbnailUrl,
      final String author,
      final String release,
      final String? period,
      final String? updateDate}) = _$MangaTitleImpl;

  factory _MangaTitle.fromJson(Map<String, dynamic> json) =
      _$MangaTitleImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get thumbnailUrl;
  @override
  String get author;
  @override
  String get release;
  @override
  String? get period;
  @override
  String? get updateDate;
  @override
  @JsonKey(ignore: true)
  _$$MangaTitleImplCopyWith<_$MangaTitleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
