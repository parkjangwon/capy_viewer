// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'manga_page.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MangaPage _$MangaPageFromJson(Map<String, dynamic> json) {
  return _MangaPage.fromJson(json);
}

/// @nodoc
mixin _$MangaPage {
  int get index => throw _privateConstructorUsedError;
  String get imageUrl => throw _privateConstructorUsedError;
  bool get isLoaded => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  bool get isError => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MangaPageCopyWith<MangaPage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MangaPageCopyWith<$Res> {
  factory $MangaPageCopyWith(MangaPage value, $Res Function(MangaPage) then) =
      _$MangaPageCopyWithImpl<$Res, MangaPage>;
  @useResult
  $Res call(
      {int index,
      String imageUrl,
      bool isLoaded,
      bool isLoading,
      bool isError});
}

/// @nodoc
class _$MangaPageCopyWithImpl<$Res, $Val extends MangaPage>
    implements $MangaPageCopyWith<$Res> {
  _$MangaPageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? index = null,
    Object? imageUrl = null,
    Object? isLoaded = null,
    Object? isLoading = null,
    Object? isError = null,
  }) {
    return _then(_value.copyWith(
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
      imageUrl: null == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String,
      isLoaded: null == isLoaded
          ? _value.isLoaded
          : isLoaded // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isError: null == isError
          ? _value.isError
          : isError // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MangaPageImplCopyWith<$Res>
    implements $MangaPageCopyWith<$Res> {
  factory _$$MangaPageImplCopyWith(
          _$MangaPageImpl value, $Res Function(_$MangaPageImpl) then) =
      __$$MangaPageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int index,
      String imageUrl,
      bool isLoaded,
      bool isLoading,
      bool isError});
}

/// @nodoc
class __$$MangaPageImplCopyWithImpl<$Res>
    extends _$MangaPageCopyWithImpl<$Res, _$MangaPageImpl>
    implements _$$MangaPageImplCopyWith<$Res> {
  __$$MangaPageImplCopyWithImpl(
      _$MangaPageImpl _value, $Res Function(_$MangaPageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? index = null,
    Object? imageUrl = null,
    Object? isLoaded = null,
    Object? isLoading = null,
    Object? isError = null,
  }) {
    return _then(_$MangaPageImpl(
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
      imageUrl: null == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String,
      isLoaded: null == isLoaded
          ? _value.isLoaded
          : isLoaded // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isError: null == isError
          ? _value.isError
          : isError // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MangaPageImpl implements _MangaPage {
  const _$MangaPageImpl(
      {required this.index,
      required this.imageUrl,
      this.isLoaded = false,
      this.isLoading = false,
      this.isError = false});

  factory _$MangaPageImpl.fromJson(Map<String, dynamic> json) =>
      _$$MangaPageImplFromJson(json);

  @override
  final int index;
  @override
  final String imageUrl;
  @override
  @JsonKey()
  final bool isLoaded;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isError;

  @override
  String toString() {
    return 'MangaPage(index: $index, imageUrl: $imageUrl, isLoaded: $isLoaded, isLoading: $isLoading, isError: $isError)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MangaPageImpl &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.isLoaded, isLoaded) ||
                other.isLoaded == isLoaded) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isError, isError) || other.isError == isError));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, index, imageUrl, isLoaded, isLoading, isError);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MangaPageImplCopyWith<_$MangaPageImpl> get copyWith =>
      __$$MangaPageImplCopyWithImpl<_$MangaPageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MangaPageImplToJson(
      this,
    );
  }
}

abstract class _MangaPage implements MangaPage {
  const factory _MangaPage(
      {required final int index,
      required final String imageUrl,
      final bool isLoaded,
      final bool isLoading,
      final bool isError}) = _$MangaPageImpl;

  factory _MangaPage.fromJson(Map<String, dynamic> json) =
      _$MangaPageImpl.fromJson;

  @override
  int get index;
  @override
  String get imageUrl;
  @override
  bool get isLoaded;
  @override
  bool get isLoading;
  @override
  bool get isError;
  @override
  @JsonKey(ignore: true)
  _$$MangaPageImplCopyWith<_$MangaPageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
