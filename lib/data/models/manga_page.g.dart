// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_page.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MangaPageImpl _$$MangaPageImplFromJson(Map<String, dynamic> json) =>
    _$MangaPageImpl(
      index: (json['index'] as num).toInt(),
      imageUrl: json['imageUrl'] as String,
      isLoaded: json['isLoaded'] as bool? ?? false,
      isLoading: json['isLoading'] as bool? ?? false,
      isError: json['isError'] as bool? ?? false,
    );

Map<String, dynamic> _$$MangaPageImplToJson(_$MangaPageImpl instance) =>
    <String, dynamic>{
      'index': instance.index,
      'imageUrl': instance.imageUrl,
      'isLoaded': instance.isLoaded,
      'isLoading': instance.isLoading,
      'isError': instance.isError,
    };
