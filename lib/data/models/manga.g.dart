// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MangaImpl _$$MangaImplFromJson(Map<String, dynamic> json) => _$MangaImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      url: json['url'] as String,
      thumbnails: (json['thumbnails'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      mode: $enumDecodeNullable(_$MangaModeEnumMap, json['mode']) ??
          MangaMode.vertical,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      date: json['date'] as String,
    );

Map<String, dynamic> _$$MangaImplToJson(_$MangaImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'url': instance.url,
      'thumbnails': instance.thumbnails,
      'mode': _$MangaModeEnumMap[instance.mode]!,
      'images': instance.images,
      'date': instance.date,
    };

const _$MangaModeEnumMap = {
  MangaMode.vertical: 'vertical',
  MangaMode.horizontal: 'horizontal',
};
